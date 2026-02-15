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
    output      [19:0] rom_addr,
    input       [ 7:0] rom_data,
    output             rom_cs,      // rom_ok not needed

    // sound output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output             sample
);

wire        env_cs = cpu_addr>='h80 && !cpu_addr[12];
wire        wav_cs = cpu_addr[12];
wire        mmr_cs = cpu_addr<'h80;
wire        mmr_we = cpu_cs && cpu_wr && mmr_cs;
wire        wav_we = cpu_cs && cpu_wr && wav_cs;
wire        env_we = cpu_cs && cpu_wr && env_cs;
reg  [ 7:0] cfg_din, cpu_wav, cpu_mmr, cpu_env;
wire [ 7:0] cfg;
wire [ 3:0] ch;
wire [ 4:0] st;
wire [15:0] keyon, pcm_l, pcm_r, wav_l, wav_r;
wire [ 7:0] cfg_data, wav_data, env_data;
reg  [11:0] wav_addr=0; // not implemented
reg  [11:0] env_addr=0; // not implemented
reg         cfg_we, kon;
wire        up;

`ifdef SIMULATION
wire        mmr_rd = cpu_cs && !cpu_wr && mmr_cs;
wire        wav_rd = cpu_cs && !cpu_wr && wav_cs;
wire        env_rd = cpu_cs && !cpu_wr && env_cs;
`endif

assign cpu_din = wav_cs ? cpu_wav :
                 env_cs ? cpu_env : cpu_mmr;

localparam KEYON=0, WAV=1;
wire keyoff;


always_comb begin
    kon     = ch[WAV] ? cfg[KEYON] & ~keyoff: cfg[KEYON];
    cfg_din ={cfg[7:1],kon};
    cfg_we  = up && st==5'o30;
end

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

jtx1010_acc u_acc(
    .clk        ( clk       ),
    .cen        ( cen       ),

    .ch         ( ch        ),
    .st         ( st        ),
    .cfg        ( cfg       ),

    .pcm_l      ( pcm_l     ),
    .pcm_r      ( pcm_r     ),
    .wav_l      ( wav_l     ),
    .wav_r      ( wav_r     ),

    .snd_l      ( snd_left  ),
    .snd_r      ( snd_right ),
    .sample     ( sample    )
);

jtx1010_pcm u_pcm_fsm(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .ch         ( ch        ),
    .st         ( st        ),
    .cfg        ( cfg       ),
    .cfg_data   ( cfg_data  ),
    .up         ( up        ),
    .keyon      ( keyon     ),

    // ROM interface
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),      // rom_ok not needed

    .pcm_l      ( pcm_l     ),
    .pcm_r      ( pcm_r     )
);

jtx1010_wav u_wav_fsm(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .ch         ( ch        ),
    .st         ( st        ),
    .cfg        ( cfg       ),
    .keyon      ( keyon     ),
    .keyoff     ( keyoff    ),
    .cfg_data   ( cfg_data  ),

    .wav_addr   ( wav_addr  ),
    .wav_data   ( wav_data  ),
    .env_addr   ( env_addr  ),
    .env_data   ( env_data  ),

    .wav_l      ( wav_l     ),
    .wav_r      ( wav_r     )
);

endmodule
