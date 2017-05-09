module jt74161(
	input cet,
	input cep,
	input ld_b,
	input clk,
	input cl_b,
	input [3:0] d,
	output [3:0] q,
	output ca
 );

	assign ca = &{q, cet};

	always @(posedge clk or negedge cl_b) 
		if( !cl_b )
			q <= 4'd0;
		else begin
			if(!ld_b) q <= d;
			else if( cep&&cet ) q <= q+4'd1;
		end

endmodule // jt74161

module jt7474(
	input d,
	input pr_b,
	input cl_b,
	input clk,
	output q,
	output q_b
);

	assign q_b = ~q;

	if( posedge clk or negedge cl_b or negedge pr_b )
		if( !pr_b ) q <= 1'b1;
		else if(!cl_b) q <= 1'b0;
		else if( clk ) q <= d;

endmodule

module jt74138(
	input e1_b,
	input e2_b,
	input e3,
	input [2:0] a,
	output reg [7:0] y_b 
);

	always @(*)
		if( !e1_b && !e2_b && e3 )
			y_b <= 8'hff;
		else y_b = ~ ( 8'b1 << a );

endmodule

module jt74112(
	input pr_b,
	input cl_b,
	input clk_b,
	input j,
	input k
	output q,
	output q_b
);

	assign q_b = ~q;

	if( negedge clk_b or negedge pr_b or negedge cl_b )
		if( !pr_b ) q <= 1'b1;
		else if( !cl_b ) q <= 1'b0;
		else if( !clk_b )
			case( {j,k} )
				2'b01: q<=1'b0;
				2'b10: q<=1'b1;
				2'b11: q<=~q;
			endcase // {j,k}

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