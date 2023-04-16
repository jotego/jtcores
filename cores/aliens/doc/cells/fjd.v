// Fujitsu AV cell
// Positive Edge Clocked Power JKFF with CLEAR
// furrtek 2022

`timescale 1ns/100ps

module FJD(
	input CK,
	input J, K,
	input nCL,
	output reg Q = 1'b0,
	output nQ
);
	
	always @(posedge CK or negedge nCL) begin
		if (~nCL)
			Q <= #1 1'b0;					// tmax = 5.1ns
		else begin
			case({J, K})
				2'b00 : Q <= #2 Q;		// tmax = 7.9ns
				2'b01 : Q <= #2 1'b0;
				2'b10 : Q <= #2 1'b1;
				2'b11 : Q <= #2 ~Q;
			endcase
		end
	end
	
	assign nQ = ~Q;

endmodule
