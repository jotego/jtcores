// Fujitsu AV cell
// Power DFF with CLEAR and PRESET
// furrtek 2022

`timescale 1ns/100ps

module FD4(
	input CK,
	input D,
	input PR, CL,
	output reg Q = 1'b0,
	output nQ
);

	always @(negedge CK, negedge PR, negedge CL) begin
		if (~PR)
			Q <= #1 1'b1;	// tmax = 5.7ns
		else if (~CL)
			Q <= #1 1'b0;	// tmax = 5.7ns (typo ?)
		else
			Q <= #1 D;		// tmax = 5.7ns (typo ?)
	end
	
	assign nQ = ~Q;

endmodule
