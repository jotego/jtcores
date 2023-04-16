// Fujitsu AV cell
// DFF with SET and RESET
// furrtek 2022

`timescale 1ns/100ps

module FDP(
	input CK,
	input D,
	input S, R,
	output reg Q = 1'b0,
	output nQ
);

	always @(posedge CK, negedge S, negedge R) begin
		if (!S)
			Q <= 1'b1;	// tmax = 3.0ns
		else if (!R)
			Q <= 1'b0;	// tmax = 2.9ns
		else
			Q <= #1 D;	// tmax = 6.1ns
	end
	
	assign nQ = ~Q;

endmodule
