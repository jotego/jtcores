// Fujitsu AV cell
// Positive Edge Clocked DFF with CLEAR
// furrtek 2022

`timescale 1ns/100ps

module FDG(
	input CK,
	input D,
	input nCL,
	output reg Q,
	output nQ
);

// Same function as FDO ?

always @(posedge CK or negedge nCL) begin
	if (!nCL)
		Q <= 1'b0;	// tmax = 5.3ns
	else
		Q <= D;		// tmax = 4.2ns
end

assign nQ = ~Q;

endmodule
