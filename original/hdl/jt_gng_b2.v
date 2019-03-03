`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-2/9 OBJECT CONTROLLER

*/

module jt_gng_b2_alt(
	input			HINIT_b,
	input			H1,
	input			H256,
	input			MATCH_b,
	input			AKB_b,
	input			BLEN,
	input			BLTIMING,
	input			LV1,

	output			phiBB,
	output	[8:0]	OB,
	output	[4:0]	OBA,
	output			TM2496_b,
	output			OBASEL_b,
	output			OBBSEL_b,
	output			OBJABWR_b,
	output			OVER96_b
);

reg blanking;
assign phiBB = ~H1;

// 2J
always @(negedge H256) begin
	blanking <= BLTIMING;
end

assign TM2496_b = blanking;

reg [1:0] base_cnt;
reg mode;
reg count_both;
//(TM2496_b | HINIT_b) & (BLEN|TM2496) )
reg OVER24;

initial base_cnt = 2'd0;
initial mode=0;

wire cnt2 = base_cnt>=2'd2 && !mode;
wire load_bus;
assign #1 load_bus = blanking ? !BLEN : HINIT;

wire load_base = load_bus || count_both || cnt2;
wire AKB = ~AKB_b;
wire next_mode;

always @(*) count_both = &{ mode, base_cnt };

always @(posedge phiBB or posedge OVER24) begin
	if( OVER24 )
		{ mode, base_cnt } <= 3'd0;
	else if( load_base )
		{ mode, base_cnt } <= { next_mode, ~next_mode, 1'b0 };
	else
		{ mode, base_cnt } <= { mode, base_cnt } + 1'b1;
end

// bus drive counter
reg [6:0] bus_cnt;
assign OB = { bus_cnt, base_cnt };
wire HINIT = !HINIT_b;
wire OVER96 = bus_cnt >= 7'd96;
assign OVER96_b = ~OVER96;
wire OVER95 = bus_cnt >= 7'd95;
wire MATCH = ~MATCH_b;
wire matched = cnt2 && ~MATCH_b;

// MATCH is only used when cnt2 is active because that marks
// byte #2 of the 4-byte sprite structure

assign next_mode = AKB || (OVER95 && !HINIT) || matched;

initial bus_cnt = 7'd0;

always @(posedge phiBB) begin
	if( load_bus )
		bus_cnt <= 7'd0;
	else if( count_both || ( !matched && cnt2 ) )
		bus_cnt <= bus_cnt + 1'd1;
end

// data buffer counter
reg [4:0] data_cnt;
assign OBA = data_cnt;

initial data_cnt = 5'd0;

wire load_data = HINIT || blanking;

always @(posedge phiBB) begin
	if( load_data ) begin
		data_cnt <= 7'd8;
		OVER24 <= 1'b0;
	end
	else if( count_both )
		{OVER24, data_cnt } <= data_cnt + 1'd1;
end

reg OBASEL, OBBSEL, OBJABWR;

always @(*) begin
	if( blanking ) begin
		OBJABWR = 1'b0;
		OBASEL  = 1'b0;
		OBBSEL  = 1'b0;
	end
	else begin
		OBJABWR = &{ mode, ~OVER24, H1 }; // H1 is the clock for this operation
		OBASEL  =  LV1;
		OBBSEL  = !LV1;
	end
end

assign OBJABWR_b = !OBJABWR;
assign OBASEL_b = !OBASEL;
assign OBBSEL_b = !OBBSEL;


endmodule

///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
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
	input			LV1,
	output	reg		OBASEL_b,
	output	reg		OBBSEL_b,
	output			OBJABWR_b,
	output			OVER96_b
);

wire	H256_b = ~H256; // 6F
wire	TM2496;
assign	#2 phiBB = ~H1; // 8D
wire	OVER24_b;

jt7474 u_2J (
	.d		(BLTIMING),
	.pr_b	(1'b1),
	.cl_b	(1'b1),
	.clk	(H256_b),
	.q		(TM2496_b),
	.q_b	(TM2496)
);

reg LV1_b;

always @(*) begin
	OBBSEL_b = TM2496_b | LV1; // 1J
	LV1_b    = ~LV1; // 5F
	OBASEL_b = TM2496_b | LV1_b; // 1J
end


wire ca_6D, ca_6E;
assign #2 OVER96_b = ~&OB[8:7];	// 5F
wire Y_6F;
assign #2 Y_6F = ~&{ ca_6D, OB[6], OB[8] }; // 6F
wire Y_5F11;
assign #2 Y_5F11 = ~&{OVER96_b, Y_6F}; // 5F
wire Y_5F6;
assign #2 Y_5F6  = ~&{Y_5F11, HINIT_b }; // 5F
wire [3:0] q_6E;
wire Y_13D3;
assign #2 Y_13D3  = OB[1] & ~q_6E[3]; // 12D, 13D
wire Y_2H6;
assign #2 Y_2H6  = MATCH_b | ~Y_13D3; // 2H, 5E
wire Y_6F6;
assign #2 Y_6F6  = ~&{AKB_b, Y_5F6, Y_2H6 }; // 6F

wire BLEN_2496;
assign #2 BLEN_2496 = BLEN | TM2496; // 2H
wire load_b;
assign #2 load_b = (TM2496_b | HINIT_b) & BLEN_2496; // 2H, 3H

jt74161 u_7D (
	.cet	(ca_6D),
	.cep	(ca_6D),
	.ld_b	(load_b),
	.clk	(phiBB),
	.cl_b	(1'b1),
	.d		(4'd0),
	.q		(OB[8:6])
);

wire Y_3H6;
assign #2 Y_3H6 = load_b & ~(ca_6E|Y_13D3); // 3H, 5E, 2H

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

wire Y_3H3;
assign #2 Y_3H3 = HINIT_b & TM2496;


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
assign #2 OVER24_b = ~OVER24; // 5E

jt74161 u_4H (
	.cet	( ca_5H	),
	.cep	( ca_5H	),
	.ld_b	( Y_3H3	),
	.clk	( phiBB	),
	.cl_b	( 1'b1  ),
	.d		( 4'd0  ),
	.q		( { OVER24, OBA[4] } )
);

assign #2 OBJABWR_b = ~&{ TM2496, q_6E[3], OVER24_b, H1 };

wire [8:0] OB_alt;
wire [4:0] OBA_alt;

jt_gng_b2_alt alt (
	.HINIT_b  (HINIT_b  ),
	.H1       (H1       ),
	.H256     (H256     ),
	.MATCH_b  (MATCH_b  ),
	.AKB_b    (AKB_b    ),
	.BLEN     (BLEN     ),
	.BLTIMING (BLTIMING ),
	.LV1      (LV1      ),
	.phiBB	  (phiBB_alt),
	.OB		  (OB_alt	),
	.OBA	  (OBA_alt  ),
	.TM2496_b (TM2496_b_alt),
	.OBASEL_b (OBASEL_b_alt),
	.OBBSEL_b (OBBSEL_b_alt),
	.OBJABWR_b(OBJABWR_b_alt),
	.OVER96_b (OVER96_b_alt )
);

wire phiBB_error    = phiBB ^ phiBB_alt;
wire OB_error       = OB  ^ OB_alt;
wire OBA_error      = OBA ^ OBA_alt;
wire TM2496_b_error = TM2496_b ^ TM2496_b_alt;
wire OBASEL_b_error = OBASEL_b ^ OBASEL_b_alt;
wire OBBSEL_b_error = OBBSEL_b ^ OBBSEL_b_alt;
wire OBJABWR_b_error= OBJABWR_b ^ OBJABWR_b_alt;
wire OVER96_b_error = OVER96_b ^ OVER96_b_alt;

endmodule // jt_gng_b2