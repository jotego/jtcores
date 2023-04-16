// Fujitsu AV cell
// 4-bit Data Latch
// furrtek 2022

`timescale 1ns/100ps

module LT4(
	input nG,
	input [3:0] D,
	output reg [3:0] P = 4'd0,
	output [3:0] N
);

	always @(*)
		if (!nG) P <= D;	// tmax = 7.5ns
	
	assign N = ~P;

endmodule
