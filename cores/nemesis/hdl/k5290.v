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
//  K0005290 Tileline Latch
//================================================================================

`default_nettype none

module K005290
(
	input                 i_MCLK,           // Main clock 48 MHz
	input                 i_RST,            // RESET signal on pos edge
	input                 i_CLK_px6,        // clock Pixel 6MHz

	input                 i_AFF,            // Tile A Flip
	input                 i_BFF,            // Tile B Flip

	input                 i_9E_pin3,        // 
	input                 i_9E_pin11,       // 
	input                 i_9E_pin6,        // 
	input                 i_9E_pin8,        // 

	input          [0:3]  i_A,              // Input 4bit data from char ram
	input          [0:3]  i_B,              // Input 4bit data from char ram
	input          [0:3]  i_C,              // Input 4bit data from char ram
	input          [0:3]  i_D,              // Input 4bit data from char ram
	input          [0:3]  i_E,              // Input 4bit data from char ram
	input          [0:3]  i_F,              // Input 4bit data from char ram
	input          [0:3]  i_G,              // Input 4bit data from char ram
	input          [0:3]  i_H,              // Input 4bit data from char ram

	input                 i_2HD,            // Horizontal Pixel (counter bus)
	input                 i_4HD_n,          // Horizontal Pixel (counter bus)

	output                o_TM_A_px_trans,  // Tilemap A pixel is transparent (active low)
	output         [3:0]  o_TM_A_pixels,    // Tilemap A pixel data

	output                o_TM_B_px_trans,  // Tilemap B pixel is transparent (active low)
	output  reg    [3:0]  o_TM_B_pixels     // Tilemap B pixel data
);

////////////////////////////////////////////////////////////////////////////////////////////////////
// init signals

wire      TM_A_pixel_latch;
wire      TM_B_pixel_latch;

assign    TM_A_pixel_latch = ~( ~i_4HD_n & i_2HD );
assign    TM_B_pixel_latch = ~(  i_4HD_n & i_2HD );


////////////////////////////////////////////////////////////////////////////////////////////////////
// Clocks

wire CLK_INTL0, CLK_INTL1;
reg  CLK_INTL2;

// using the main clock and a clock-enable in lmn74194_nbit results in a
// delay in operation by one clock cycle, so we subtract this delay here
// by only delaying CLK_INTL2 by one clock cycle, instead if delaying
// CLK_INTL0 and CLK_INTL1 by one clock cycle, and CLK_INTL2 by 2, as we
// had before when we had always @( posedge cen or posedge clr ) in lmn74194_nbit
assign CLK_INTL0 = i_CLK_px6;
assign CLK_INTL1 = i_CLK_px6;

always @( posedge i_MCLK ) begin
	CLK_INTL2 <= CLK_INTL0;
end

////////////////////////////////////////////////////////////////////////////////////////////////////
// Tile Map A

wire [7:0] TM_A_px_bits_0_latched; // latched
wire [7:0] TM_A_px_bits_1_latched; // latched
wire [7:0] TM_A_px_bits_2_latched; // latched
wire [7:0] TM_A_px_bits_3_latched; // latched

// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U1(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_A_pixel_latch       ),
	.d       ( { i_H[0], i_G[0], i_F[0], i_E[0], i_D[0], i_C[0], i_B[0], i_A[0] } ),
	.q       ( TM_A_px_bits_0_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U2U3(
	.D      ( TM_A_px_bits_0_latched    ), // parallel input
	.S      ( { i_9E_pin11, i_9E_pin3 } ), // mode select
	.mclk   ( i_MCLK                    ), // main clock
	.cen    ( CLK_INTL0                 ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_0_flipped     )  // parallel output
);

wire [7:0] TM_A_px_bit_0_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U4(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_A_pixel_latch       ),
	.d       ( { i_H[1], i_G[1], i_F[1], i_E[1], i_D[1], i_C[1], i_B[1], i_A[1] } ),
	.q       ( TM_A_px_bits_1_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U5U6(
	.D      ( TM_A_px_bits_1_latched    ), // parallel input
	.S      ( { i_9E_pin11, i_9E_pin3 } ), // mode select
	.mclk   ( i_MCLK                    ), // main clock
	.cen    ( CLK_INTL0                 ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_1_flipped     )  // parallel output
);

wire [7:0] TM_A_px_bit_1_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U7(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_A_pixel_latch       ),
	.d       ( { i_H[2], i_G[2], i_F[2], i_E[2], i_D[2], i_C[2], i_B[2], i_A[2] } ),
	.q       ( TM_A_px_bits_2_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U8U9(
	.D      ( TM_A_px_bits_2_latched    ), // parallel input
	.S      ( { i_9E_pin11, i_9E_pin3 } ), // mode select
	.mclk   ( i_MCLK                    ), // main clock
	.cen    ( CLK_INTL0                 ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_2_flipped     )  // parallel output
);

wire [7:0] TM_A_px_bit_2_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U10(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_A_pixel_latch       ),
	.d       ( { i_H[3], i_G[3], i_F[3], i_E[3], i_D[3], i_C[3], i_B[3], i_A[3] } ),
	.q       ( TM_A_px_bits_3_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U11U12(
	.D      ( TM_A_px_bits_3_latched    ), // parallel input
	.S      ( { i_9E_pin11, i_9E_pin3 } ), // mode select
	.mclk   ( i_MCLK                    ), // main clock
	.cen    ( CLK_INTL0                 ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_A_px_bit_3_flipped     )  // parallel output
);

wire [7:0] TM_A_px_bit_3_flipped;

`ifdef SIMULATION

wire [0:3] db_TM_A_px_0_latched = { TM_A_px_bits_0_latched[0], TM_A_px_bits_1_latched[0], TM_A_px_bits_2_latched[0], TM_A_px_bits_3_latched[0] };
wire [0:3] db_TM_A_px_7_latched = { TM_A_px_bits_0_latched[7], TM_A_px_bits_1_latched[7], TM_A_px_bits_2_latched[7], TM_A_px_bits_3_latched[7] };

`endif

// MUX U13 with AFF as selector
reg [3:0] TM_A_px_early;

always @( posedge i_MCLK ) begin
	case( i_AFF )
		// bits put back in order compared to schematic
		1'b0:   TM_A_px_early <= { TM_A_px_bit_0_flipped[0], TM_A_px_bit_1_flipped[0], TM_A_px_bit_2_flipped[0], TM_A_px_bit_3_flipped[0] };
		1'b1:   TM_A_px_early <= { TM_A_px_bit_0_flipped[7], TM_A_px_bit_1_flipped[7], TM_A_px_bit_2_flipped[7], TM_A_px_bit_3_flipped[7] };
	endcase
end

`ifdef SIMULATION
	wire [3:0] u13_a = { TM_A_px_bit_0_flipped[0], TM_A_px_bit_1_flipped[0], TM_A_px_bit_2_flipped[0], TM_A_px_bit_3_flipped[0] };
	wire [3:0] u13_b = { TM_A_px_bit_0_flipped[7], TM_A_px_bit_1_flipped[7], TM_A_px_bit_2_flipped[7], TM_A_px_bit_3_flipped[7] };
`endif

lmn74194_nbit #( .N( 4 ) )
U14
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.mclk   ( i_MCLK            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[0]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_0_delayed )  // parallel output
);

wire [3:0] TM_A_px_0_delayed;


lmn74194_nbit #( .N( 4 ) )
U15
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.mclk   ( i_MCLK            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[1]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_1_delayed )  // parallel output
);

wire [3:0] TM_A_px_1_delayed;


lmn74194_nbit #( .N( 4 ) )
U34
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.mclk   ( i_MCLK            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[2]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_2_delayed )  // parallel output
);

wire [3:0] TM_A_px_2_delayed;


lmn74194_nbit #( .N( 4 ) )
U16
(
	.D      ( 4'b1111           ), // parallel input
	.S      ( 2'b01             ), // mode select
	.mclk   ( i_MCLK            ), // main clock
	.cen    ( CLK_INTL2         ), // clock enable
	.clr    ( 1'b0              ), // clear
	.R      ( TM_A_px_early[3]  ), // right feed
	.L      ( 1'b1              ), // left feed
	.Q      ( TM_A_px_3_delayed )  // parallel output
);

wire [3:0] TM_A_px_3_delayed;


// output pixel data (4bits)
// bits put back in order compared to schematic
assign o_TM_A_pixels = { TM_A_px_3_delayed[3], TM_A_px_2_delayed[3], TM_A_px_1_delayed[3], TM_A_px_0_delayed[3] };

// U29b output transparency flag
assign o_TM_A_px_trans = (o_TM_A_pixels == 4'b0)  ?  1'b0 : 1'b1;


////////////////////////////////////////////////////////////////////////////////////////////////////
// Tile Map B

wire [7:0] TM_B_px_bits_0_latched; // latched
wire [7:0] TM_B_px_bits_1_latched; // latched
wire [7:0] TM_B_px_bits_2_latched; // latched
wire [7:0] TM_B_px_bits_3_latched; // latched

// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U17(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_B_pixel_latch       ), // clock
	.d       ( { i_H[0], i_G[0], i_F[0], i_E[0], i_D[0], i_C[0], i_B[0], i_A[0] } ),
	.q       ( TM_B_px_bits_0_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U18U19(
	.D      ( TM_B_px_bits_0_latched   ), // parallel input
	.S      ( { i_9E_pin8, i_9E_pin6 } ), // mode select
	.mclk   ( i_MCLK                   ), // main clock
	.cen    ( CLK_INTL1                ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_0_flipped    )  // parallel output
);

wire [7:0] TM_B_px_bit_0_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U20(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_B_pixel_latch       ), // clock
	.d       ( { i_H[1], i_G[1], i_F[1], i_E[1], i_D[1], i_C[1], i_B[1], i_A[1] } ),
	.q       ( TM_B_px_bits_1_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U21U22(
	.D      ( TM_B_px_bits_1_latched    ), // parallel input
	.S      ( { i_9E_pin8 , i_9E_pin6 } ), // mode select
	.mclk   ( i_MCLK                    ), // main clock
	.cen    ( CLK_INTL1                 ), // clock enable
	.clr    ( 1'b0                      ), // clear
	.R      ( 1'b0                      ), // right feed
	.L      ( 1'b0                      ), // left feed
	.Q      ( TM_B_px_bit_1_flipped     )  // parallel output
);

wire [7:0] TM_B_px_bit_1_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U23(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_B_pixel_latch       ), // clock
	.d       ( { i_H[2], i_G[2], i_F[2], i_E[2], i_D[2], i_C[2], i_B[2], i_A[2] } ),
	.q       ( TM_B_px_bits_2_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U24U25(
	.D      ( TM_B_px_bits_2_latched   ), // parallel input
	.S      ( { i_9E_pin8, i_9E_pin6 } ), // mode select
	.mclk   ( i_MCLK                   ), // main clock
	.cen    ( CLK_INTL1                ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_2_flipped    )  // parallel output
);

wire [7:0] TM_B_px_bit_2_flipped;


// Octal D-type flip-flop latch with reset; positive-edge trigger
bus_ff #( .W( 8 ) ) U26(
	.rst     ( i_RST                  ),
	.clk     ( i_MCLK                 ),
	.trig    ( TM_B_pixel_latch       ), // clock
	.d       ( { i_H[3], i_G[3], i_F[3], i_E[3], i_D[3], i_C[3], i_B[3], i_A[3] } ),
	.q       ( TM_B_px_bits_3_latched ),
	.q_n     (                        )
);

// 8-bit bidirectional universal shift register
lmn74194_nbit #( .N( 8 ) )
U27U28(
	.D      ( TM_B_px_bits_3_latched   ), // parallel input
	.S      ( { i_9E_pin8, i_9E_pin6 } ), // mode select
	.mclk   ( i_MCLK                   ), // main clock
	.cen    ( CLK_INTL1                ), // clock enable
	.clr    ( 1'b0                     ), // clear
	.R      ( 1'b0                     ), // right feed
	.L      ( 1'b0                     ), // left feed
	.Q      ( TM_B_px_bit_3_flipped    )  // parallel output
);

wire [7:0] TM_B_px_bit_3_flipped;

`ifdef SIMULATION

wire [0:3] db_TM_B_px_0_latched = { TM_B_px_bits_0_latched[0], TM_B_px_bits_1_latched[0], TM_B_px_bits_2_latched[0], TM_B_px_bits_3_latched[0] };
wire [0:3] db_TM_B_px_7_latched = { TM_B_px_bits_0_latched[7], TM_B_px_bits_1_latched[7], TM_B_px_bits_2_latched[7], TM_B_px_bits_3_latched[7] };

`endif

// MUX U33 with BFF as selector
// output pixel data (4bits) Tile Map B
always @( posedge i_MCLK ) begin
	case( i_BFF )
		// bits put back in order compared to schematic
		1'b0:   o_TM_B_pixels <= { TM_B_px_bit_0_flipped[0], TM_B_px_bit_1_flipped[0], TM_B_px_bit_2_flipped[0], TM_B_px_bit_3_flipped[0] };
		1'b1:   o_TM_B_pixels <= { TM_B_px_bit_0_flipped[7], TM_B_px_bit_1_flipped[7], TM_B_px_bit_2_flipped[7], TM_B_px_bit_3_flipped[7] };
	endcase
end

// U29a output transparency flag Tile Map B
assign o_TM_B_px_trans = (o_TM_B_pixels == 4'b0)  ?  1'b0 : 1'b1;

endmodule
