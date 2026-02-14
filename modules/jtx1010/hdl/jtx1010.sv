/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-2-2026 */

module jtx1010(
    input              rst,
    input              clk,
    input              cen, // usually 16MHz

    // CPU interface
    input       [12:0] cpu_addr,
    input       [ 7:0] cpu_dout,
    output      [ 7:0] cpu_din,
    input              cpu_wr,
    input              cpu_cs,

    // ROM interface
    output reg  [19:0] rom_addr,
    input       [ 7:0] rom_data,
    output reg         rom_cs,      // rom_ok not needed

    // sound output
    output reg signed [15:0] snd_left,
    output reg signed [15:0] snd_right,
    output reg           sample
);

wire        env_cs = cpu_addr>='h80 && !cpu_addr[12];
wire        wav_cs = cpu_addr[12];
wire        mmr_cs = cpu_addr<'h80;
wire        mmr_we = cpu_cs && cpu_wr && mmr_cs;
wire        wav_we = cpu_cs && cpu_wr && wav_cs;
wire        env_we = cpu_cs && cpu_wr && env_cs;
reg  [ 3:0] ch, vol_l, vol_r;
reg  [ 7:0] cfg_din, cfg, delta, wavlo, start, finish, cpu_wav, cpu_mmr, cpu_env;
reg  [15:0] cur, buf_l, keyon;
wire [ 7:0] cfg_data, wav_data, env_data, wav_id;
reg  [11:0] wav_addr=0; // not implemented
reg  [11:0] env_addr=0; // not implemented
reg         cfg_we, up;

`ifdef SIMULATION
wire        mmr_rd = cpu_cs && !cpu_wr && mmr_cs;
wire        wav_rd = cpu_cs && !cpu_wr && wav_cs;
wire        env_rd = cpu_cs && !cpu_wr && env_cs;
`endif

assign cpu_din = wav_cs ? cpu_wav :
                 env_cs ? cpu_env : cpu_mmr;
assign wav_id  = {vol_l,vol_r};

jtframe_dual_ram #(.AW(7)) u_mmr(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  (cpu_addr[6:0]),
    .we0    ( mmr_we    ),
    .q0     ( cpu_mmr   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( cfg_din   ),
    .addr1  ( {ch,st[2:0]} ),
    .we1    ( cfg_we    ),
    .q1     ( cfg_data  )
);

jtframe_dual_ram #(.AW(12)) u_env(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  (cpu_addr[11:0]),
    .we0    ( env_we    ),
    .q0     ( cpu_env   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( 8'd0      ),
    .addr1  ( env_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( env_data  )
);

jtframe_dual_ram #(.AW(12)) u_waves(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  (cpu_addr[11:0]),
    .we0    ( wav_we    ),
    .q0     ( cpu_wav   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( 8'd0      ),
    .addr1  ( wav_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( wav_data  )
);

localparam KEYON=0, WAV=1, REPEAT=2, DIV=7;

reg signed [15:0] mul, acc_l, acc_r;
reg        [ 3:0] mul_in;
reg        [ 4:0] st;

always_comb begin
    mul = {4'd0,mul_in} * rom_data;
end

always_comb begin
    case(st)
        5'o3_0:  begin cfg_we = up; cfg_din = cfg;       end
        5'o3_6:  begin cfg_we = up; cfg_din = cur[ 7:0]; end
        5'o3_7:  begin cfg_we = up; cfg_din = cur[15:8]; end
        default: begin cfg_we =  0; cfg_din = 0;         end
    endcase
end

// 16 MHz/16 ch => 1MHz per channel
// 32 steps per channel => 31,250 Hz sampling rate
always_ff @(posedge clk) if(cen) begin
    {ch,st} <= {ch,st}+9'd1;
    sample <= 0;
    case(st)
        0:  cfg          <= cfg_data;
        1: {vol_l,vol_r} <= cfg_data; // also used as wav_id
        2:  delta        <= cfg_data;
        3:  wavlo        <= cfg_data;
        4:  start        <= cfg_data;
        5:  finish       <=~cfg_data;
        6:  cur[ 7:0]    <= cfg_data;
        7: begin up <= cfg[KEYON];  cur[15:8] <= cfg_data;  end
       10: if(!keyon[ch] && cfg[KEYON]) cur <= 0;
       11: rom_addr <= {start,12'd0}+{8'd0,cur[15:4]};
       12: if(rom_addr[19:12]>=finish) cfg[KEYON] <= 0;
       13: rom_cs <= cfg[KEYON] && !cfg[WAV];
       14: cur <= cur+{8'd0,delta};
`ifdef SIMULATION
       15: if(cfg[KEYON] && cfg[WAV]) begin
           $display("WAV table is used but it is not implemented");
           $finish;
       end
`endif
       // 14 -> 21 waiting for rom data for 7us
       // MAME driver questions vol_l bits
       21: begin mul_in <= cfg[KEYON] ? vol_l : 4'd0;               end
       22: begin mul_in <= cfg[KEYON] ? vol_r : 4'd0; buf_l <= mul; end
       24: keyon[ch] <= cfg[KEYON];
       31: begin
            sample <= 1;
            if(ch==0) begin
                snd_left  <= acc_l;
                snd_right <= acc_r;
                acc_l     <= buf_l;
                acc_r     <= mul;
            end else begin
                acc_l     <= acc_l + buf_l;
                acc_r     <= acc_r + mul;
            end
        end
        default: ;
    endcase
end

endmodule
