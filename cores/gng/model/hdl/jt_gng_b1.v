`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-1/9 Objects Data RAM

*/

module jt_gng_b1_alt(
	input [7:0]		V,
	input		FLIP,
	input [8:0]  OB,
	inout [7:0] DB,
	input		OBASEL_b,
	input		OBBSEL_b,
	input		ALC2_b,
	input		AKB_b,
	input		OVER96_b,
	input		phiBB,
	input		OKOUT_b,

	output		RDB_b,	// B25
	output		WRB_b,	// B24
	output	[7:0]	VF,
	output [12:0] AB,
	output 		BLCNTEN_b,
	output	[7:0] DEA,
	output	[7:0] DEB,
	output		RQB_b,
	output	reg	BLEN,
	output		MATCH_b
);

wire [7:0] DE;
assign BLCNTEN_b = !BLEN;
wire mem_WE_b = BLCNTEN_b | phiBB;

assign #2 AB = !BLCNTEN_b ? {4'hf, OB} : 13'hzzz;
assign #2 { WRB_b, RDB_b } = !BLCNTEN_b ? 2'b10 : 2'bzz;

jt_gng_genram_alt #(.addrw(9),.id(104)) u_12E (
	.A(OB), .din(DB), .dout(DE),.cs_b(1'b0), .rd_b(~mem_WE_b), .wr_b(mem_WE_b)
);

wire OBASEL = !OBASEL_b;
wire OBBSEL = !OBBSEL_b;
wire OVER96 = !OVER96_b;

assign #2 DEA = !OVER96 && OBASEL ? DE : 8'hff;
assign #2 DEB = !OVER96 && OBBSEL ? DE : 8'hff;
assign #2 VF  = {8{FLIP}} ^ V;

wire [7:0] Vaux = ~VF + { {6{~FLIP}}, 2'b10};
wire [7:0] sumData = !BLCNTEN_b? DB:DE;
wire [7:0] sum  = sumData + Vaux;

// 10H
wire MATCH;
assign #2 MATCH = &sum[7:4];
assign MATCH_b = ~MATCH;

wire OKOUT = !OKOUT_b;
reg okout_latch;

wire ALC2 = !ALC2_b;

// 13D, 11D
wire rst;
assign #2 rst  = (OVER96&&okout_latch) || ALC2;
wire rstb = ~rst;

always @(negedge OKOUT or negedge rstb )
	if( !rstb )
		okout_latch <= 1'b0;
	else
		okout_latch <= 1'b1;

assign RQB_b = !okout_latch;

always @(posedge phiBB or negedge okout_latch)
	if( !okout_latch )
		BLEN <= 1'b0;
	else
		BLEN <= !AKB_b;

endmodule

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
	inout		RDB_b,	// B25
	inout		WRB_b,	// B24
	output		V1F,
	output		V2F,
	output		V4F,
	output		V8F,
	output		V16F,
	output		V32F,
	output		V64F,
	output		V128F,
	inout [12:0] AB,
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
	output		MATCH_b
);

// 12K, 13K
assign {V1F,V2F,V4F,V8F,V16F,V32F,V64F,V128F}
	= {8{FLIP}} ^ { V1,V2,V4,V8,V16,V32,V64,V128};
wire [7:0] VF = {V128F, V64F, V32F, V16F, V8F, V4F, V2F, V1F};
wire FLIP_b = ~FLIP;
wire [7:0] Vaux = ~VF + { {6{FLIP_b}}, 2'b10}; // 9E 9F
wire [7:0] comp = DE + Vaux;
assign MATCH_b = comp[7:4]==4'hf ? 1'b0 : 1'b1;
/*
always @(comp)
	casex(comp[7:4]) // avoid X
		4'b1111: MATCH_b = 1'b0;
		default: MATCH_b = 1'b1;
		4'bxxxx: MATCH_b = 1'b1;
	endcase
*/
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

wire [7:0] VF_alt;
wire [12:0] AB_alt;
wire [7:0] DEA_alt, DEB_alt;
jt_gng_b1_alt alt (
	.V        ({V128,V64,V32,V16,V8,V4,V2,V1}),
	.FLIP     (FLIP     ),
	.OB       (OB       ),
	.DB       (DB       ),
	.OBASEL_b (OBASEL_b ),
	.OBBSEL_b (OBBSEL_b ),
	.ALC2_b   (ALC2_b   ),
	.AKB_b    (AKB_b    ),
	.OVER96_b (OVER96_b ),
	.phiBB    (phiBB    ),
	.OKOUT_b  (OKOUT_b  ),

	.RDB_b    (RDB_b_alt),
	.WRB_b    (WRB_b_alt),
	.VF       (VF_alt   ),
	.AB       (AB_alt   ),
	.BLCNTEN_b(BLCNTEN_b_alt),
	.DEA      (DEA_alt  ),
	.DEB      (DEB_alt  ),
	.RQB_b    (RQB_b_alt),
	.BLEN     (BLEN_alt     ),
	.MATCH_b  (MATCH_b_alt  )
);

wire RDB_b_error = !BLCNTEN_b ? (RDB_b ^ RDB_b_alt) : 1'b0;
wire WRB_b_error = !BLCNTEN_b ? (WRB_b ^ WRB_b_alt) : 1'b0;
wire VF_error = |( {V128F,V64F,V32F,V16F,V8F,V4F,V2F,V1F} ^ VF_alt );
wire AB_error = (|(AB ^ AB_alt)) & !BLCNTEN_b;
wire BLCNTEN_b_error = BLCNTEN_b ^ BLCNTEN_b_alt;
wire DEA_error = !BLCNTEN_b ? |(DEA ^ DEA_alt) : 1'b0;
wire DEB_error = !BLCNTEN_b ? |(DEB ^ DEB_alt) : 1'b0;
wire RQB_b_error = RQB_b ^ RQB_b_alt;
wire BLEN_error = BLEN ^ BLEN_alt;
wire MATCH_b_error = MATCH_b ^ MATCH_b_alt;


endmodule // jt_gng_b1

