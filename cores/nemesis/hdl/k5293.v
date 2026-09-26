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
//  K0005293 Priority Handler
//================================================================================

`default_nettype none

module K005293
(
	input             i_RST,
	input             i_CLK,            // Pin 23
	input             i_CEN6,           // |

	input             i_SHIFT_A1_CLKD,  // Pin 18
	input             i_SHIFT_A2_CLKD,  // Pin 17
	input             i_SHIFT_B_CLKD,   // Pin 19
	input             i_2HD_CLKD,       // Pin 21
	input             i_4HD_CLKD,       // Pin 20

	output            o_TM_A_HFLIP,     // Pin 36
	output            o_TM_B_HFLIP,     // Pin 37

	// Pins 3–10, 15–16
	input      [ 3:0] i_TM_A_PX_DATA,   // Tilemap A pixel data
	input             i_TM_A_PX_TRANS,  // Tilemap A pixel is transparent (active low)
	input      [ 3:0] i_TM_B_PX_DATA,   // Tilemap B pixel data
	input             i_TM_B_PX_TRANS,  // Tilemap B pixel is transparent (active low)

	input             i_HFLIP,          // Pin 56

	input      [ 3:0] i_TILE_PRIORITY,  // PR, Pins 11–14
	input             i_VHFF,           // Pin 57
	input      [ 6:0] i_VRAM2_DATA,     // VC

	input      [15:0] i_OBJ_PX_DATA,    // DQ

	output reg [10:0] o_COLOR_RAM_ADDR, // CD

	input             i_1H_n            // Pin 22
);

wire [11:0]    tm_a_4hd_latched, tm_a_2hd_latched, tm_a_shift_a1_latched;
wire [10:0]    tm_a_shift_a2_latched;
wire [ 9:0]    tm_b_2hd_latched, tm_b_4hd_latched, tm_b_shift_b_latched;
wire [ 7:0]    obj_a_px_data_latched, obj_b_px_data_latched, obj_px_data_muxed;
wire [ 1:0]    tm_select;


///////////////////
// Tilemap A Delay Line
///////////////////

bus_ff #( .W( 12 ) ) u_tm_a_4hd_ff(
	.rst     ( i_RST            ),
	.clk     ( i_CLK            ),
	.trig    ( i_4HD_CLKD       ),
	.d       ( { i_TILE_PRIORITY[3:0], i_VHFF, i_VRAM2_DATA[6:0] } ),
	.q       ( tm_a_4hd_latched ),
	.q_n     (                  )
);

`ifdef SIMULATION
	// weird pri order to match jt74 version
	wire [3:0] pri_tma_1 = { tm_a_4hd_latched[10], tm_a_4hd_latched[11], tm_a_4hd_latched[9], tm_a_4hd_latched[8] };
	wire       vhff_tma_1  = tm_a_4hd_latched[7];
	wire [6:0] color_tma_1 = tm_a_4hd_latched[6:0];
`endif

bus_ff #( .W( 12 ) ) u_tm_a_2hd_ff(
	.rst     ( i_RST            ),
	.clk     ( i_CLK            ),
	.trig    ( i_2HD_CLKD       ),
	.d       ( tm_a_4hd_latched ),
	.q       ( tm_a_2hd_latched ),
	.q_n     (                  )
);

`ifdef SIMULATION
	wire [3:0] pri_tma_2 = { tm_a_2hd_latched[10], tm_a_2hd_latched[11], tm_a_2hd_latched[9], tm_a_2hd_latched[8] };
	wire       vhff_tma_2  = tm_a_2hd_latched[7];
	wire [6:0] color_tma_2 = tm_a_2hd_latched[6:0];
`endif

bus_ff #( .W( 12 ) ) u_tm_a_shift_a1_ff(
	.rst     ( i_RST                 ),
	.clk     ( i_CLK                 ),
	.trig    ( i_SHIFT_A1_CLKD       ),
	.d       ( tm_a_2hd_latched      ),
	.q       ( tm_a_shift_a1_latched ),
	.q_n     (                       )
);

`ifdef SIMULATION
	wire [3:0] pri_tma_3 = { tm_a_shift_a1_latched[10], tm_a_shift_a1_latched[11], tm_a_shift_a1_latched[9], tm_a_shift_a1_latched[8] };
	wire [6:0] color_tma_3 = tm_a_shift_a1_latched[6:0];
`endif

assign o_TM_A_HFLIP = tm_a_shift_a1_latched[7];

bus_ff #( .W( 11 ) ) u_tm_a_shift_a2_ff(
	.rst     ( i_RST                 ),
	.clk     ( i_CLK                 ),
	.trig    ( i_SHIFT_A2_CLKD       ),
	.d       ( { tm_a_shift_a1_latched[11:8], tm_a_shift_a1_latched[6:0] } ),
	.q       ( tm_a_shift_a2_latched ),
	.q_n     (                       )
);

`ifdef SIMULATION
	wire [3:0] pri_tma_4 = { tm_a_shift_a2_latched[9], tm_a_shift_a2_latched[10], tm_a_shift_a2_latched[8], tm_a_shift_a2_latched[7] };
	wire [6:0] color_tma_4 = tm_a_shift_a2_latched[6:0];
`endif

///////////////////
// Tilemap B Delay Line
///////////////////

bus_ff #( .W( 10 ) ) u_tm_b_2hd_ff(
	.rst     ( i_RST            ),
	.clk     ( i_CLK            ),
	.trig    ( i_2HD_CLKD       ),
	.d       ( { i_TILE_PRIORITY[1:0], i_VHFF, i_VRAM2_DATA[6:0] } ),
	.q       ( tm_b_2hd_latched ),
	.q_n     (                  )
);

`ifdef SIMULATION
	wire [1:0] pri_tmb_1 = tm_b_2hd_latched[9:8];
	wire       vhff_tmb_1  = tm_b_2hd_latched[7];
	wire [6:0] color_tmb_1 = tm_b_2hd_latched[6:0];
`endif

bus_ff #( .W( 10 ) ) u_tm_b_4hd_ff(
	.rst     ( i_RST            ),
	.clk     ( i_CLK            ),
	.trig    ( i_4HD_CLKD       ),
	.d       ( tm_b_2hd_latched ),
	.q       ( tm_b_4hd_latched ),
	.q_n     (                  )
);

`ifdef SIMULATION
	wire [1:0] pri_tmb_2 = tm_b_4hd_latched[9:8];
	wire       vhff_tmb_2  = tm_b_4hd_latched[7];
	wire [6:0] color_tmb_2 = tm_b_4hd_latched[6:0];
`endif

bus_ff #( .W( 10 ) ) u_tm_b_shift_a1_ff(
	.rst     ( i_RST                ),
	.clk     ( i_CLK                ),
	.trig    ( i_SHIFT_B_CLKD       ),
	.d       ( tm_b_4hd_latched     ),
	.q       ( tm_b_shift_b_latched ),
	.q_n     (                      )
);

`ifdef SIMULATION
	wire [1:0] pri_tmb_3 = tm_b_shift_b_latched[9:8];
	wire [6:0] color_tmb_3 = tm_b_shift_b_latched[6:0];
`endif

assign o_TM_B_HFLIP = tm_b_shift_b_latched[7];

///////////////////
// Object Data Latch
///////////////////

bus_ff #( .W( 16 ) ) u_obj_ff(
	.rst     ( i_RST            ),
	.clk     ( i_CLK            ),
	.trig    ( i_1H_n          ),
	.d       ( i_OBJ_PX_DATA    ),
	.q       ( { obj_b_px_data_latched, obj_a_px_data_latched } ),
	.q_n     (                  )
);

assign obj_px_data_muxed = ( ~i_1H_n ^ i_HFLIP ) ? obj_b_px_data_latched : obj_a_px_data_latched;

///////////////////
// Priority Decoding PAL
///////////////////

gx400_priority_handler priority_handler
(
	.i_TM_A_PR       ( tm_a_shift_a2_latched[10:7] ), // PR4_TM-A, PR3_TM-A, PR2_TM-A, PR1_TM-A
	.i_TM_B_PR       ( tm_b_shift_b_latched[9:8  ] ), // PR2_TM-B, PR1_TM-B
	.i_OBJ_COLOR     ( obj_px_data_muxed[3:0]      ),
	.i_TM_A_PX_TRANS ( i_TM_A_PX_TRANS             ), // Tilemap A pixel is transparent (active low)
	.i_TM_B_PX_TRANS ( i_TM_B_PX_TRANS             ), // Tilemap B pixel is transparent (active low)

	.o_S0_n          ( tm_select[0]                ),
	.o_S1_n          ( tm_select[1]                )
);

///////////////////
// Output MUX
///////////////////

always @(posedge i_CLK ) if( i_CEN6 ) begin
	case( tm_select )
		2'b10:   o_COLOR_RAM_ADDR <= { tm_a_shift_a2_latched[6:0], i_TM_A_PX_DATA };
		2'b11:   o_COLOR_RAM_ADDR <= { tm_b_shift_b_latched[6:0],  i_TM_B_PX_DATA };
		default: o_COLOR_RAM_ADDR <= obj_px_data_muxed;
	endcase
end

endmodule
