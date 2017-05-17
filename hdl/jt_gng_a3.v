`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a3(
	input			INCS_b,
	input	[2:0]	AB,
	inout	[7:0]	DB,
	input	[1:0]	UP,
	input	[1:0]	DOWN,
	input	[1:0]	LEFT,
	input	[1:0]	RIGHT,
	input	[1:0]	SHOT2,
	input	[1:0]	SHOT1,
	input	[7:0]	DIPSW_B,
	input	[7:0]	DIPSW_A,
	input	[1:0]	COIN,
	input	[1:0]	START,
	input	[1:0]	RESERVED
);

wire [7:0] IN;
jt74138 u_3A (.e1_b(INCS_b), .e2_b(INCS_b), .e3(1'b1), .a(AB[2:0]), .y_b(IN));

jt74367 u_4A ( 
	.A( { SHOT2[0], SHOT1[0], UP[0], DOWN[0], LEFT[0], RIGHT[0] }  ),
	.Y(DB[5:0]), .en4_b(IN[1]), .en6_b(IN[1])
);

jt74367 u_5A ( 
	.A( { SHOT2[1], SHOT1[1], UP[1], DOWN[1], LEFT[1], RIGHT[1] }  ),
	.Y		(DB[5:0]	), 
	.en4_b	(IN[2]		), 
	.en6_b	(IN[2]		)
);

jt74367 u_2B ( 
	.A( DIPSW_B  ),
	.Y(DB[7:0]), .en4_b(IN[4]), .en6_b(IN[4])
);

jt74367 u_1B ( 
	.A( DIPSW_A  ),
	.Y(DB[7:0]), .en4_b(IN[3]), .en6_b(IN[3])
);

jt74367 u_8A ( 
	.A( {COIN[1:0], RESERVED, 2'b0, START}  ),
	.Y(DB[7:0]), .en4_b(IN[0]), .en6_b(IN[0])
);



endmodule // jt_gng_a3