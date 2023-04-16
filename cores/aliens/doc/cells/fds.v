// Fujitsu AV cell
// Positive Edge Clocked 4-bit DFF
// furrtek 2022

`timescale 1ns/100ps

module FDS(
	input CK,
	input [3:0] D,
	output reg [3:0] Q = 4'd0
);

	always @(posedge CK)
		Q <= D;		// tmax = 7.7ns

endmodule
