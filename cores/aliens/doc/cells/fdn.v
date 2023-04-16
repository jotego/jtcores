// Fujitsu AV cell
// DFF with SET
// furrtek 2022

`timescale 1ns/100ps

module FDN(
	input CK,
	input D,
	input nS,
	output reg Q,
	output nQ
);

always @(posedge CK or negedge nS) begin
	if (!nS)
		Q <= 1'b1;	// tmax = 2.9ns
	else
		Q <= D;		// tmax = 6.1ns
end

assign nQ = ~Q;

endmodule
