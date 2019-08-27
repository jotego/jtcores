`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-6/9 Line buffer 2

*/

module jt_gng_b6(
	output	[7:0]	OBJ,	// OBJ2
	inout	[7:0]	COL,
	input			ST_b,
	input			OBFLIP,
	input			OB6M,
	input	[7:0]	DF,
	input			LOAD_b,
	input			HOVER,
	input			CL_b,
	input			WR_b,
	input			L6MB
);

reg [7:0] dmux;
pullup( D[7], D[6], D[5], D[4], D[3], D[2], D[1], D[0] );
pullup( COL[7], COL[6], COL[5], COL[4], COL[3], COL[2], COL[1], COL[0] );
// 6L, 7L (74257)
wire [7:0] D = !ST_b ? dmux : 8'hzz;
wire sel;
// assign #2 sel = |(~OBJ[3:0]);
assign #2 sel = &(OBJ[3:0]);
always @(*)
	dmux = sel ? COL : OBJ;

jt74273 u_273 (.d(D), .clk(L6MB), .cl_b(CL_b), .q(OBJ));

wire [8:0] cnt;
wire [1:0] carry;

jt74163 u_9L (
	.cet	(1'b1	),
	.cep	(1'b1	),
	.ld_b	(LOAD_b	),
	.clk	(OB6M	),
	.cl_b	(CL_b	),
	.d		(DF[3:0]),
	.q		(cnt[3:0]),
	.ca		(carry[0])
);

jt74163 u_9M (
	.cet	(carry[0]),
	.cep	(carry[0]),
	.ld_b	(LOAD_b	),
	.clk	(OB6M	),
	.cl_b	(CL_b	),
	.d		(DF[7:4]),
	.q		(cnt[7:4]),
	.ca		(carry[1])
);

wire [2:0] NoConn;

jt74163 u_9N (
	.cet	(carry[1]),
	.cep	(carry[1]),
	.ld_b	(LOAD_b	),
	.clk	(OB6M	),
	.cl_b	(CL_b	),
	.d		({3'b0, HOVER}),
	.q		({NoConn[2:0],cnt[8]})
);

wire [7:0] A = {8{OBFLIP}} ^ cnt[7:0];

jt_gng_genram #(.addrw(8), .id(20)) LINE_BUF (
	.A		(A		),
	.D		(D		),
	.cs_b	(cnt[7]	),
	.rd_b	(1'b0	),
	.wr_b	(WR_b	)
);


endmodule // jt_gng_b6