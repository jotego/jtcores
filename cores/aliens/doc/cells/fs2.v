// Fujitsu AV cell
// 4-bit Shift Register With Synchronous Load
// furrtek 2022

`timescale 1ns/100ps

module FS2(
	input CK,
	input [3:0] P,
	input SD, L,
	output reg [3:0] Q = 4'd0
);

	always @(negedge CK)
	begin
		if (L)
			Q <= #1 P;					// Load tmax = ?
		else
			Q <= #1 {Q[2:0], SD};	// Shift tmax = 7.9ns
	end

endmodule
