`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-8/9 Scroll video RAM

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
	output		V1F,
	output		V2F,
	output		V4F,
	output		V8F,
	output		V16F,
	output		V32F,
	output		V64F,
	output		V128F,
	input [12:0] AB,
	inout [8:0]  OB,
	output [7:0] DB,
	output 		BLCNTEN_b,

	input		OKOUT_b,
	output		ROB_b,
	input		ACL2_b,
	input		AKB_b,
	input		OVER96_b,
	input		phi_BB,
	output		BLEN,
	output		MATCH_b,
);

// 12K, 13K
assign {V1F,V2F,V4F,V8F,V16F,V32F,V64F,V128F} 
	= {8{FLIP}} ^ { V1,V2,V4,V8,V16,V32,V64,V128};
wire [7:0] VF = {V128F, V64F, V32F, V16F, V8F, V4F, V2F, V1F};
wire [7:0] Vaux = ~VF + ~{ {6{FLIP}}, 1'b0, FLIP};
wire [7:0] comp = DE + Vaux;
assign MATCH_b = ~&comp[7:4];

assign BLCNTEN_b = ~BLEN;

wire [7:0] DE;

// unnamed instances in the original
jt74245 u0 (.a(AB[7:0]), .b(OB[7:0]), .dir(1'b0), .en_b(BLCNTEN_b));
jt74245 u1 (.a(AB[8]), .b(OB[8]), .dir(1'b0), .en_b(BLCNTEN_b));
jt74245 u2 (.a(DB), .b(DE), .dir(1'b1), .en_b(BLCNTEN_b));

wire ROB;
// 11D, 13D
wire pr3_b = ACL2_b & ( ROB_b | OVER96_b );

jt7474 u14D_a (.d(1'b0), .pr_b(pr3_b), .cl_b(1'b1), 
	.clk(OKOUT_b), .q(ROB_b), .q_b(ROB));

jt7474 u14D_b (.d(AKB_b), .pr_b(ROB), .cl_b(1'b1), 
	.clk(phi_BB), .q_b(BLEN));

wire mem_WE_b = phi_BB | BLCNTEN_b;

M2114x2 m
	.addr	( {1'b0, OB} ),
	.d		( DE		 ),
	.ce_b	( 1'b0		 ),
	.we_b	( mem_WE_b	 )
	);


endmodule // jt_gng_b1

