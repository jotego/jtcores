`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-7/9 Scroll H position

*/

module jt_gng_b7(
	input	[7:0]	DB,		// from 1/9
	input	[3:0]	AB,
	input			CBCS_b,	// from B13
	input			G6M,	// from 4/9
	input			FLIP,
	input			H256,	// from 3/9
	input			H128,
	input			H64,
	input			H32,
	input			H16,
	input			H8,
	input			H4,
	input			H2,
	input			H1,
	output			SH2,		// to 8/9
	output			SH8,		// to 8/9
	output			SH16,		// to 8/9
	output			SH32,		// to 8/9
	output			SH64,		// to 8/9
	output			SH128,		// to 8/9
	output			SH256,		// to 8/9
	input			SCRCS_b,	// from B14
	output			MRDY2_b,	// to B15
	output			SCREN_b,	// to 8/9
	output			POS2,	// to 8/9
	output			POS3,
	output	reg		S0H,
	output	reg		S2H,
	output	reg		S4H,
	output			FLIP_buf,	// to 9/9
	output			S7H_b,
	output			S6M

);

wire [7:0] POS;
assign POS2=POS[2];
assign POS3=POS[3];

assign FLIP_buf = FLIP;
assign S6M = G6M;

jt74138 u_13A(
	.e1_b	( CBCS_b	),
	.e2_b	( CBCS_b	),
	.e3		( AB[3]		),
	.a		( AB[2:0]	),
	.y_b	( POS		)
);

wire [8:0] hscroll;
reg [7:0] DBdly;

// Real board uses DB but due to ideal signal delays
// on simulation, DB's gets latched as ZZ by u_12A/u_14A
always @(posedge H1) DBdly <= DB;

jt74273 u_12A(
	.d		( DBdly			),
	.q		( hscroll[7:0]	),
	.cl_b	( 1'b1			),
	.clk	( POS[0]		)
);

jt7474 u_14A(
	.d		( DBdly[0]		),
	.pr_b	( 1'b1			),
	.cl_b	( 1'b1			),
	.clk	( POS[1]		),
	.q		( hscroll[8]	)
);

reg [8:0] HF, SHx;
reg Haux;

always @(*) begin
	// 14B, 14C
	HF[6:0] = {8{FLIP}}^{H64,H32,H16,H8,H4,H2,H1};
	// 13C
	Haux  = ~FLIP ^ HF[6]; // Haux = ~HF[6] ??
	// 13D 13C
	HF[8] = ~H256;
	HF[7] = (~H256&~HF[6])^(FLIP&H128);
	// 13B 12B 12C
	SHx = hscroll + HF;
end

assign SH256 = SHx[8];
assign SH128 = SHx[7];
assign  SH64 = SHx[6];
assign  SH32 = SHx[5];
assign  SH16 = SHx[4];
assign   SH8 = SHx[3];

wire [7:0] SHdecod;

jt74138 u_10C(
	.e1_b	( 1'b0		),
	.e2_b	( 1'b0		),
	.e3		( 1'b1		),
	.a		( {3{FLIP}}^SHx[2:0]	),
	.y_b	( SHdecod	)
);

assign S7H_b = SHdecod[7];
reg clk_mrdy;

always @(posedge G6M) begin
	S0H 	 = ~SHdecod[7];
	clk_mrdy = ~SHdecod[5];
	S4H 	 = ~SHdecod[3];
	S2H 	 = ~SHdecod[1];
end

assign SH2 = SHx[1];

wire [1:0] mrdyq;

jt7474 u_7Ca(
	.d		( 1'b1 		),
	.pr_b	( 1'b1 		),
	.clk	( clk_mrdy	),
	.cl_b	( mrdyq[0]	),
	.q		( mrdyq[1]	)
);

jt7474 u_7Cb(
	.d		( 1'b1 		),
	.pr_b	( 1'b1 		),
	.clk	( S4H		),
	.cl_b	( ~S0H		),
	.q		( mrdyq[0]	)
);

assign MRDY2_b =  mrdyq[1] | SCRCS_b;
assign SCREN_b = ~mrdyq[0] | SCRCS_b;

endmodule // jt_gng_a7