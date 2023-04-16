// Fujitsu AV cell
// DFF
// furrtek 2022

`timescale 1ns/100ps

module FDM(
	input CK,
	input D,
	output reg Q,
	output nQ
);

always @(posedge CK)
		Q <= D;		// tmax = 6.0ns

assign nQ = ~Q;

endmodule
