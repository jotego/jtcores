/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-8-2020 */

module jtsf_sound #(
    parameter SND1W = 15,
    parameter SND2W = 18
) (
    input              rst,
    input              clk,
    input       [ 1:0] pcm_level,
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
    output               sample,
    output reg           peak
);
`ifndef NOSOUND
// Sound effects via FM seem too loud compared to music
// but that's the way the game is
// Some PCM samples seem to have been recorded with clipping
localparam [7:0] FM_GAIN  = 8'h08;

wire signed [12:0] adpcm_snd;
wire signed [15:0] fm_left, fm_right;
wire               cen1p5, adpcm_sample;

wire               cen_fm, cen_fm2, cenp384;
wire               cen3, cen_alt, cen3p5, cen1p7;
wire               peak_l, peak_r;
reg         [ 7:0] pcm_gain;

assign cen_alt = cen3;
//assign cen_fm  = cen3;
//assign cen_fm2 = cen1p5;
assign cen_fm  = cen3p5;
assign cen_fm2 = cen1p7;

always @(posedge clk) peak <= peak_l | peak_r;

always @(posedge clk) begin
    case( pcm_level )
        2'd0: pcm_gain <= 8'h04;
        2'd1: pcm_gain <= 8'h06;
        2'd2: pcm_gain <= 8'h08;
        2'd3: pcm_gain <= 8'h0C;
    endcase
end

jtframe_cen48 u_cenalt(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen6   (           ),
    .cen6b  (           ),
    .cen4   (           ),
    .cen3   ( cen3      ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5 ( cen1p5    ),
    .cen1p5b(           )
);


jtframe_cen3p57 u_cen (
    .clk        ( clk       ),
    .cen_3p57   ( cen3p5    ),
    .cen_1p78   ( cen1p7    )
);

jtframe_cenp384 u_cenp384(
    .clk      ( clk       ),
    .cen_p384 ( cenp384   )
);

jtbiocom_sound #(.LAYOUT(9),.RECOVERY(1)) u_fmcpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
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
    .snd        ( adpcm_snd     ),
    .sample     ( adpcm_sample  )
);

jtframe_mixer #(.W0(16),.W1(13)) u_left_mix(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_fm2   ),
    // input signals
    .ch0    ( fm_left   ),
    .ch1    ( adpcm_snd ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FM_GAIN   ),
    .gain1  ( pcm_gain  ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);

jtframe_mixer #(.W0(16),.W1(13)) u_right_mix(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_fm2   ),
    // input signals
    .ch0    ( fm_right  ),
    .ch1    ( adpcm_snd ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FM_GAIN   ),
    .gain1  ( pcm_gain  ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( right     ),
    .peak   ( peak_r    )
);
`else
    assign rom_addr  = 0;
    assign rom_cs    = 0;
    assign rom2_addr = 0;
    assign rom2_cs   = 0;
    assign left      = 0;
    assign right     = 0;
    assign sample    = 0;
    initial peak     = 0;
`endif
endmodule