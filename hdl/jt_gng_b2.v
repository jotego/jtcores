`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-2/9 OBJECT CONTROLLER

*/

module jt_gng_b2(
	input			HINIT_b,
	input			H1,
	input			H256,
	output			phiBB,
	input			MATCH_b,
	input			AKB_b,
	input			BLEN,
	output	[8:0]	OB,
	output	[4:0]	OBA,
	input			BLTIMING,
	output			TM2496_b,
	input			LVI,
	output			OBASEL_b,
	output			OBBSEL_b,
	output			OBJABWR_b,
	output			OVER96_b
);

wire	H256_b = ~H256; // 6F
wire	TM2496;
assign	phiBB = ~H1; // 8D
wire	OVER24_b;

jt7474 u_2J (
	.d		(BLTIMING), 
	.pr_b	(1'b1), 
	.cl_b	(1'b1), 
	.clk	(H256_b), 
	.q		(TM2496_b), 
	.q_b	(TM2496)
);

assign OBBSEL_b = TM2496_b | LVI; // 1J
wire	LVI_b   = ~LVI; // 5F
assign OBASEL_b = TM2496_b | LVI_b; // 1J

wire ca_6D, ca_6E;
assign OVER96_b = ~&OB[8:7];	// 5F
wire Y_6F = ~&{ ca_6D, OB[6], OB[8] }; // 6F
wire Y_5F11 = ~&{OVER96_b, Y_6F}; // 5F
wire Y_5F6  = ~&{Y_5F11, HINIT_b }; // 5F
wire [3:0] q_6E;
wire Y_13D3  = OB[1] & ~q_6E[3]; // 12D, 13D
wire Y_2H6  = MATCH_b | ~Y_13D3; // 2H, 5E
wire Y_6F6  = ~&{AKB_b, Y_5F6, Y_2H6 }; // 6F 

wire BLEN_2496 = BLEN | TM2496; // 2H
wire load_b = (TM2496_b | HINIT_b) & BLEN_2496; // 2H, 3H

jt74161 u_7D (
	.cet	(ca_6D), 
	.cep	(ca_6D), 
	.ld_b	(load_b), 
	.clk	(phiBB), 
	.cl_b	(1'b1), 
	.d		(4'd0), 
	.q		(OB[8:6])
);

wire Y_3H6 = load_b & ~(ca_6E|Y_13D3); // 3H, 5E, 2H

jt74161 u_6E (
	.cet	(1'b1		), 
	.cep	(1'b1		), 
	.ld_b	(Y_3H6		), 
	.clk	(phiBB		), 
	.cl_b	(OVER24_b	), 
	.d		({Y_6F6, Y_6F6, ~Y_6F6, 1'b0}), 
	.q		(q_6E		), 
	.ca		(ca_6E		)
);

assign OB[1:0] = q_6E[1:0];

wire Y_1J3 = (MATCH_b&Y_13D3) | ca_6E;

jt74161 u_6D (
	.cet	(Y_1J3		), 
	.cep	(Y_1J3		), 
	.ld_b	(load_b		), 
	.clk	(phiBB		), 
	.cl_b	(1'b1		), 
	.d		(4'd0		), 
	.q		(OB[5:2]	), 
	.ca		(ca_6D		)
);

wire Y_3H3 = HINIT_b & TM2496;


jt74161 u_5H (
	.cet	( ca_6E	), 
	.cep	( ca_6E	), 
	.ld_b	( Y_3H3	), 
	.clk	( phiBB ), 
	.cl_b	( 1'b1  ), 
	.d		( 4'h8  ), 
	.q		( OBA[3:0]	), 
	.ca		( ca_5H	)
);

wire OVER24;
assign OVER24_b = ~OVER24; // 5E

jt74161 u_4H (
	.cet	( ca_5H	), 
	.cep	( ca_5H	), 
	.ld_b	( Y_3H3	), 
	.clk	( phiBB	), 
	.cl_b	( 1'b1  ), 
	.d		( 4'd0  ), 
	.q		( { OVER24, OBA[4] } )
);



endmodule // jt_gng_b2