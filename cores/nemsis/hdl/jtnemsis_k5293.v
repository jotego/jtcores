/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  K0005293 Priority Handler
//================================================================================

`default_nettype none

module jtnemsis_k5293
(
	input             rst,
	input             clk,            // Pin 23
	input             pxl_cen,           // |

	input             shift_a1_clkd,  // Pin 18
	input             shift_a2_clkd,  // Pin 17
	input             shift_b_clkd,   // Pin 19
	input             h2_clkd,       // Pin 21
	input             h4_clkd,       // Pin 20

	output            tm_a_hflip,     // Pin 36
	output            tm_b_hflip,     // Pin 37

	// Pins 3–10, 15–16
	input      [ 3:0] tm_a_px_data,   // Tilemap A pixel data
	input             tm_a_px_trans,  // Tilemap A pixel is transparent (active low)
	input      [ 3:0] tm_b_px_data,   // Tilemap B pixel data
	input             tm_b_px_trans,  // Tilemap B pixel is transparent (active low)

	input             hflip,          // Pin 56

	input      [ 3:0] tile_priority,  // PR, Pins 11–14
	input             vhff,           // Pin 57
	input      [ 6:0] vram2_data,     // VC

	input      [15:0] obj_px_data,    // DQ

	output reg [10:0] color_ram_addr, // CD
	output reg [ 1:0] color_source,   // internal selected layer: 1=A, 2=B, 0=object

	input             h1_n            // Pin 22
);

wire [11:0]    tm_a_4hd_latched, tm_a_2hd_latched, tm_a_shift_a1_latched;
wire [10:0]    tm_a_shift_a2_latched;
wire [ 9:0]    tm_b_2hd_latched, tm_b_4hd_latched, tm_b_shift_b_latched;
wire [ 7:0]    obj_a_px_data_latched, obj_b_px_data_latched, obj_px_data_muxed;
wire [ 1:0]    tm_select;
wire [11:0]    tm_a_4hd_data;
wire [10:0]    tm_a_shift_a2_data;
wire [ 9:0]    tm_b_2hd_data;
wire [15:0]    obj_px_bus_latched;

`ifdef SIMULATION
wire [3:0] pri_tma_1;
wire [6:0] color_tma_1;
wire [3:0] pri_tma_2;
wire [6:0] color_tma_2;
wire [3:0] pri_tma_3;
wire [6:0] color_tma_3;
wire [3:0] pri_tma_4;
wire [6:0] color_tma_4;
wire [1:0] pri_tmb_1;
wire [6:0] color_tmb_1;
wire [1:0] pri_tmb_2;
wire [6:0] color_tmb_2;
wire [1:0] pri_tmb_3;
wire [6:0] color_tmb_3;
`endif

`ifdef SIMULATION
assign pri_tma_1 = { tm_a_4hd_latched[10], tm_a_4hd_latched[11], tm_a_4hd_latched[9], tm_a_4hd_latched[8] };
assign color_tma_1 = tm_a_4hd_latched[6:0];
assign pri_tma_2 = { tm_a_2hd_latched[10], tm_a_2hd_latched[11], tm_a_2hd_latched[9], tm_a_2hd_latched[8] };
assign color_tma_2 = tm_a_2hd_latched[6:0];
assign pri_tma_3 = { tm_a_shift_a1_latched[10], tm_a_shift_a1_latched[11], tm_a_shift_a1_latched[9], tm_a_shift_a1_latched[8] };
assign color_tma_3 = tm_a_shift_a1_latched[6:0];
assign pri_tma_4 = { tm_a_shift_a2_latched[9], tm_a_shift_a2_latched[10], tm_a_shift_a2_latched[8], tm_a_shift_a2_latched[7] };
assign color_tma_4 = tm_a_shift_a2_latched[6:0];
assign pri_tmb_1 = tm_b_2hd_latched[9:8];
assign color_tmb_1 = tm_b_2hd_latched[6:0];
assign pri_tmb_2 = tm_b_4hd_latched[9:8];
assign color_tmb_2 = tm_b_4hd_latched[6:0];
assign pri_tmb_3 = tm_b_shift_b_latched[9:8];
assign color_tmb_3 = tm_b_shift_b_latched[6:0];
`endif

assign tm_a_hflip = tm_a_shift_a1_latched[7];
assign tm_b_hflip = tm_b_shift_b_latched[7];
assign obj_px_data_muxed = (~h1_n ^ hflip) ? obj_b_px_data_latched : obj_a_px_data_latched;
assign tm_a_4hd_data = {tile_priority[3:0], vhff, vram2_data[6:0]};
assign tm_a_shift_a2_data = {tm_a_shift_a1_latched[11:8], tm_a_shift_a1_latched[6:0]};
assign tm_b_2hd_data = {tile_priority[1:0], vhff, vram2_data[6:0]};
assign obj_b_px_data_latched = obj_px_bus_latched[15:8];
assign obj_a_px_data_latched = obj_px_bus_latched[7:0];

///////////////////
// Tilemap A Delay Line
///////////////////

///////////////////
// Tilemap B Delay Line
///////////////////

///////////////////
// Object Data Latch
///////////////////

///////////////////
// Priority Decoding PAL
///////////////////

///////////////////
// Output MUX
///////////////////

always @(posedge clk ) if( pxl_cen ) begin
	case( tm_select )
		2'b10: begin
			color_ram_addr <= { tm_a_shift_a2_latched[6:0], tm_a_px_data };
			color_source   <= 2'd1;
		end
		2'b11: begin
			color_ram_addr <= { tm_b_shift_b_latched[6:0], tm_b_px_data };
			color_source   <= 2'd2;
		end
		default: begin
			color_ram_addr <= { 3'd0, obj_px_data_muxed };
			color_source   <= 2'd0;
		end
	endcase
end

// Registered tile, object, and priority-chip instances.
jtnemsis_bus_ff #( .W( 12 ) ) u_tm_a_4hd_ff(
	.rst     ( rst            ),
	.clk     ( clk            ),
	.trig    ( h4_clkd       ),
	.d       ( tm_a_4hd_data ),
	.q       ( tm_a_4hd_latched ),
	.q_n     (                  )
);

jtnemsis_bus_ff #( .W( 12 ) ) u_tm_a_2hd_ff(
	.rst     ( rst            ),
	.clk     ( clk            ),
	.trig    ( h2_clkd       ),
	.d       ( tm_a_4hd_latched ),
	.q       ( tm_a_2hd_latched ),
	.q_n     (                  )
);

jtnemsis_bus_ff #( .W( 12 ) ) u_tm_a_shift_a1_ff(
	.rst     ( rst                 ),
	.clk     ( clk                 ),
	.trig    ( shift_a1_clkd       ),
	.d       ( tm_a_2hd_latched      ),
	.q       ( tm_a_shift_a1_latched ),
	.q_n     (                       )
);

jtnemsis_bus_ff #( .W( 11 ) ) u_tm_a_shift_a2_ff(
	.rst     ( rst                 ),
	.clk     ( clk                 ),
	.trig    ( shift_a2_clkd       ),
	.d       ( tm_a_shift_a2_data ),
	.q       ( tm_a_shift_a2_latched ),
	.q_n     (                       )
);

jtnemsis_bus_ff #( .W( 10 ) ) u_tm_b_2hd_ff(
	.rst     ( rst            ),
	.clk     ( clk            ),
	.trig    ( h2_clkd       ),
	.d       ( tm_b_2hd_data ),
	.q       ( tm_b_2hd_latched ),
	.q_n     (                  )
);

jtnemsis_bus_ff #( .W( 10 ) ) u_tm_b_4hd_ff(
	.rst     ( rst            ),
	.clk     ( clk            ),
	.trig    ( h4_clkd       ),
	.d       ( tm_b_2hd_latched ),
	.q       ( tm_b_4hd_latched ),
	.q_n     (                  )
);

jtnemsis_bus_ff #( .W( 10 ) ) u_tm_b_shift_a1_ff(
	.rst     ( rst                ),
	.clk     ( clk                ),
	.trig    ( shift_b_clkd       ),
	.d       ( tm_b_4hd_latched     ),
	.q       ( tm_b_shift_b_latched ),
	.q_n     (                      )
);

jtnemsis_bus_ff #( .W( 16 ) ) u_obj_ff(
	.rst     ( rst            ),
	.clk     ( clk            ),
	.trig    ( h1_n           ),
	.d       ( obj_px_data    ),
	.q       ( obj_px_bus_latched ),
	.q_n     (                  )
);

jtnemsis_gx400_priority_handler priority_handler
(
	.tm_a_pr       ( tm_a_shift_a2_latched[10:7] ), // PR4_TM-A, PR3_TM-A, PR2_TM-A, PR1_TM-A
	.tm_b_pr       ( tm_b_shift_b_latched[9:8  ] ), // PR2_TM-B, PR1_TM-B
	.obj_color     ( obj_px_data_muxed[3:0]      ),
	.tm_a_px_trans ( tm_a_px_trans             ), // Tilemap A pixel is transparent (active low)
	.tm_b_px_trans ( tm_b_px_trans             ), // Tilemap B pixel is transparent (active low)

	.s0_n          ( tm_select[0]                ),
	.s1_n          ( tm_select[1]                )
);

endmodule
