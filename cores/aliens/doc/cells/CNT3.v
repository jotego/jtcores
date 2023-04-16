module CNT3(
	input CLK,
	input RESET,
	input nLOAD, CEN1, CEN2,
	input [4:0] D,
	output reg [4:0] Q
);

always @(posedge CLK or posedge RESET) begin
	if (RESET) begin
		Q <= 5'd0;
	end else begin
		if (!nLOAD)
			Q <= D;
		else
			if (CEN1 & CEN2) Q <= Q + 1'b1;
	end
end

endmodule
