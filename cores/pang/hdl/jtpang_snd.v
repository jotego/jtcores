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
    Date: 21-5-2022 */

module jtpang_snd(
    input              clk,
    input              rst,
    input              fm_cen,  // 4 MHz
    input              pcm_cen, // 1 MHz

    // CPU interface
    input        [7:0] cpu_dout,
    input              wr_n,

    input              a0,
    input              fm_cs,

    output       [7:0] pcm_dout,
    input              pcm_cs,

    // OSD control - not implemented yet
    input              enable_psg,
    input              enable_fm,

    // ROM interface
    output      [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,

    output signed [15:0] fm,
    output signed [13:0] pcm
);

localparam [7:0] FM_GAIN  = 8'h10,
                 PCM_GAIN = 8'h0c;

wire signed [15:0] fm_snd;
wire signed [13:0] pcm_snd, pcm_raw;
wire               pcm_wrn;

assign pcm_wrn = wr_n | ~pcm_cs;


jt2413 u_jt2413 (
    .rst   ( rst        ),
    .clk   ( clk        ),
    .cen   ( fm_cen     ),
    .din   ( cpu_dout   ),
    .addr  ( a0         ),
    .cs_n  ( ~fm_cs     ),
    .wr_n  ( wr_n       ),
    .snd   ( fm         ),
    .sample(            )
);
/* verilator tracing_off */

jt6295 u_pcm (
    .rst     ( rst      ),
    .clk     ( clk      ),
    .cen     ( pcm_cen  ),
    .ss      ( 1'b1     ),
    .wrn     ( pcm_wrn  ),
    .din     ( cpu_dout ),
    .dout    ( pcm_dout ),
    .rom_addr( rom_addr ),
    .rom_data( rom_data ),
    .rom_ok  ( rom_ok   ),
    .sound   ( pcm      ),
    .sample  (          )
);

/* verilator tracing_on */
endmodule

