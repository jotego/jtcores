/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

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
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [1:0]   psg_level,
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
    output signed [15:0] ym_snd,
    output          sample,
    output reg      peak
);

wire signed [15:0] fm_snd;
wire signed [11:0] adpcm_snd;
wire               cenp384; //  384 kHz
wire               fm_peak, mix_peak;
reg         [ 7:0] pcm_gain;

always @(posedge clk) begin
    peak <= fm_peak | mix_peak;
    case( psg_level )
        2'd0: pcm_gain <= 8'h04;
        2'd1: pcm_gain <= 8'h08;
        2'd2: pcm_gain <= 8'h10;
        2'd3: pcm_gain <= 8'h20;
    endcase
end

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
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_level  (  psg_level    ),
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    .ym_snd     (  fm_snd       ),
    .sample     (  sample       ),
    .peak       (  fm_peak      )
);

jttora_adpcm #(.ADPCM_EXTRA(0))u_adpcmcpu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen3       ( cen3          ),
    .cenp384    ( cenp384       ),
    // Interface with second CPU
    .snd2_latch ( snd2_latch    ),
    // ADPCM ROM
    .rom2_addr  ( rom2_addr     ),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),
    // Sound output
    .snd        ( adpcm_snd     )
);

jtframe_mixer #(.W0(16),.W1(12)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen1p5    ),
    // input signals
    .ch0    ( fm_snd    ),
    .ch1    ( adpcm_snd ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( 8'h10     ),
    .gain1  ( pcm_gain  ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( ym_snd    ),
    .peak   ( mix_peak  )
);

endmodule