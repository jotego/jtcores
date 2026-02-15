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

module jtx1010_wav(
    input              clk,
    input              cen,
    input       [ 3:0] ch,
    input       [ 4:0] st,
    input       [ 7:0] cfg, cfg_data,
    input       [15:0] keyon,
    output reg         keyoff,

    output      [11:0] wav_addr, env_addr,
    input       [ 7:0] wav_data, env_data,

    output reg signed [15:0] wav_l, wav_r
);

localparam KEYON=0, WAV=1, SINGLE=2, DIV=7;

wire [16:0] ram_dout;
reg  [ 7:0] evstep;
reg  [ 4:0] wav_id, env_id;
reg  [ 3:0] vol_l, vol_r;
reg  [16:0] wav_cnt, env_cnt;
reg  [15:0] buf_l, pitch;
reg         we;

reg signed [15:0] mul;
reg signed [ 7:0] mul_in2;
reg        [ 3:0] mul_in;

assign wav_addr = {wav_id,wav_cnt[16:10]};
assign env_addr = {env_id,env_cnt[16:10]};

always_comb begin
    mul_in2 = cfg[KEYON] & ~keyoff ? wav_data : 8'd0;
    mul = {4'd0,mul_in} * mul_in2;
end

reg [16:0] muxin, nx_env, nx_wav;
wire       wav_sel = st[0];

always_comb begin
    case(st)
         5'o3_6: begin we = 1; muxin = nx_env; end
         5'o3_7: begin we = 1; muxin = nx_wav; end
        default: begin we = 0; muxin = 0;      end
    endcase
    if( !cfg[KEYON] ) muxin = 0;
end

jtframe_ram #(.DW(17), .AW(5))u_ram(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( muxin         ),
    .addr   ( {wav_sel,ch}  ),
    .we     ( we            ),
    .q      ( ram_dout      )
);

always_ff @(posedge clk) if(cen) begin
    case(st)
        1: begin wav_id <= cfg_data[4:0]; wav_cnt <= ram_dout; end
        2: pitch[ 7:0]  <= cfg_data;
        3: pitch[15:8]  <= cfg_data;
        4: begin evstep <= cfg_data; env_cnt <= ram_dout; end
        5: env_id       <= cfg_data[4:0];
        8: pitch   <= pitch >> cfg[DIV];
       10: if(!keyon[ch] && cfg[KEYON]) {env_cnt,wav_cnt} <= '0;
       20: nx_env <= env_cnt + {9'd0,evstep};
       21: begin keyoff <= nx_env[16] && cfg[SINGLE]; end
       22: mul_in <= env_data[7:4];
       23: begin buf_l <= mul; mul_in <= env_data[3:0]; end
       25: begin
            wav_l  <= buf_l;
            wav_r  <= mul;
            keyoff <= 0;
            nx_wav <= wav_cnt + {1'd0,pitch};
        end
        default: ;
    endcase
end

endmodule
