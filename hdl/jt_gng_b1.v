`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-1/9 Objects Data RAM

*/

module jt_gng_b1(
	input		V1,
	input		V2,
	input		V4,
	input		V8,
	input		V16,
	input		V32,
	input		V64,
	input		V128,
	input		FLIP,
	input		RDB_b,	// B25
	input		WRB_b,	// B24
	output		V1F,
	output		V2F,
	output		V4F,
	output		V8F,
	output		V16F,
	output		V32F,
	output		V64F,
	output		V128F,
	output [12:0] AB,
	input [8:0]  OB,
	inout [7:0] DB,
	output 		BLCNTEN_b,
	
	input		OBASEL_b,
	input		OBBSEL_b,
	output	[7:0] DEA,
	output	[7:0] DEB,


	input		OKOUT_b,
	output		RQB_b,
	input		ALC2_b,
	input		AKB_b,
	input		OVER96_b,
	input		phiBB,
	output		BLEN,
	output	reg MATCH_b
);

// 12K, 13K
assign {V1F,V2F,V4F,V8F,V16F,V32F,V64F,V128F} 
	= {8{FLIP}} ^ { V1,V2,V4,V8,V16,V32,V64,V128};
wire [7:0] VF = {V128F, V64F, V32F, V16F, V8F, V4F, V2F, V1F};
wire FLIP_b = ~FLIP;
wire [7:0] Vaux = ~VF + { {6{FLIP_b}}, 2'b10}; // 9E 9F
wire [7:0] comp = DE + Vaux;
//assign MATCH_b = ~&comp[7:4];

always @(comp)
	casex(comp[7:4]) // avoid X
		4'b1111: MATCH_b = 1'b0;
		default: MATCH_b = 1'b1;
		4'bxxxx: MATCH_b = 1'b1;
	endcase

assign BLCNTEN_b = ~BLEN;

wire [7:0] DE;

// unnamed instances in the original
jt74245 u0 (.a(AB[7:0]), .b(OB[7:0]), .dir(1'b0), .en_b(BLCNTEN_b));
wire [5:0] pull_res = 6'h1f;
jt74245 u1 (.a({RDB_b, WRB_b, AB[12:8]}), .b( { pull_res, OB[8]} ), .dir(1'b0), .en_b(BLCNTEN_b));
jt74245 u2 (.a(DB), .b(DE), .dir(1'b1), .en_b(BLCNTEN_b));

// 11D, 13D
wire pr3_b = ALC2_b & ( RQB_b | OVER96_b );

jt7474 u14D_a (.d(1'b0), .pr_b(pr3_b), .cl_b(1'b1), 
	.clk(OKOUT_b), .q(RQB_b), .q_b(RQB));

jt7474 u14D_b (.d(AKB_b), .pr_b(RQB), .cl_b(1'b1), 
	.clk(phiBB), .q_b(BLEN));

wire mem_WE_b = phiBB | BLCNTEN_b;

wire OVER96 = ~OVER96_b; // 12D


jt_gng_genram #(.addrw(9),.id(4)) u_12E (.A(OB), .D(DE), .cs_b(1'b0), .rd_b(~mem_WE_b), .wr_b(mem_WE_b));

wire oba_en = OVER96 | OBASEL_b; // 11D
wire obb_en = OVER96 | OBBSEL_b; // 11D

jt74245 u_11F (
	.a		(DE		), 
	.b		(DEA	), 
	.dir	(1'b1	), 
	.en_b	(oba_en	)
);

jt74245 u_12F (
	.a		(DE		), 
	.b		(DEB	), 
	.dir	(1'b1	), 
	.en_b	(obb_en	)
);


endmodule // jt_gng_b1

