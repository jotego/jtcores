`timescale 1ns/1ns

// 2kByte SRAM

module M58725(
	input we_b,
	input oe_b,
	input ce_b
	input [10:0] addr,
	inout [7:0] d
);
	
	reg [7:0] mem[2047:0];
	
	assign d = !ce_b && !oe_b && we_b ? mem[addr] : 8'hzz; 

	always @(*)
		if( !ce_b && !we_b ) mem[addr] = d;

endmodule // M58725
