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

	Author: Jose Tejada Gomez. Twitter: @topapate
	Author: Olivier Scherler.  Twitter: @oscherler
	Version: 1.0
	Date: 15-02-2022
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

module gx400_cen(
	input      i_clk,     // 48 MHz
	input      i_vsync60,

	output     o_cen12,
	output     o_cen6,
	output     o_cen6b,
	output     o_clk6,
	output     o_cen9,
	output     o_cen3p5,
	output     o_cen1p7,
	output     o_cen_audio_clk_div
);

// With 48.000 MHz clock: o_cen9 = i_clk * 96 / 500, o_cen12 = i_clk * 96 / 375
// With 49.152 MHz clock: o_cen9 = i_clk * 96 / 512, o_cen12 = i_clk * 96 / 384

localparam        WC     = 10; // enough for largest parameter (which is 500 or 512)

jtframe_frac_cen #( .W(2) ) u_cpucen(
	.clk        ( i_clk      ), // input 48 MHz
	.n          ( 10'd24     ),
	.m          ( 10'd128    ),
	.cen        ( o_cen9     ), // output 9'216'000 Hz
	.cenb       (            )
);

/////

wire [9:0] m_video = i_vsync60 ? 10'd131 : 10'd128;

jtframe_frac_cen #( .W(2) ) u_videocen(
	.clk        ( i_clk               ), // input 48 MHz
	.n          ( 10'd32              ),
	.m          ( m_video             ),
	.cen        ( { o_cen6, o_cen12 } ), // output 12.288 MHz and 6.144 MHz or 12.000 MHz and 6.000 MHz
	.cenb       (                     )
);

reg [2:0] clk6_holder = 3'b0;

always @( posedge i_clk ) begin
	if( o_cen6 ) begin
		clk6_holder <= 3'b0;
	end else begin
		clk6_holder <= clk6_holder + 3'b1;
	end
end

// generate clk6 and o_cen6b to match 2/3 duty cycle of pixel clock on original hardware
assign o_clk6 = ~( clk6_holder > 3'd4 );
assign o_cen6b = clk6_holder == 3'd4;

/////

wire [6:0] audio_cens;

jtframe_frac_cen #( .W(7), .WC(12) ) u_audiocen(
	.clk        ( i_clk      ), // input 48 MHz
	.n          ( 12'd67     ),
	.m          ( 12'd920    ),
	// .n          ( 12'd251    ), // temporary faster clock to match Alamone recording
	// .m          ( 12'd3442   ),
	.cen        ( audio_cens ), // output 3'579'546 Hz, and 6 divisions
	.cenb       (            )
);

assign o_cen3p5 = audio_cens[0];
assign o_cen1p7 = audio_cens[1];
assign o_cen_audio_clk_div = audio_cens[6];

endmodule
