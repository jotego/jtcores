/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-only
// Date: 2026-11-08

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

module jtnemsis_k5292
(
	input               rst_n,          // RESET signal on negative edge
	input               clk,            // Master clock 49.152 MHz
	input               pxl_cen,        // 6.144 MHz pixel enable

	input               vflp,           // Vertical Flip
	input               hflp,           // Horizontal Flip
	input               inter,          // inter/non -> non used (interlace/non-interlace)
	input               resolution_288_256,        // 288/256 resolution -> non used

	output reg          vblank_xx_n,    // inverted Vertical blank sync ?
	output reg          vblank_n,       // Vertical blank
	output              hblank_n,       // Horizontal blank == inverted o_256H
	input               dma_n,          // DMA (used to reset the ORINC)

	output              csync_n,        // sync clock from pin 33 for monitor CRT
	output              vsync_n,        // video sync from pin 10 for ?? connected to an external connector

	output       [8:0]  h256_h1,        // Horizontal Pixel counter
	output       [7:0]  h128_h1_x,      // Horizontal Pixel counter inverted (FLIP)
                                          // o_256H_x is created outside of this chip
	output              h1_n,           // Horizontal Pixel counter -> 1H inverted

	output              vclk,           // Physical video-clock level at pin 19

	// Scanline counter 9bit ( 256V..1V  )
	output       [7:0]  v128_v1,        // Scanline counter
	output              v256,           // Separate, because not really the 9th bit of the counter
	output       [7:0]  v128_v1_x,      // Scanline counter inverted (FLIP)

	input               orinc,          // ORINC -> Object register increment
	output       [7:0]  obj_cntr        // object counter
);


////////////////////////////////////////////////////////////////////////////////////////////////////
// init signals

`define H_CNT_RESET 9'd128
`define V_CNT_RESET 9'd248

reg [8:0]     h_count = `H_CNT_RESET;

// Module-scope signal declarations.
reg [8:0]     v_count = `V_CNT_RESET;


////////////////////////////////////////////////////////////////////////////////////////////////////
// VCLK/HSYNC GENERATOR
//
// (u5a, u6a, u12a, u15a) Raki schematics

// ~256H & ~64H & 32H
wire vclk_ff_d;

wire vclk_n;

// Generate a clock enable from vclk

reg vclk_prev, vclk_cen;


////////////////////////////////////////////////////////////////////////////////////////////////////
// Vertical COUNTER
//
// This is the simulated counter made of 1x 74ls74 + 2x 74ls161 (u12b, u3, u7) Raki schematics

// VBLANK_xx fix to be like real K5292 and not like bootleg.

wire gen_vblank_n;


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

wire v256_internal_n;
wire reset, vblank_active;

////////////////////////////////////////////////////////////////////////////////////////////////////
// OBJECT COUNTER
//
// (u4a, u4b, u5c) Raki schematics

reg       orinc_prev;
reg [7:0] obj_cnt = 8'd0;

// Continuous signal equations.

assign h256_h1[8:0] = h_count[8:0];

// ASSIGN HORIZONTAL FLIPPED COUNTER BUS
// 256H_x is created outside this custom chip
assign h128_h1_x[7:0] = {8{hflp}} ^ h_count[7:0];

assign h1_n     = ~h_count[0];
assign hblank_n = h_count[8];
assign vclk_ff_d = &{ ~h256_h1[8], ~h256_h1[6], h256_h1[5] };

assign csync_n = &{ vclk_n, vsync_n };
assign gen_vblank_n = ( v_count <= 9'd494 && v_count >= 9'd271 );

// ASSIGN SCANLINE COUNTER BUS
// o_256V is setup differently
assign v128_v1[7:0] = v_count[7:0];

// ASSIGN SCANLINE FLIPPED COUNTER BUS
assign v128_v1_x[7:0] = {8{vflp}} ^ v_count[7:0];

assign vsync_n = v_count[8];

assign obj_cntr = obj_cnt;
assign reset = ~rst_n;
assign vblank_active = ~vblank_n;

// Sequential and combinational processes.


////////////////////////////////////////////////////////////////////////////////////////////////////
// Horizontal COUNTER
//
// This is the simulated counter made of 1x 74ls74 + 2x 74ls161 (u11a, u1, u2) Raki schematics

always @(posedge clk) begin
	if( ~rst_n ) begin                    // if n_reset = 0
		h_count <= `H_CNT_RESET;            // 9 bits for the counter output
	end else if( pxl_cen ) begin             // Pixel-clock enable pulse is active
		if( h_count[8:0] < 9'd511 ) begin
			h_count <= h_count + 9'd1;
		end else begin
			// re-set to the value in horizontal counter reset value d128 --> so the loop start
			// at 128 and then count up to 511 (so 383 H position)
			h_count[8:0] <= `H_CNT_RESET;
		end
	end
end

always @( posedge clk ) begin
	if( ~rst_n ) begin
		vclk_prev <= 1'b1;
	end else begin
		vclk_prev <= vclk;
		vclk_cen <= vclk && ~vclk_prev;
	end
end

initial begin
	vblank_n = 1'b1;
	vblank_xx_n = 1'b1;
end

always @( posedge clk ) begin
	if( ~rst_n ) begin                    // if n_reset = 0
		v_count <=  `V_CNT_RESET;           // 9 bits for the counter output
	end else if( vclk_cen ) begin           // generated video clock-enable pulse is active
		if( v_count[8:0] < 9'd511 ) begin
			v_count <= v_count + 9'd1;
			vblank_n <= gen_vblank_n;
			vblank_xx_n <= gen_vblank_n;
		end else begin
			// re-set to the value in vertical counter reset value d248 --> so the loop start
			// at 248 and then count up to 511 (so 263 V position)
			v_count[8:0] <= `V_CNT_RESET;
			// VBLANK** goes high when vcounter = 248
			vblank_xx_n <= 1'b1;
		end
	end
end

always @( posedge clk ) begin
	if( ~rst_n | ~dma_n ) begin
		orinc_prev <= 1'b1;
		obj_cnt <= 8'd0;
	end else if( ~orinc & orinc_prev ) begin // negative edge
		obj_cnt <= obj_cnt + 8'd1;
	end

	orinc_prev <= orinc;
end

// Chip and framework instances.

jtframe_ff #( .EDGE_RESET( 1'b1 ) ) u_vclk_ff(
    .rst     ( reset ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( vclk_ff_d ),
    .q       ( vclk ),
    .qn      ( vclk_n ),
    .set     ( 1'd0 ),
    .clr     ( 1'd0 ),
    .sigedge ( h256_h1[4] )
);

jtframe_ff #( .EDGE_RESET( 1'b1 ) ) u_256v_ff2(
    .rst     ( reset ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( v256_internal_n ),
    .q       ( v256 ),
    .qn      ( v256_internal_n ),
    .set     ( 1'd0 ),
    .clr     ( 1'd0 ),
    .sigedge ( vblank_active )
);
endmodule
