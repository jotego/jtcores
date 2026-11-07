/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  K0005292 Video Timing Generator
//================================================================================

`default_nettype none

module K005292
(
	input               i_MCLK,           // Main clock 48 MHz
	input               i_CEN6,           // 6 MHz
	input               i_RST_n,          // RESET signal on negative edge

	input               i_VFLP,           // Vertical Flip
	input               i_HFLP,           // Horizontal Flip
	input               i_INTER,          // inter/non -> non used (interlace/non-interlace)
	input               i_288_256,        // 288/256 resolution -> non used

	output              o_VBLANK_xx_n,    // inverted Vertical blank sync ?
	output              o_VBLANK_n,       // Vertical blank
	output              o_HBLANK_n,       // Horizontal blank == inverted o_256H
	input               i_DMA_n,          // DMA (used to reset the ORINC)

	output              o_CSYNC_n,        // sync clock from pin 33 for monitor CRT
	output              o_VSYNC_n,        // video sync from pin 10 for ?? connected to an external connector

	output       [8:0]  o_256H_1H,        // Horizontal Pixel counter
	output       [7:0]  o_128H_1H_x,      // Horizontal Pixel counter inverted (FLIP)
                                          // o_256H_x is created outside of this chip
	output              o_1H_n,           // Horizontal Pixel counter -> 1H inverted

	output              o_VCLK,           // output Video Clock pin 19 (same as Pixel Clock at 6 MHz?)

	// Scanline counter 9bit ( 256V..1V  )
	output       [7:0]  o_128V_1V,        // Scanline counter
	output              o_256V,           // Separate, because not really the 9th bit of the counter
	output       [7:0]  o_128V_1V_x,      // Scanline counter inverted (FLIP)

	input               i_ORINC,          // ORINC -> Object register increment
	output       [7:0]  o_OBJ_CNTR        // object counter
);


////////////////////////////////////////////////////////////////////////////////////////////////////
// init signals

`define H_CNT_RESET 9'd128
`define V_CNT_RESET 9'd248

reg [8:0]     r_H_cnt = `H_CNT_RESET;
reg [8:0]     r_V_cnt = `V_CNT_RESET;


////////////////////////////////////////////////////////////////////////////////////////////////////
// Horizontal COUNTER
//
// This is the simulated counter made of 1x 74ls74 + 2x 74ls161 (u11a, u1, u2) Raki schematics

always @(posedge i_MCLK) begin
	if( ~i_RST_n ) begin                    // if n_reset = 0
		r_H_cnt <= `H_CNT_RESET;            // 9 bits for the counter output
	end else if( i_CEN6 ) begin             // if i_CEN6 pulse = 1
		if( r_H_cnt[8:0] < 9'd511 ) begin
			r_H_cnt <= r_H_cnt + 9'd1;
		end else begin
			// re-set to the value in r_H_cnt memory register to d128 --> so the loop start
			// at 128 and then count up to 511 (so 383 H position)
			r_H_cnt[8:0] <= `H_CNT_RESET;
		end
	end
end

assign o_256H_1H[8:0] = r_H_cnt[8:0];

// ASSIGN HORIZONTAL FLIPPED COUNTER BUS
// 256H_x is created outside this custom chip
assign o_128H_1H_x[7:0] = {8{i_HFLP}} ^ r_H_cnt[7:0];

assign o_1H_n     = ~r_H_cnt[0];
assign o_HBLANK_n = r_H_cnt[8];


////////////////////////////////////////////////////////////////////////////////////////////////////
// VCLK/HSYNC GENERATOR
//
// (u5a, u6a, u12a, u15a) Raki schematics

// ~256H & ~64H & 32H
wire vclk_ff_d = &{ ~o_256H_1H[8], ~o_256H_1H[6], o_256H_1H[5] };

wire vclk, vclk_n;

bus_ff #( .W( 1 ) ) u_vclk_ff(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_MCLK       ),
	.trig    ( o_256H_1H[4] ), // 16H
	.d       ( vclk_ff_d    ),
	.q       ( vclk         ),
	.q_n     ( vclk_n       )
);

assign o_VCLK    = vclk;
assign o_CSYNC_n = &{ vclk_n, o_VSYNC_n };

// Generate a clock enable from vclk

reg vclk_prev, vclk_cen;

always @( posedge i_MCLK ) begin
	if( ~i_RST_n ) begin
		vclk_prev <= 1'b1;
	end else begin
		vclk_prev <= vclk;
		vclk_cen <= vclk && ~vclk_prev;
	end
end


////////////////////////////////////////////////////////////////////////////////////////////////////
// Vertical COUNTER
//
// This is the simulated counter made of 1x 74ls74 + 2x 74ls161 (u12b, u3, u7) Raki schematics

// VBLANK_xx fix to be like real K5292 and not like bootleg.

wire gen_vblank_n = ( r_V_cnt <= 9'd494 && r_V_cnt >= 9'd271 );

reg r_VBLANK_n = 1'b1;
reg r_VBLANK_xx_n = 1'b1;

always @( posedge i_MCLK ) begin
	if( ~i_RST_n ) begin                    // if n_reset = 0
		r_V_cnt <=  `V_CNT_RESET;           // 9 bits for the counter output
	end else if( vclk_cen ) begin           // if r_VCLK pulse = 1
		if( r_V_cnt[8:0] < 9'd511 ) begin
			r_V_cnt <= r_V_cnt + 9'd1;
			r_VBLANK_n <= gen_vblank_n;
			r_VBLANK_xx_n <= gen_vblank_n;
		end else begin
			// re-set to the value in r_H_cnt memory register to d248 --> so the loop start
			// at 248 and then count up to 511 (so 263 V position)
			r_V_cnt[8:0] <= `V_CNT_RESET;
			// VBLANK** goes high when vcounter = 248
			r_VBLANK_xx_n <= 1'b1;
		end
	end
end

assign o_VBLANK_n = r_VBLANK_n;
assign o_VBLANK_xx_n = r_VBLANK_xx_n;

// ASSIGN SCANLINE COUNTER BUS
// o_256V is setup differently
assign o_128V_1V[7:0] = r_V_cnt[7:0];

// ASSIGN SCANLINE FLIPPED COUNTER BUS
assign o_128V_1V_x[7:0] = {8{i_VFLP}} ^ r_V_cnt[7:0];

assign o_VSYNC_n = r_V_cnt[8];


////////////////////////////////////////////////////////////////////////////////////////////////////
// Vertical BLANK Generator
//
// (u6b, u17c, u16a) Raki schematics

// Done in vertical counter block, for consistency with HBLANK_n and VBLANK_xx_n.


////////////////////////////////////////////////////////////////////////////////////////////////////
// Vertical BLANK xx (is it half the vblank?)
//
// (u11b, u14c) Raki schematics

// Done in vertical counter block, as the bootleg is different from the original hardware.


////////////////////////////////////////////////////////////////////////////////////////////////////
// o_256V signal generator
//
// (u11b, u16b) Raki schematics

wire w_256v, w_256v_n;

bus_ff #( .W( 1 ) ) u_256v_ff2(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_MCLK       ),
	.trig    ( ~r_VBLANK_n  ),
	.d       ( w_256v_n     ),
	.q       ( w_256v       ),
	.q_n     ( w_256v_n     )
);

assign o_256V = w_256v;

////////////////////////////////////////////////////////////////////////////////////////////////////
// OBJECT COUNTER
//
// (u4a, u4b, u5c) Raki schematics

reg       orinc_prev;
reg [7:0] obj_cnt = 8'd0;

always @( posedge i_MCLK ) begin
	if( ~i_RST_n | ~i_DMA_n ) begin
		orinc_prev <= 1'b1;
		obj_cnt <= 8'd0;
	end else if( ~i_ORINC & orinc_prev ) begin // negative edge
		obj_cnt <= obj_cnt + 4'd1;
	end
	
	orinc_prev <= i_ORINC;
end

assign o_OBJ_CNTR = obj_cnt;

endmodule
