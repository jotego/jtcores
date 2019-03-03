`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-9/9 Scroll ROM

*/

module shift8(
	input [7:0] D,
	output Y,
	input [1:0] S,
	input SEL,
	input clk
);
	wire [3:0] Q4A, Q4B;

	jt74194 u_4A(
		.D		( { D[0], D[1], D[2], D[3] }	),
		.R		( 1'b0		),
		.L		( Q4B[0]	),
		.cl_b	( 1'b1		),
		.clk	( clk		),
		.S		( S			),
		.Q		( Q4A		)
	);

	jt74194 u_4B(
		.D		( { D[4], D[5], D[6], D[7] }	),
		.R		( Q4A[3]	),
		.L		( 1'b0		),
		.cl_b	( 1'b1		),
		.clk	( clk		),
		.S		( S			),
		.Q		( Q4B		)
	);
	assign Y = SEL ? Q4B[3] : Q4A[0];
endmodule

module jt_gng_b9(
	input [9:0]		AS,		// from 8/9
	input			SH8,
	input			SHFLIP,
	input			SHFLIP_q,
	input			V8S,
	input			V4S,
	input			V2S,
	input			V1S,
	input			SVFLIP,
	input			S6M,
	input			FLIP_buf,
	output			SCRX,
	output			SCRY,
	output			SCRZ,
	input			S7H_b
);

reg [7:0] 	mem_3b [0:16383];
reg [7:0]	mem_3c [0:16383];
reg [7:0]	mem_3e [0:16383];
reg [7:0]	mem_1b [0:16383];
reg [7:0]	mem_1c [0:16383];
reg [7:0]	mem_1e [0:16383];

initial begin
	$readmemh("../../rom/3b.hex", mem_3b);
	$readmemh("../../rom/3c.hex", mem_3c);
	$readmemh("../../rom/3e.hex", mem_3e);
	$readmemh("../../rom/1b.hex", mem_1b);
	$readmemh("../../rom/1c.hex", mem_1c);
	$readmemh("../../rom/1e.hex", mem_1e);
end

reg [4:0] addr_lsb;

always @(*)
	addr_lsb = { SHFLIP^SH8, {4{SVFLIP}}^{V8S,V4S,V2S,V1S} };

reg [13:0] addr;

always @(*)
	addr = { AS, addr_lsb };

reg [7:0] X,Y,Z;

always @(addr,AS[9])
	if( AS[9] ) begin
		X = mem_3b[addr];
		Y = mem_3c[addr];
		Z = mem_3e[addr];
	end
	else begin
		X = mem_1b[addr];
		Y = mem_1c[addr];
		Z = mem_1e[addr];
	end

wire XL, YL, ZL;
reg [1:0] S;
wire [3:0] Q4A, Q4B;
wire SEL = FLIP_buf ^ SHFLIP_q;

always @(*) begin
	S[0] = ~S7H_b |  SEL;
	S[1] = ~S7H_b | ~SEL;
end

shift8 U4AB( .D(X), .clk(S6M), .S(S), .Y(SCRX), .SEL(SEL) );
shift8 U4CD( .D(Y), .clk(S6M), .S(S), .Y(SCRY), .SEL(SEL) );
shift8 U4EF( .D(Z), .clk(S6M), .S(S), .Y(SCRZ), .SEL(SEL) );

endmodule // jt_gng_b9