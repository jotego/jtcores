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
    Date: 27-10-2017 */

module jttora_sound(
    input           rst,
    input           clk,
    input           cen3,    //  3   MHz
    input           cenfm,   //  3.57   MHz
    input           cenp384, //  384 kHz
    input           jap,
    // Interface with main CPU
    input   [7:0]   snd_latch,
    // Interface with MCU
    input   [7:0]   snd_din,
    output  [7:0]   snd_dout,
    output          snd_mcu_wr,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [7:0]   psg_gain,
    // ROM
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [15:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,    

    // Sound output
    output  reg signed [15:0] ym_snd,
    output  sample
);

wire signed [15:0] fm_snd, adpcm_snd;
wire        [ 7:0] snd2_latch;

// It looks like the sound CPU never interacts with the MCU
// So I do not bother to fully connect it
assign snd_mcu_wr = 1'b0;
assign snd_dout   = 8'd0;

jtgng_sound #(.LAYOUT(3)) u_fmcpu (
    .rst        (  rst          ),
    .clk        (  clk          ),
    .cen3       (  cenfm        ),
    .cen1p5     (  cenfm        ), // unused
    .sres_b     (  1'b1         ),
`ifndef F1DREAM
    .snd_latch  (  snd_latch    ),
`else
    .snd_latch  (  snd_din      ), // from MCU
`endif
    .snd2_latch (  snd2_latch   ),
    .snd_int    (  1'b1         ), // unused
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_gain   (  psg_gain     ),
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    .ym_snd     (  fm_snd       ),
    .sample     (  sample       )
);

`ifndef F1DREAM
jttora_adpcm u_adpcmcpu(
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

always @(posedge clk) begin
    ym_snd <= jap ? (fm_snd>>>1) + adpcm_snd : fm_snd;
end

`else
// F1 Dream does not have the ADPCM section
always @(*) ym_snd = fm_snd;
`endif

endmodule // jtgng_sound