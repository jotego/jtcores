// Fujitsu AV cell
// Positive Edge Clocked Power DFF with CLEAR
// furrtek 2022

`timescale 1ns/100ps

module FDE(
	input CK,
	input D,
	input nCL,
	output reg Q,
	output nQ
);

// Same function as FDO and FDG ?

always @(posedge CK or negedge nCL) begin
	if (!nCL)
		Q <= 1'b0;	// tmax = 5.2ns
	else
		Q <= D;		// tmax = 6.3ns
end

assign nQ = ~Q;

endmodule
