module jt74161(
	input cet,
	input cep,
	input ld_b,
	input clk,
	input cl_b,
	input [3:0] d,
	output reg [3:0] q,
	output ca
 );

	assign ca = &{q, cet};

	initial q=4'd0;

	always @(posedge clk or negedge cl_b) 
		if( !cl_b )
			q <= 4'd0;
		else begin
			if(!ld_b) q <= d;
			else if( cep&&cet ) q <= q+4'd1;
		end

endmodule // jt74161

// Dual D-type flip-flop with set and reset; positive edge-trigger
module jt7474(
	input d,
	input pr_b,
	input cl_b,
	input clk,
	output reg q,
	output q_b
);

	assign q_b = ~q;

	initial q=1'b0;

	always @( posedge clk or negedge cl_b or negedge pr_b )
		if( !pr_b ) q <= 1'b1;
		else if(!cl_b) q <= 1'b0;
		else if( clk ) q <= d;

endmodule

// 3-to-8 line decoder/demultiplexer; inverting
module jt74138(
	input e1_b,
	input e2_b,
	input e3,
	input [2:0] a,
	output reg [7:0] y_b 
);

	always @(*)
		if( e1_b || e2_b || !e3 )
			y_b <= 8'hff;
		else y_b = ~ ( 8'b1 << a );

endmodule

module jt74112(
	input  pr_b,
	input  cl_b,
	input  clk_b,
	input  j,
	input  k,
	output reg q,
	output q_b
);

	assign q_b = ~q;

	initial q=1'b0;

	always @( negedge clk_b or negedge pr_b or negedge cl_b )
		if( !pr_b ) q <= 1'b1;
		else if( !cl_b ) q <= 1'b0;
		else if( !clk_b )
			case( {j,k} )
				2'b01: q<=1'b0;
				2'b10: q<=1'b1;
				2'b11: q<=~q;
			endcase // {j,k}

endmodule

// Octal bus transceiver; 3-state
module jt74245(
	inout [7:0] a,
	inout [7:0] b,
	input dir,
	input en_b
);

	assign a = en_b || dir  ? 8'hzz : b;
	assign b = en_b || !dir ? 8'hzz : a;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74233(
	input [7:0] d,
	output reg [7:0] q,
	input cl_b, // CLEAR, reset
	input clk
);

	always @(posedge clk or negedge cl_b)
		if( !cl_b ) q<=8'h0;
		else q<= d;

endmodule

// Hex D-type flip-flop with reset; positive-edge trigger
module jt74174(
	input [5:0] d,
	output reg [5:0] q,
	input cl_b, // CLEAR, reset
	input clk
);

	always @(posedge clk or negedge cl_b)
		if( !cl_b ) q<=6'h0;
		else q<= d;

endmodule

module jt74367(
	input [5:0] A,
	output [5:0] Y,
	input en4_b,
	input en6_b
);
	assign Y[3:0] = !en4_b ? A[3:0] : 4'hz;
	assign Y[5:4] = !en6_b ? A[5:4] : 2'hz;
endmodule

// 4-bit bidirectional universal shift register
module jt74194(
	input [3:0] D,
	input [1:0] S,
	input clk,
	input cl_b,
	input R, 	// right
	input L,  	// left
	output reg [3:0] Q
);
	// reg clk2;
	// always @(clk)
	// 	clk2 = #1 clk;

	always @(posedge clk)
		if( !cl_b )
			Q <= 4'd0;
		else case( S )
			2'b10: Q <= { L, Q[3:1] };
			2'b01: Q <= { Q[2:0], R };
			2'b11: Q <= D;
		endcase
endmodule

module jt74157(
	input	sel,
	input	st_l,
	input	[3:0] A,
	input	[3:0] B,
	output	reg [3:0] Y
);

	always @(*)
		if( st_l ) Y = 4'd0;
		else Y = sel ? B : A;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74273(
	input	[7:0] d,
	input	clk,
	input	cl_b,
	output	reg [7:0] q
);

	always @(posedge clk or negedge cl_b)
		if(!cl_b)
			q <= 8'd0;
		else if(clk) q<=d;

endmodule

// 4-bit binary full adder with fast carry
module jt74283(
	input [3:0] a,
	input [3:0] b,
	input 		cin,
	output reg [3:0] s,
	output reg	cout
);

	always @(a,b,cin) {cout,s} <= a+b+cin;

endmodule