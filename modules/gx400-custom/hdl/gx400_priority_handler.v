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
//  Tile and Sprite Priority Decoding Module
//================================================================================
// 
//  Part of the K0005293 Konami custom chip.
//  Implemented in a PAL in the bootleg version.

`default_nettype none

/*

This module implements the priority handler of the GX400 video. Each tile on both
tilemaps A and B have four bits of priority that determine the layering order of the
tiles and object (sprite). Moreover, if the pixel value of a tile or sprite is zero,
it is considered to be transparent.

In order to accurately reproduce the display modes, Raki wrote a custom program
in 68000 assembly for the main CPU, that he ran on real hardware, and filmed the
result. The program loads carefully designed tiles and sprites, and cycles through
all 256 combinations of priority bits.

Olivier, who doesn’t mind boring, repetitive work sometimes, then analysed the resulting
256 frames and found 26 distinct cases. It quickly appeared that the two MSB of the priority
of tilemap B have no effect. We gave names to each of these cases to make it easier to implement
them. Most of them are straightforward: the three layers are layered in various orders, or
ignored, with transparency enabled or disabled. Some cases were harder to name, like the ones
where a tile masks the sprite, or where one tile punches holes in the other. And two of them
are just plain weird (TMM_A_O1 and TMM_A_O2.)

The priority handler thus works in two stages: 

1. The first case statement identifies the named case from the six meaningful priority bits,
   and assigns it to tm_mode.

2. The second case statement then selects the pixel to display between Tilemap A, Tilemap B,
   and Object, taking the transparency of each one into account, which is done via the
   i_TM_A_PX_TRANS and i_TM_B_PX_TRANS inputs for the tilemaps, and by checking if all the
   bits of i_OBJ_COLOR are zero for the object.

The outputs are the two selector bits of the multiplexer, which select the pixel to be
displayed according to the following truth table:

o_S1_n   o_S0_n   Output
------------------------
  1        0      Tile A
  1        1      Tile B
  0        X      Object

Notes:

– This implementation doesn’t try to identify the meaning of each priority bit. It doesn’t
  matter, because the goal is accuracy, not documentation for game developers;

– There seems to be a convention that colour 0 is always black, because otherwise you get
  strange results in some cases. For example, case “A over B” shows A in the corners. We
  would expect it to show B, since A is on top, and transparent at the corners. But if
  colour 0 is always black, the difference is not noticeable. Our implementation follows
  the hardware, and is accurate even if this convention is not followed, something that
  wouldn’t have been possible by only looking at games that always use black as colour 0.

*/

module gx400_priority_handler
(
	input      [3:0]  i_TM_A_PR,        // PR4_TM-A, PR3_TM-A, PR2_TM-A, PR1_TM-A
	input      [1:0]  i_TM_B_PR,        // PR2_TM-B, PR1_TM-B
	input      [3:0]  i_OBJ_COLOR,
	input             i_TM_A_PX_TRANS,  // Tilemap A pixel is transparent (active low)
	input             i_TM_B_PX_TRANS,  // Tilemap B pixel is transparent (active low)

	output            o_S0_n,           // Already inverted, to facilitate reasoning
	output            o_S1_n            // |
);

wire       obj_px_trans = |{ i_OBJ_COLOR }; // active low

reg  [4:0] tm_mode;
reg  [1:0] tm_select;

`define TMM_A        5'd0   // A
`define TMM_A_B      5'd1   // A over B
`define TMM_A_B_O    5'd2   // A over B over Object
`define TMM_A_BMO    5'd3   // A over (B-masked Object)
`define TMM_A_O1     5'd4   // A over Object 1
`define TMM_A_O2     5'd5   // A over Object 2
`define TMM_A_O_B    5'd6   // A over Object over B
`define TMM_B        5'd7   // B
`define TMM_B_A      5'd8   // B over A
`define TMM_B_A_O    5'd9   // B over A over Object
`define TMM_B_O      5'd10  // B over Object
`define TMM_B_O_A    5'd11  // B over Object over A
`define TMM_O        5'd12  // Object
`define TMM_O_A      5'd13  // Object over A
`define TMM_O_A_B    5'd14  // Object over A over B
`define TMM_O_B      5'd15  // Object over B
`define TMM_O_B_A    5'd16  // Object over B over A
`define TMM_A_BMO_B  5'd17  // A over (B-masked Object) over B
`define TMM_APB_O    5'd18  // (A-punched B) over Object
`define TMM_APB_O_A  5'd19  // (A-punched B) over Object over A
`define TMM_B_AMO    5'd20  // B over (A-masked Object)
`define TMM_B_AMO_A  5'd21  // B over (A-masked Object) over A
`define TMM_BPA_O    5'd22  // (B-punched A) over Object
`define TMM_BPA_O_B  5'd23  // (B-punched A) over Object over B
`define TMM_O_APB    5'd24  // Object over (A-punched B)
`define TMM_O_BPA    5'd25  // Object over (B-punched A)

always @(*) begin
	casez( { i_TM_B_PR[1:0], i_TM_A_PR[3:0] } )

		6'b??0101:  tm_mode = `TMM_A;        // A
		6'b?11101:  tm_mode = `TMM_A_B;      // A over B
		6'b?11111:  tm_mode = `TMM_A_B_O;    // A over B over Object
		6'b001101:  tm_mode = `TMM_A_BMO;    // A over (B-masked Object)
		6'b??0111:  tm_mode = `TMM_A_O1;     // A over Object 1
		6'b001111:  tm_mode = `TMM_A_O2;     // A over Object 2
		6'b101111:  tm_mode = `TMM_A_O_B;    // A over Object over B
		6'b0100??:  tm_mode = `TMM_B;        // B
		6'b0110?1:  tm_mode = `TMM_B_A;      // B over A
		6'b1110?1:  tm_mode = `TMM_B_A_O;    // B over A over Object
		6'b1100??:  tm_mode = `TMM_B_O;      // B over Object
		6'b111000:  tm_mode = `TMM_B_O;      // |
		6'b111010:  tm_mode = `TMM_B_O_A;    // B over Object over A
		6'b0000??:  tm_mode = `TMM_O;        // Object
		6'b001?00:  tm_mode = `TMM_O;        // |
		6'b??0100:  tm_mode = `TMM_O;        // |
		6'b??0110:  tm_mode = `TMM_O_A;      // Object over A
		6'b001110:  tm_mode = `TMM_O_A;      // |
		6'b101110:  tm_mode = `TMM_O_A_B;    // Object over A over B
		6'b1000??:  tm_mode = `TMM_O_B;      // Object over B
		6'b101000:  tm_mode = `TMM_O_B;      // |
		6'b101010:  tm_mode = `TMM_O_B_A;    // Object over B over A
		6'b101101:  tm_mode = `TMM_A_BMO_B;  // A over (B-masked Object) over B
		6'b?11100:  tm_mode = `TMM_APB_O;    // (A-punched B) over Object
		6'b?11110:  tm_mode = `TMM_APB_O_A;  // (A-punched B) over Object over A
		6'b011000:  tm_mode = `TMM_B_AMO;    // B over (A-masked Object)
		6'b011010:  tm_mode = `TMM_B_AMO_A;  // B over (A-masked Object) over A
		6'b0010?1:  tm_mode = `TMM_BPA_O;    // (B-punched A) over Object
		6'b1010?1:  tm_mode = `TMM_BPA_O_B;  // (B-punched A) over Object over B
		6'b101100:  tm_mode = `TMM_O_APB;    // Object over (A-punched B)
		6'b001010:  tm_mode = `TMM_O_BPA;    // Object over (B-punched A)
	endcase

	/*

	Test patterns

	A, B, O: opaque (colour #1)
	a, b, o: transparent (colour #0)

	    TM-A            TM-B           Object

	┌───┬───┬───┐   ┌───────────┐   ┌─────┬─────┐
	│   │   │   │   │     b     │   │     │     │
	│   │   │   │   ├───────────┤   │     │     │
	│ a │ A │ a │   │     B     │   │  O  │  o  │
	│   │   │   │   ├───────────┤   │     │     │
	│   │   │   │   │     b     │   │     │     │
	└───┴───┴───┘   └───────────┘   └─────┴─────┘

	ASCII Boxes: https://asciiflow.com/
	
	In the cases below, the left box shows what the hardware is actually displaying,
	and the right box shows the result if colour 0 of both tilemaps and the object
	are the same.
	
	*/

	case( tm_mode )
		// A
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │   │   │    │   │   │   │
		// │   │   │   │    │   │   │   │
		// │ a │ A │ a │    │   │ A │   │
		// │   │   │   │    │   │   │   │
		// │   │   │   │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A: tm_select = {
				1'b1,
				1'b0
			};

		// A over B
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ a │   │ a │    │   │   │   │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ B │ A │ B │    │ B │ A │ B │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ a │   │ a │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_B: tm_select = {
				1'b1,
				~i_TM_A_PX_TRANS & i_TM_B_PX_TRANS
			};

		// A over B over Object
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ O │   │ a │    │ O │   │   │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ B │ A │ B │    │ B │ A │ B │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ O │   │ a │    │ O │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_B_O: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS, obj_px_trans },
				~i_TM_A_PX_TRANS & i_TM_B_PX_TRANS
			};

		// A over (B-masked Object)
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ a │   │ a │    │   │   │   │
		// ├───┤   ├───┤    ├───┤   │   │
		// │ O │ A │ o │    │ O │ A │   │
		// ├───┤   ├───┤    ├───┤   │   │
		// │ a │   │ a │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_BMO: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, i_TM_B_PX_TRANS },
				1'b0
			};

		// A over Object 1
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │   │   │    │   │   │   │
		// │   │   │   │    │   │   │   │
		// │ O │ A │ a │    │ O │ A │   │
		// │   │   │   │    │   │   │   │
		// │   │   │   │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_O1: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, obj_px_trans },
				1'b0
			};

		// A over Object 2
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │   │ a │    │   │   │   │
		// │   │   ├───┤    │   │   │   │
		// │ O │ A │ o │    │ O │ A │   │
		// │   │   ├───┤    │   │   │   │
		// │   │   │ a │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_O2: tm_select = {
				i_TM_A_PX_TRANS | ( ~i_TM_B_PX_TRANS & ~obj_px_trans ),
				1'b0
			};

		// A over Object over B
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │   │ a │    │   │   │   │
		// │   │   ├───┤    │   │   ├───┤
		// │ O │ A │ B │    │ O │ A │ B │
		// │   │   ├───┤    │   │   ├───┤
		// │   │   │ a │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_O_B: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, obj_px_trans },
				~i_TM_A_PX_TRANS & i_TM_B_PX_TRANS
			};

		// B
		// 
		// ┌───────────┐    ┌───────────┐
		// │     b     │    │           │
		// ├───────────┤    ├───────────┤
		// │     B     │    │     B     │
		// ├───────────┤    ├───────────┤
		// │     b     │    │           │
		// └───────────┘    └───────────┘
		`TMM_B: tm_select = {
				1'b1,
				1'b1
			};

		// B over A
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ b │ A │ b │    │   │ A │   │
		// ├───┴───┴───┤    ├───┴───┴───┤
		// │     B     │    │     B     │
		// ├───┬───┬───┤    ├───┬───┬───┤
		// │ b │ A │ b │    │   │ A │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_B_A: tm_select = {
				1'b1,
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS }
			};

		// B over A over Object
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ O │ A │ o │    │ O │ A │   │
		// ├───┴───┴───┤    ├───┴───┴───┤
		// │     B     │    │     B     │
		// ├───┬───┬───┤    ├───┬───┬───┤
		// │ O │ A │ o │    │ O │ A │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_B_A_O: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS },
				i_TM_B_PX_TRANS
			};

		// B over Object
		// 
		// ┌─────┬─────┐    ┌─────┬─────┐
		// │  O  │  o  │    │  O  │     │
		// ├─────┴─────┤    ├─────┴─────┤
		// │     B     │    │     B     │
		// ├─────┬─────┤    ├─────┬─────┤
		// │  O  │  o  │    │  O  │     │
		// └─────┴─────┘    └─────┴─────┘
		`TMM_B_O: tm_select = {
				i_TM_B_PX_TRANS,
				1'b1
			};

		// B over Object over A
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │  O  │A│ o │    │  O  │A│   │
		// ├─────┴─┴───┤    ├─────┴─┴───┤
		// │     B     │    │     B     │
		// ├─────┬─┬───┤    ├─────┬─┬───┤
		// │  O  │A│ o │    │  O  │A│   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_B_O_A: tm_select = {
				i_TM_B_PX_TRANS | i_TM_A_PX_TRANS & ~obj_px_trans,
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS }
			};

		// Object
		// 
		// ┌─────┬─────┐    ┌─────┬─────┐
		// │     │     │    │     │     │
		// │     │     │    │     │     │
		// │  O  │  o  │    │  O  │     │
		// │     │     │    │     │     │
		// │     │     │    │     │     │
		// └─────┴─────┘    └─────┴─────┘
		`TMM_O: tm_select = {
				1'b0,
				1'b0
			};

		// Object over A
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │     │ │   │    │     │ │   │
		// │     │ │   │    │     │ │   │
		// │  O  │A│ o │    │  O  │A│   │
		// │     │ │   │    │     │ │   │
		// │     │ │   │    │     │ │   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_O_A: tm_select = {
				&{ i_TM_A_PX_TRANS, ~obj_px_trans },
				1'b0
			};

		// Object over A over B
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │     │ │ o │    │     │ │   │
		// │     │ ├───┤    │     │ ├───┤
		// │  O  │A│ B │    │  O  │A│ B │
		// │     │ ├───┤    │     │ ├───┤
		// │     │ │ o │    │     │ │   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_O_A_B: tm_select = {
				i_TM_A_PX_TRANS & ~obj_px_trans | i_TM_B_PX_TRANS & ~obj_px_trans,
				~i_TM_A_PX_TRANS
			};

		// Object over B
		// 
		// ┌─────┬─────┐    ┌─────┬─────┐
		// │     │  o  │    │     │     │
		// │     ├─────┤    │     ├─────┤
		// │  O  │  B  │    │  O  │  B  │
		// │     ├─────┤    │     ├─────┤
		// │     │  o  │    │     │     │
		// └─────┴─────┘    └─────┴─────┘
		`TMM_O_B: tm_select = {
				&{ i_TM_B_PX_TRANS, ~obj_px_trans },
				1'b1
			};

		// Object over B over A
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │     │A│ o │    │     │A│   │
		// │     ├─┴───┤    │     ├─┴───┤
		// │  O  │  B  │    │  O  │  B  │
		// │     ├─┬───┤    │     ├─┬───┤
		// │     │A│ o │    │     │A│   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_O_B_A: tm_select = {
				i_TM_A_PX_TRANS & ~obj_px_trans | i_TM_B_PX_TRANS & ~obj_px_trans,
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS }
			};

		// A over (B-masked Object) over B
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │ a │   │ a │    │   │   │   │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ O │ A │ B │    │ O │ A │ B │
		// ├───┤   ├───┤    ├───┤   ├───┤
		// │ a │   │ a │    │   │   │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_A_BMO_B: tm_select = {
				~&{ ~i_TM_A_PX_TRANS, i_TM_B_PX_TRANS, obj_px_trans },
				~i_TM_A_PX_TRANS & i_TM_B_PX_TRANS
			};

		// (A-punched B) over Object
		// 
		// ┌─────┬─────┐    ┌─────┬─────┐
		// │  O  │  o  │    │  O  │     │
		// ├───┐ │ ┌───┤    ├───┐ │ ┌───┤
		// │ B │ │ │ B │    │ B │ │ │ B │
		// ├───┘ │ └───┤    ├───┘ │ └───┤
		// │     │     │    │     │     │
		// └─────┴─────┘    └─────┴─────┘
		`TMM_APB_O: tm_select = {
				&{ ~i_TM_A_PX_TRANS, i_TM_B_PX_TRANS },
				1'b1
			};

		// (A-punched B) over Object over A
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │  O  │ │ o │    │  O  │ │   │
		// ├───┐ │ ├───┤    ├───┐ │ ├───┤
		// │ B │ │A│ B │    │ B │ │A│ B │
		// ├───┘ │ ├───┤    ├───┘ │ ├───┤
		// │     │ │ o │    │     │ │   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_APB_O_A: tm_select = {
				i_TM_A_PX_TRANS & ~obj_px_trans | ~i_TM_A_PX_TRANS & i_TM_B_PX_TRANS,
				~i_TM_A_PX_TRANS
			};

		// B over (A-masked Object)
		// 
		// ┌───┬─┬─┬───┐    ┌───┬─┬─────┐
		// │ b │O│o│ b │    │   │O│     │
		// ├───┴─┴─┴───┤    ├───┴─┴─────┤
		// │     B     │    │     B     │
		// ├───┬─┬─┬───┤    ├───┬─┬─────┤
		// │ b │O│o│ b │    │   │O│     │
		// └───┴─┴─┴───┘    └───┴─┴─────┘
		`TMM_B_AMO: tm_select = {
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS },
				1'b1
			};

		// B over (A-masked Object) over A
		// 
		// ┌───┬─┬─┬───┐    ┌───┬─┬─┬───┐
		// │ b │O│A│ b │    │   │O│A│   │
		// ├───┴─┴─┴───┤    ├───┴─┴─┴───┤
		// │     B     │    │     B     │
		// ├───┬─┬─┬───┤    ├───┬─┬─┬───┤
		// │ b │O│A│ b │    │   │O│A│   │
		// └───┴─┴─┴───┘    └───┴─┴─┴───┘
		`TMM_B_AMO_A: tm_select = {
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS, obj_px_trans },
				~&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS }
			};

		// (B-punched A) over Object
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │ A │   │    │   │ A │   │
		// │   └─┬─┘   │    │   └─┬─┘   │
		// │  O  │  o  │    │  O  │     │
		// │   ┌─┴─┐   │    │   ┌─┴─┐   │
		// │   │ A │   │    │   │ A │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_BPA_O: tm_select = {
				&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS },
				1'b0
			};

		// (B-punched A) over Object over B
		// 
		// ┌───┬───┬───┐    ┌───┬───┬───┐
		// │   │ A │ o │    │   │ A │   │
		// │   └─┬─┴───┤    │   └─┬─┴───┤
		// │  O  │  B  │    │  O  │  B  │
		// │   ┌─┴─┬───┤    │   ┌─┴─┬───┤
		// │   │ A │ o │    │   │ A │   │
		// └───┴───┴───┘    └───┴───┴───┘
		`TMM_BPA_O_B: tm_select = {
				i_TM_A_PX_TRANS & ~i_TM_B_PX_TRANS  | i_TM_B_PX_TRANS & ~obj_px_trans,
				i_TM_B_PX_TRANS & ~obj_px_trans
			};

		// Object over (A-punched B)
		// 
		// ┌─────┬─────┐    ┌─────┬─────┐
		// │     │  o  │    │     │     │
		// │     │ ┌───┤    │     │ ┌───┤
		// │  O  │ │ B │    │  O  │ │ B │
		// │     │ └───┤    │     │ └───┤
		// │     │     │    │     │     │
		// └─────┴─────┘    └─────┴─────┘
		`TMM_O_APB: tm_select = {
				&{ ~i_TM_A_PX_TRANS, i_TM_B_PX_TRANS, ~obj_px_trans },
				1'b1
			};

		// Object over (B-punched A)
		// 
		// ┌─────┬─┬───┐    ┌─────┬─┬───┐
		// │     │A│   │    │     │A│   │
		// │     ├─┘   │    │     ├─┘   │
		// │  O  │  o  │    │  O  │     │
		// │     ├─┐   │    │     ├─┐   │
		// │     │A│   │    │     │A│   │
		// └─────┴─┴───┘    └─────┴─┴───┘
		`TMM_O_BPA: tm_select = {
				&{ i_TM_A_PX_TRANS, ~i_TM_B_PX_TRANS, ~obj_px_trans },
				1'b0
			};
	endcase
end

assign o_S1_n = tm_select[1];
assign o_S0_n = tm_select[0];

endmodule
