// 74163 counter

module m74163(
	input CEP,
	input CET,
	input CLK,
	input nLOAD,
	input nMR,
	input [3:0] D,
	output reg [3:0] Q,
	output TC
);

always @(posedge CLK) begin
    if (!nMR) begin
        Q <= 4'd0;
    end else begin
        if (!nLOAD)
            Q <= D;
        else if (CEP & CET)
            Q <= Q + 1'b1;
    end
end

assign TC = &{CET, Q};

endmodule
