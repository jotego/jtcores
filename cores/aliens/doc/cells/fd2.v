// Fujitsu AV cell
// Power DFF
// furrtek 2022

`timescale 1ns/100ps

module FD2(
	input nCK,
	input D,
	output reg Q,
	output nQ
);

	always @(negedge nCK)
		Q <= #1 D;	// tmax = 4.9ns
	
	assign nQ = ~Q;

endmodule
