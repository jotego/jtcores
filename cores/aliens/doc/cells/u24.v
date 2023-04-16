// Fujitsu AV cell
// Power 2-OR 4-wide Multiplexer
// furrtek 2022

`timescale 1ns/100ps

module U24(
	input [1:0] A,
	input [1:0] B,
	input [1:0] C,
	input [1:0] D,
	output X
);

assign X = ~&{|{A}, |{B}, |{C}, |{D}};	// tmax = 3.2ns

endmodule
