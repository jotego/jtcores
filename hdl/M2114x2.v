`timescale 1ns/1ps

module M2114x2(
	input [9:0] addr,
	inout [7:0] d,
	input ce_b,
	input we_b
);

reg [7:0] mem [1023:0];

reg [7:0] dread;

always @(addr)
	dread = mem[addr];


assign d = !ce_b ? dread : 8'hzz;

always @(*)
	if(!ce_b && we_b) mem[addr] = d;

endmodule // M2114x2
