
// synchronous presettable 4-bit binary counter, asynchronous clear
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

// synchronous presettable 4-bit binary counter, synchronous clear
module jt74163(
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

	always @(posedge clk)
		if( !cl_b )
			q <= 4'd0;
		else begin
			if(!ld_b) q <= d;
			else if( cep&&cet ) q <= q+4'd1;
		end

endmodule // jt74163

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
	output [7:0] y_b
);
	reg [7:0] yb_nodly;
	always @(*)
		if( e1_b || e2_b || !e3 )
			yb_nodly <= 8'hff;
		else yb_nodly = ~ ( 8'b1 << a );
	assign #2 y_b = yb_nodly;
endmodule

// Dual 2-to-4 line decoder/demultiplexer
module jt74139(
	input 	en1_b,
	input 		[1:0] 		a1,
	output  	[3:0] 		y1_b,
	input 	en2_b,
	input 		[1:0] 		a2,
	output  	[3:0] 		y2_b
);
	assign #2 y1_b = en1_b ? 4'hf : ~( (4'b1)<<a1 );
	assign #2 y2_b = en2_b ? 4'hf : ~( (4'b1)<<a2 );
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

	assign #2 a = en_b || dir  ? 8'hzz : b;
	assign #2 b = en_b || !dir ? 8'hzz : a;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74233(
	input [7:0] d,
	output reg [7:0] q,
	input cl_b, // CLEAR, reset
	input clk
);
	initial q=8'd0;
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
	initial q=6'd0;
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
	assign #2 Y[3:0] = !en4_b ? A[3:0] : 4'hz;
	assign #2 Y[5:4] = !en6_b ? A[5:4] : 2'hz;
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
	output	[3:0] Y
);
	reg [3:0] y_nodly;
	assign #2 Y = y_nodly;
	always @(*)
		if( st_l ) y_nodly = 4'd0;
		else y_nodly = sel ? B : A;

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
	output  [3:0] s,
	output 	cout
);
	assign #2 {cout,s} = a+b+cin;

endmodule

// Quad 2-input multiplexer; 3-state
module jt74257(
	input sel,
	input en_b,
	input [3:0] a,
	input [3:0] b,
	output [3:0] y
);

reg [3:0] y_nodly;
assign #2 y = y_nodly;

always @(*)
	if( !en_b )
		y_nodly = sel ? b : a;
	else
		y_nodly = 4'hz;

endmodule

// 8-bit addressable latch
module jt74259(
	input		D,
	input [2:0] A,
	input		LE_b,
	input		MR_b,
	output reg [7:0]	Q
);

initial Q=8'd0;

always @(*)
	if(!MR_b) Q=8'd0;
		else if(!LE_b) Q[A] <= D;

endmodule