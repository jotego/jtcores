// Fujitsu AV cell
// 4-bit Serial-in Parallel-out Shift Register
// furrtek 2022

`timescale 1ns/100ps

module FS1(
	input CK,
	input SD,
	output reg [3:0] Q
);

	always @(negedge CK)
		Q <= #1 {Q[2:0], ~SD};	// tmax = 7.9ns

endmodule
