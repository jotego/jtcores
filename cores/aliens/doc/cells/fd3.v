// Fujitsu AV cell
// Power DFF with PRESET
// furrtek 2022

`timescale 1ns/100ps

module FD3(
	input nCK,
	input D,
	input PR,
	output reg Q = 1'b0,
	output nQ
);

	always @(negedge nCK or negedge PR) begin	// Posedge ?
		if (!PR)
			Q <= 1'b1;	// tmax = 5.2ns
		else
			Q <= D;		// tmax = 5.4ns
	end
	
	assign nQ = ~Q;

endmodule
