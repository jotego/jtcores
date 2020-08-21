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
    Date: 21-8-2020 */

module jtsf_sound #(
    parameter SND1W = 15,
    parameter SND2W = 15
) (
    input              rst,
    input              clk,
    // Interface with main CPU
    input       [ 7:0] snd_latch,
    input              snd_nmi_n,
    // ROM
    output [SND1W-1:0] rom_addr,
    output             rom_cs,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // ADPCM ROM
    output [SND2W-1:0] rom2_addr,
    output             rom2_cs,
    input       [ 7:0] rom2_data,
    input              rom2_ok,

    // Sound output
    output signed [15:0] left,
    output signed [15:0] right,
    output               sample
);

wire signed [12:0] adpcm_snd;
wire signed [15:0] fm_left, fm_right;

wire               cen_fm, cen_fm2, cenp384;

assign left  = fm_left  + {adpcm_snd,3'd0};
assign right = fm_right + {adpcm_snd,3'd0};

jtframe_cen3p57 #(.CLK24(1)) u_cen (
    .clk        ( clk       ),
    .cen_3p57   ( cen_fm    ),
    .cen_1p78   ( cen_fm2   )
);

jtframe_cenp384 #(.CLK24(1)) u_cenp384(
    .clk      ( clk       ),
    .cen_p384 ( cenp384   )
);

jtbiocom_sound #(.LAYOUT(9)) u_fm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_alt    ( cen_fm    ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    // Interface with main CPU
    .snd_latch  ( snd_latch ),
    .nmi_n      ( snd_nmi_n ),
    // Interface with MCU - Used by Bionic Commando only
    .snd_din    (           ),
    .snd_dout   (           ),
    .snd_mcu_wr (           ),
    .snd_mcu_rd (           ),
    // ROM
    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    // Sound output
    .left       ( fm_left   ),
    .right      ( fm_right  ),
    .sample     ( sample    )
);

jtsf_adpcm u_adpcmcpu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cen_fm        ),
    .cenp384    ( cenp384       ),
    // Interface with second CPU
    .snd_latch  ( snd_latch     ),
    // ADPCM ROM
    .rom2_addr  ( rom2_addr     ),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),
    // Sound output
    .snd        ( adpcm_snd     )
);

endmodule