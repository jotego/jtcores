`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A-2-6/8 Character video RAM

*/

module jt_gng_a6(
	input	H2,			// from A-5/8
	input	H4,			// from A-5/8
	input	H8,			// from A-5/8
	input	H16,		// from A-5/8
	input	H32,		// from A-5/8
	input	H64,		// from A-5/8
	input	H128,		// from A-5/8
	input	H256,		// from A-5/8
	input	V8,			// from A-5/8
	input	V16,		// from A-5/8
	input	V32,		// from A-5/8
	input	V64,		// from A-5/8
	input	V128,		// from A-5/8
	input	FLIP,		// from A-2/8
	output	MRDY_b,		// to   A-1/8
	input	MRDY2_b,	// from B15
	input	CHARCS_b,	// from A-2/8
	input	OH,			// from A-5/8
	input	N4H,		// from A-5/8
	output [3:0] CC,	// to   A-8/8
	output	CHHFLIP,	// to   A-7/8
	output	CHHFLIP4,	// to   A-7/8
	output	CHVFLIP,	// to	A-7/8
	output	[9:0] AC,	// to	A-7/8
	input	[7:0] DB,	// from A-1/8
	input	RDB_b,		// from A-1/8
	input	[10:0] AB,	// from A-1/8
);

reg [10:0] ram_addr;
reg	ram_wr_b;

always @(*)
	if( ~H4 ) begin
		ram_addr = AB;
		ram_wr_b = 
	end else begin
		ram_addr = { H2, {10{FLIP}}^{V128,V64,V32,V16,V8,H128,H64,H32,H16,H8}};
		ram_wr_b = 1'b1;
	end

endmodule

