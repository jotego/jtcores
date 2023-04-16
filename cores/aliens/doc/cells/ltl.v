// Fujitsu AV cell
// S-R Latch with CLEAR
// furrtek 2022

`timescale 1ns/100ps

module LTL(
	input D,
	input nG,
	input nCL,
	output reg Q,
	output XQ
);

always @(*) begin
	if (!nCL) begin
		Q <= 1'b0;
	end else begin
		if (!nG)
			Q <= D;	// tmax = 2.6ns
	end
end

assign XQ = ~Q;

endmodule
