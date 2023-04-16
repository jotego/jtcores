// Fujitsu AV cell
// 4-bit Binary Synchronous Up Counter
// furrtek 2022

`timescale 1ns/100ps

module C43(
	input CK,
	input [3:0] D,
	input nL, EN, CI, nCL,
	output reg [3:0] Q = 4'd0,
	output CO
);

wire CL = ~nCL;

always @(posedge CK or posedge CL) begin
	if (CL) begin
		Q <= 4'd0;			// Clear tmax = 9.7ns
	end else begin
		if (!nL)
			Q <= D;			// Load
		else if (EN & CI)
			Q <= Q + 1'b1;	// Count tmax = 13.4ns
		else
			Q <= Q;
	end
end

assign CO = &{Q[3:0], CI};

endmodule
