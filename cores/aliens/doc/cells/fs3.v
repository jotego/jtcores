// Fujitsu AV cell
// 4-bit Shift Register With Asynchronous Load
// furrtek 2022

`timescale 1ns/100ps

module FS3(
	input CK,
	input [3:0] P,
	input SD, nL,
	output reg [3:0] Q = 4'd0
);
	
	always @(posedge CK, negedge nL) begin
		if (!nL)
			Q <= #2 P;					// Load tmax = 8.1ns
		else
			Q <= #1 {Q[2:0], SD};	// Shift tmax = 6.1ns
	end

endmodule
