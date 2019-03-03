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
	input	G4H,		// from A-5/8
	input	FLIP,		// from A-2/8
	output	MRDY_b,		// to   A-1/8
	input	MRDY2_b,	// from B15
	input	CHARCS_b,	// from A-2/8
	input	OH,			// from A-5/8
	input	N4H,		// from A-5/8
	output [3:0] CC,	// to   A-8/8 ... character palette
	output	CHHFLIP,	// to   A-7/8
	output	CHHFLIPq,	// to   A-7/8
	output	CHVFLIP,	// to	A-7/8
	output	[9:0] AC,	// to	A-7/8
	inout	[7:0] DB,	// from A-1/8
	input	RDB_b,		// from A-1/8
	inout	[10:0] AB	// from A-1/8
);

reg [10:0] ram_addr;
reg	ram_we_b;

// MRDY is like wait cycles in modern CPUs
assign MRDY_b = MRDY2_b & (CHARCS_b | (H2&H4));

wire sel = ~H4;
always @(*)
//always @(sel)
	if( !sel ) begin
		ram_addr = AB;
		ram_we_b = CHARCS_b | ~RDB_b;
	end else begin
		ram_we_b = 1'b1; // line order is important here
		ram_addr = { H2, {10{FLIP}}^{V128,V64,V32,V16,V8,H128,H64,H32,H16,H8}};
	end

wire [7:0] DC;

wire CPU_access_ok = ~H4 | CHARCS_b;
wire keep_clk = H2 & ~H4;

jt74245 u10H(
	.a		( DB 			),
	.b		( DC 			),
	.dir	( RDB_b 		),
	.en_b	( CPU_access_ok )
);

wire [7:0] aux, aux2;
wire [5:0] aux3;

assign AC[9:8] = aux2[7:6];
assign CHVFLIP = aux2[5];
assign CHHFLIP = aux2[4];
assign CHHFLIPq = aux3[4];
assign CC = aux3[3:0];

jt74273 u9H( .clk(keep_clk), .d(DC), .q(aux), .cl_b(1'b1) );
jt74273 u9F( .clk(G4H), .d(aux), .q(AC[7:0]), .cl_b(1'b1) );

jt74273 u8H( .clk(G4H), .d(DC), .q(aux2), .cl_b(1'b1) );
jt74174 u8F( .clk(OH), .d(aux2[5:0]), .q(aux3), .cl_b(1'b1) );


jt_gng_genram #(.addrw(11),.id(3)) u_7H (
	.A		(ram_addr	),
	.D		(DC			),
	.cs_b	(1'b0		),
	.rd_b	(1'b0		),
	.wr_b	(ram_we_b	)
);

endmodule

