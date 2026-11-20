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
//  K0005290 Tileline Latch
//================================================================================

`default_nettype none

// These ascending 4-bit buses preserve the PCB's first-to-last pixel naming
// and the existing nibble rotation. Keep their declared range for bit order.
/* verilator lint_off ASCRANGE */

module jtnemsis_k5290
(
	input                 rst,            // RESET signal on pos edge
	input                 clk,            // Main clock 48 MHz
	input                 pxl_cen,        // clock Pixel 6MHz

	input                 aff,            // Tile A Flip
	input                 bff,            // Tile B Flip

	input                 u9e_pin3,       // PCB U9E pin 3
	input                 u9e_pin11,      // PCB U9E pin 11
	input                 u9e_pin6,       // PCB U9E pin 6
	input                 u9e_pin8,      // PCB U9E pin 8

	input          [0:3]  a,              // Input 4bit data from char ram
	input          [0:3]  b,              // Input 4bit data from char ram
	input          [0:3]  c,              // Input 4bit data from char ram
	input          [0:3]  d,              // Input 4bit data from char ram
	input          [0:3]  e,              // Input 4bit data from char ram
	input          [0:3]  f,              // Input 4bit data from char ram
	input          [0:3]  g,              // Input 4bit data from char ram
	input          [0:3]  h,              // Input 4bit data from char ram

	input                 hd2,            // Horizontal Pixel (counter bus)
	input                 hd4_n,          // Horizontal Pixel (counter bus)

	output                tm_a_px_trans,  // Tilemap A pixel is transparent (active low)
	output         [3:0]  tm_a_pixels,    // Tilemap A pixel data

	output                tm_b_px_trans,  // Tilemap B pixel is transparent (active low)
	output  reg    [3:0]  tm_b_pixels     // Tilemap B pixel data
);

////////////////////////////////////////////////////////////////////////////////////////////////////
// init signals

wire      TM_A_pixel_latch;
wire      TM_B_pixel_latch;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Clocks

reg CLK_INTL2;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Tile Map A

wire [7:0] TM_A_px_bits_0_latched; // latched
wire [7:0] TM_A_px_bits_1_latched; // latched
wire [7:0] TM_A_px_bits_2_latched; // latched
wire [7:0] TM_A_px_bits_3_latched; // latched

wire [7:0] TM_A_px_bit_0_flipped;

wire [7:0] TM_A_px_bit_1_flipped;

wire [7:0] TM_A_px_bit_2_flipped;

wire [7:0] TM_A_px_bit_3_flipped;
wire [7:0] char_data_0, char_data_1, char_data_2, char_data_3;
wire [1:0] tm_a_shift_mode, tm_b_shift_mode;

`ifdef SIMULATION

wire [0:3] db_TM_A_px_0_latched;
wire [0:3] db_TM_A_px_7_latched;

`endif
// MUX U13 with AFF as selector
reg [3:0] TM_A_px_early;

`ifdef SIMULATION
	wire [3:0] u13_a;
	wire [3:0] u13_b;
`endif

wire [3:0] TM_A_px_0_delayed;

wire [3:0] TM_A_px_1_delayed;

wire [3:0] TM_A_px_2_delayed;

wire [3:0] TM_A_px_3_delayed;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Tile Map B

wire [7:0] TM_B_px_bits_0_latched; // latched
wire [7:0] TM_B_px_bits_1_latched; // latched
wire [7:0] TM_B_px_bits_2_latched; // latched
wire [7:0] TM_B_px_bits_3_latched; // latched

wire [7:0] TM_B_px_bit_0_flipped;

wire [7:0] TM_B_px_bit_1_flipped;

wire [7:0] TM_B_px_bit_2_flipped;

wire [7:0] TM_B_px_bit_3_flipped;

`ifdef SIMULATION

wire [0:3] db_TM_B_px_0_latched;
wire [0:3] db_TM_B_px_7_latched;

`endif

wire [7:0] tm_a_pixel_latch_edge_8;
wire [7:0] tm_b_pixel_latch_edge_8;

assign tm_a_pixel_latch_edge_8 = {8{TM_A_pixel_latch}};
assign tm_b_pixel_latch_edge_8 = {8{TM_B_pixel_latch}};

assign TM_A_pixel_latch = ~(~hd4_n & hd2);
assign TM_B_pixel_latch = ~(hd4_n & hd2);
assign char_data_0 = {h[0], g[0], f[0], e[0], d[0], c[0], b[0], a[0]};
assign char_data_1 = {h[1], g[1], f[1], e[1], d[1], c[1], b[1], a[1]};
assign char_data_2 = {h[2], g[2], f[2], e[2], d[2], c[2], b[2], a[2]};
assign char_data_3 = {h[3], g[3], f[3], e[3], d[3], c[3], b[3], a[3]};
assign tm_a_shift_mode = {u9e_pin11, u9e_pin3};
assign tm_b_shift_mode = {u9e_pin8, u9e_pin6};

`ifdef SIMULATION
assign u13_a = {TM_A_px_bit_0_flipped[0], TM_A_px_bit_1_flipped[0], TM_A_px_bit_2_flipped[0], TM_A_px_bit_3_flipped[0]};
assign u13_b = {TM_A_px_bit_0_flipped[7], TM_A_px_bit_1_flipped[7], TM_A_px_bit_2_flipped[7], TM_A_px_bit_3_flipped[7]};
assign db_TM_A_px_0_latched = {TM_A_px_bits_0_latched[0], TM_A_px_bits_1_latched[0], TM_A_px_bits_2_latched[0], TM_A_px_bits_3_latched[0]};
assign db_TM_A_px_7_latched = {TM_A_px_bits_0_latched[7], TM_A_px_bits_1_latched[7], TM_A_px_bits_2_latched[7], TM_A_px_bits_3_latched[7]};
assign db_TM_B_px_0_latched = {TM_B_px_bits_0_latched[0], TM_B_px_bits_1_latched[0], TM_B_px_bits_2_latched[0], TM_B_px_bits_3_latched[0]};
assign db_TM_B_px_7_latched = {TM_B_px_bits_0_latched[7], TM_B_px_bits_1_latched[7], TM_B_px_bits_2_latched[7], TM_B_px_bits_3_latched[7]};
`endif

// Using the main clock with a clock enable in jtnemsis_lmn74194_nbit would
// add one cycle of delay, so only CLK_INTL2 is delayed by one main-clock cycle.

// output pixel data (4bits)
// bits put back in order compared to schematic
assign tm_a_pixels = { TM_A_px_3_delayed[3], TM_A_px_2_delayed[3], TM_A_px_1_delayed[3], TM_A_px_0_delayed[3] };

// U29b output transparency flag
assign tm_a_px_trans = (tm_a_pixels == 4'b0)  ?  1'b0 : 1'b1;

// U29a output transparency flag Tile Map B
assign tm_b_px_trans = (tm_b_pixels == 4'b0)  ?  1'b0 : 1'b1;

always @( posedge clk ) begin
	CLK_INTL2 <= pxl_cen;
end

always @( posedge clk ) begin
	case( aff )
		// bits put back in order compared to schematic
		1'b0:   TM_A_px_early <= { TM_A_px_bit_0_flipped[0], TM_A_px_bit_1_flipped[0], TM_A_px_bit_2_flipped[0], TM_A_px_bit_3_flipped[0] };
		1'b1:   TM_A_px_early <= { TM_A_px_bit_0_flipped[7], TM_A_px_bit_1_flipped[7], TM_A_px_bit_2_flipped[7], TM_A_px_bit_3_flipped[7] };
	endcase
end
// MUX U33 with BFF as selector
// output pixel data (4bits) Tile Map B
always @( posedge clk ) begin
	case( bff )
		// bits put back in order compared to schematic
		1'b0:   tm_b_pixels <= { TM_B_px_bit_0_flipped[0], TM_B_px_bit_1_flipped[0], TM_B_px_bit_2_flipped[0], TM_B_px_bit_3_flipped[0] };
		1'b1:   tm_b_pixels <= { TM_B_px_bit_0_flipped[7], TM_B_px_bit_1_flipped[7], TM_B_px_bit_2_flipped[7], TM_B_px_bit_3_flipped[7] };
	endcase
end

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U1(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_0 ),
    .q       ( TM_A_px_bits_0_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_a_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U2U3(
	.D      ( TM_A_px_bits_0_latched    ), // parallel input
	.S      ( tm_a_shift_mode ), // mode select
	.clk   ( clk                    ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_0_flipped     )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U4(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_1 ),
    .q       ( TM_A_px_bits_1_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_a_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U5U6(
	.D      ( TM_A_px_bits_1_latched    ), // parallel input
	.S      ( tm_a_shift_mode ), // mode select
	.clk   ( clk                    ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_1_flipped     )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U7(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_2 ),
    .q       ( TM_A_px_bits_2_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_a_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U8U9(
	.D      ( TM_A_px_bits_2_latched    ), // parallel input
	.S      ( tm_a_shift_mode ), // mode select
	.clk   ( clk                    ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_2_flipped     )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U10(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_3 ),
    .q       ( TM_A_px_bits_3_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_a_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U11U12(
	.D      ( TM_A_px_bits_3_latched    ), // parallel input
	.S      ( tm_a_shift_mode ), // mode select
	.clk   ( clk                    ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_3_flipped     )  // parallel output
);
jtnemsis_lmn74194_nbit
U14
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.clk   ( clk            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[0]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_0_delayed )  // parallel output
);

jtnemsis_lmn74194_nbit
U15
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.clk   ( clk            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[1]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_1_delayed )  // parallel output
);

jtnemsis_lmn74194_nbit
U34
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.clk   ( clk            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[2]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_2_delayed )  // parallel output
);

jtnemsis_lmn74194_nbit
U16
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.clk   ( clk            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[3]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_3_delayed )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U17(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_0 ),
    .q       ( TM_B_px_bits_0_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_b_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U18U19(
	.D      ( TM_B_px_bits_0_latched   ), // parallel input
	.S      ( tm_b_shift_mode ), // mode select
	.clk   ( clk                   ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_0_flipped    )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U20(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_1 ),
    .q       ( TM_B_px_bits_1_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_b_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U21U22(
	.D      ( TM_B_px_bits_1_latched    ), // parallel input
	.S      ( tm_b_shift_mode ), // mode select
	.clk   ( clk                    ), // main clock
	.cen   (pxl_cen), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_B_px_bit_1_flipped     )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U23(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_2 ),
    .q       ( TM_B_px_bits_2_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_b_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U24U25(
	.D      ( TM_B_px_bits_2_latched   ), // parallel input
	.S      ( tm_b_shift_mode ), // mode select
	.clk   ( clk                   ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_2_flipped    )  // parallel output
);

// Octal D-type flip-flop latch with reset; positive-edge trigger
jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) U26(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( char_data_3 ),
    .q       ( TM_B_px_bits_3_latched ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( tm_b_pixel_latch_edge_8 )
);

// 8-bit bidirectional universal shift register
jtnemsis_lmn74194_nbit #( .N( 8 ) )
U27U28(
	.D      ( TM_B_px_bits_3_latched   ), // parallel input
	.S      ( tm_b_shift_mode ), // mode select
	.clk   ( clk                   ), // main clock
	.cen    ( pxl_cen                    ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_3_flipped    )  // parallel output
);

endmodule

/* verilator lint_on ASCRANGE */
