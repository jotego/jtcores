`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A-2-6/8 Character video RAM

*/

module jt_gng_a7(
	input		G4H,		// from 5/8
	input		V4,
	input		V2,
	input		V1,
	input		H4,
	input		G6M,
	input		G4_3H,
	input		CHVFLIP,	// from 6/8
	input		CHHFLIP,
	input		CHHFLIPq,
	input [9:0] AC,
	input		FLIP,		// from 2/8
	output		CH6M,		// to 8/8
	output		CHARZ,
	output		CHARY
);

reg VV4,VV2,VV1;

assign CH6M = G6M;

always @(posedge G4H) {VV4,VV2,VV1} <= {V4,V2,V1};
wire vflip =  CHVFLIP ^ FLIP;
wire flip_9D = FLIP;
wire hflip = ~CHHFLIP ^ flip_9D;

wire [3:0] addr;
assign #2 addr = { {3{vflip}} ^ {VV4,VV2,VV1}, hflip^H4 };

reg [7:0] mem_11e[0:16383];

initial
	$readmemh("../../rom/mm01.11e.hex", mem_11e);

reg [7:0] data;

always @(AC,addr)
	data <= mem_11e[ {AC,addr} ];

wire [1:0] S;
wire [3:0] QZ, QY;

jt74194 u_10D(
	.D		( data[7:4] ),
	.S		( S 		),
	.clk	( CH6M 		),
	.cl_b	( 1'b1		),
	.L		( 1'b0		),
	.R		( 1'b0		),
	.Q		( QZ		)
);

jt74194 u_11D(
	.D		( data[3:0] ),
	.S		( S 		),
	.clk	( CH6M 		),
	.cl_b	( 1'b1		),
	.L		( 1'b0		),
	.R		( 1'b0		),
	.Q		( QY		)
);

jt74157 u_10C(
	.A	( {1'b1, G4_3H, QZ[0], QY[0]} ),
	.B	( {G4_3H, 1'b1, QZ[3], QY[3]} ),
	.sel( CHHFLIPq ^ ~flip_9D ), // according to schematic CHHFLIPq ^ flip_9D
	// but the output is corrupted unless I take ~flip_9D
	.st_l( 1'b0 ),
	.Y	( {S, CHARZ, CHARY} )
);

endmodule // jt_gng_a7