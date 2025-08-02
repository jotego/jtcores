module RAM(
	input clk,
	input [9:0] addr,
	input we,
	input [7:0] din,
	output reg [7:0] dout
);

reg [7:0] data [0:1023];
reg [9:0] we_addr;

always @(posedge clk) begin
	we_addr <= addr;
	dout <= data[addr];
end

always @(*) begin
	if (we)
		data[we_addr] <= din;
end

endmodule
