`timescale 1ns/1ps

module M58725(
	input [10:0] addr,
	inout [7:0] d,
	input oe_b,
	input ce_b,
	input we_b
);

reg [7:0] mem [2047:0];

reg [7:0] dread;

always @(addr)
	dread = mem[addr];

integer i;

initial begin
	for(i=0; i<2048;i=i+1)
		mem[i] = 8'd0;

	// mem[0]=8'd72; // H
	// mem[1]=8'd79; // O
	// mem[2]=8'd76; // L
	// mem[3]=8'd65; // A
	mem[0]=8'd01; // H
	mem[1]=8'd02; // O
	mem[2]=8'd04; // L
	mem[3]=8'd08; // A

	// attributes
	mem[1024]=8'h10;
	mem[1025]=8'h20;
	mem[1026]=8'h40;
	mem[1027]=8'h80;
end

assign d = !ce_b && !oe_b ? dread : 8'hzz;

always @(*)
	if(!ce_b && we_b) mem[addr] = d;

endmodule // M58725
