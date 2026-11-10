/*
	This file is derived from JTFRAME.
	JTFRAME program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JTFRAME program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter:  @topapate
	Author: Olivier Scherler.  Mastodon: @oscherler@tooting.ch
	Version: 1.0
	Date: 15-02-2022
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.
*/

//================================================================================
//  Clock-Enable Generator for GX400
//================================================================================

// Generates clock enable signals for GX400
// 
// MiSTer with jtframe has a 48 MHz main clock and expects a 6 MHz clock enable
// for the pixel clock and a 12 MHz clock enable for HDMI.
// 
// The main GX400 oscillator is at 18.432 MHz. The main CPU takes half of that, 9.216 MHz.
// Therefore if we generate 12 MHz (48 div 4), 9 MHz (48 x 3 div 16), and 6 MHz (48 div 8)
// from the main MiSTer clock, which we push up by 2.4% to 49.152 MHz, then we get an
// accurate 9.216 MHz main clock and 6.144 MHz pixel clock.
// 
// The main audio oscillator is at 14.318 MHz, and is immediately divided by 4, which
// is 3.5795 MHz, for the K5289. It is further divided by 2 (1.78975 MHz) for the Z80
// and AY3-8910s, and again by 32 for the LS393 counter on AY3-8910 8E. Therefore,
// 3.5795 MHz can be generated from 49.152 MHz by dividing it by 13.7315, which is
// approximated by the fraction 563/41 = 13.7317073171.
// 
// https://www.bee-man.us/math/fraction_approximation.htm

/*
https://wavedrom.com/editor.html
With GX400_ADJUSTED_PLL:

{ signal: [
  { name: 'clk48', wave: 'p................................................' },
  {},
  { name: 'cen12', wave: '010..10..10..10..10..10..10..10..10..10..10..10..' },
  { name: 'cen6',  wave: '010......10......10......10......10......10......' },
  { name: 'cen9',  wave: '010....10...10...10....10...10...10....10...10...' },
] }
*/

`default_nettype none

module jtnemsis_gx400_cen(
    input  clk,     // 48 MHz
    input  vsync60,

    output cen_12,
    output cen_6,
    output cen_6b,
    output clk6,
    output cen_9,
    output cen_3p5,
    output cen_1p7,
    output audio_div_cen
);

wire       cen9_unused;
wire [1:0] cpu_cen_bus;
wire [1:0] video_cen_bus;
wire [9:0] m_video;
wire [6:0] audio_cens;
reg  [2:0] clk6_holder = 3'b0;

assign m_video = vsync60 ? 10'd131 : 10'd128;

assign clk6          = ~(clk6_holder > 3'd4);
assign cen_6b        = clk6_holder == 3'd4;
assign cen_3p5       = audio_cens[0];
assign cen_1p7       = audio_cens[1];
assign audio_div_cen = audio_cens[6];
assign {cen9_unused, cen_9} = cpu_cen_bus;
assign {cen_6, cen_12} = video_cen_bus;

always @(posedge clk) begin
    if (cen_6) begin
        clk6_holder <= 3'b0;
    end else begin
        clk6_holder <= clk6_holder + 3'b1;
    end
end

// CPU clock enable: 9.000 MHz at 48 MHz input or 9.216 MHz at 49.152 MHz.
jtframe_frac_cen u_cpucen(
    .clk   (clk),
    .n     (10'd24),
    .m     (10'd128),
    .cen   (cpu_cen_bus),
    .cenb  ()
);

// Pixel and HDMI clock enables.
jtframe_frac_cen u_videocen(
    .clk   (clk),
    .n     (10'd32),
    .m     (m_video),
    .cen   (video_cen_bus),
    .cenb  ()
);

// Audio enables: 3.5795 MHz, then divide-by-two stages through 111.86 kHz.
jtframe_frac_cen #(.W(7), .WC(12)) u_audiocen(
    .clk   (clk),
    .n     (12'd67),
    .m     (12'd920),
    .cen   (audio_cens),
    .cenb  ()
);

endmodule
