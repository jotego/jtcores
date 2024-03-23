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
    Date: 4-8-2020 */

module jttrojan_sound(
    input           rst,
    input           clk,
    input           cen3,     //  3    MHz
    input           cen1p5,   //  1.5  MHz
    // Interface with main CPU
    input           sres_b,
    input           snd_int,
    input   [7:0]   snd_latch,
    input   [7:0]   snd2_latch,
    // ROM
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [13:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,

    // Sound output
    output signed [15:0] fm0, fm1,
    output        [ 9:0] psg0, psg1,
    output signed [11:0] pcm,
    output        [ 7:0] debug_view
);
`ifndef NOSOUND
wire               cenp384; //  384 kHz

jtframe_cenp384 u_cenp384(
    .clk      ( clk       ),
    .cen_p384 ( cenp384   )
);

jtgng_sound #(.LAYOUT(0)) u_fmcpu (
    .rst        (  rst          ),
    .clk        (  clk          ),
    .cen3       (  cen3         ),
    .cen1p5     (  cen1p5       ), // unused
    .sres_b     (  sres_b       ),
    .snd_latch  (  snd_latch    ),
    .snd2_latch (               ),
    .snd_int    (  snd_int      ), // unused
    // ROM
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    // sound output
    .fm0        ( fm0           ),
    .fm1        ( fm1           ),
    .psg0       ( psg0          ),
    .psg1       ( psg1          ),
    .debug_bus  ( 8'd0          ),
    .debug_view ( debug_view    )
);

wire [1:0] nc;

jttora_adpcm u_adpcmcpu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen3       ( cen3          ),
    .cenp384    ( cenp384       ),
    // Interface with second CPU
    .snd2_latch ( snd2_latch    ),
    // ADPCM ROM
    .rom2_addr  ( {nc,rom2_addr}),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),
    // Sound output
    .snd        ( pcm           )
);
`else
    assign  rom_addr   = 0;
    assign  rom_cs     = 0;
    assign  rom2_addr  = 0;
    assign  rom2_cs    = 0;
    assign  adpcm      = 0;
    assign  fm0        = 0;
    assign  fm1        = 0;
    assign  psg0       = 0;
    assign  psg1       = 0;
    assign  debug_view = 0;
`endif
endmodule