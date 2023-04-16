// Fujitsu AV cell
// Power 3-AND 4-wide Multiplexer
// furrtek 2022

`timescale 1ns/100ps

module T34(
	input [2:0] A,
	input [2:0] B,
	input [2:0] C,
	input [2:0] D,
	output X
);

assign X = ~|{&{A}, &{B}, &{C}, &{D}};	// tmax = 3.3ns

endmodule
