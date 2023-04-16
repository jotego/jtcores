// Fujitsu AV cell
// 4-bit DFF with CLEAR
// furrtek 2022

`timescale 1ns/100ps

module FDR(
	input CK,
	input [3:0] D,
	input nCL,
	output reg [3:0] Q = 4'd0
);

	always @(posedge CK or negedge nCL) begin
		if (!nCL)
			Q <= 4'd0;	// tmax = 6.7ns
		else
			Q <= D;		// tmax = 8.4ns
	end

endmodule
