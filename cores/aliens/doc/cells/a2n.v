// Fujitsu AV cell
// 2-bit Full Adder
// furrtek 2022

`timescale 1ns/100ps

module A2N(
	input [1:0] A,
	input [1:0] B,
	input CIN,
	output [1:0] S,
	output CO
);

assign {CO, S} = A + B + {1'd0, CIN};	// tmax = 5.3ns

endmodule
