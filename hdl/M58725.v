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

`ifdef CHAR_TEST
integer i,j,k,c=0;
initial begin
	for(j=0;j<32;j=j+1)
	for(i=0; i<32;i=i+1) begin
		k = i+(j<<5);
		c = (i&32'hf)+(j<<4);
		mem[k] = c;
		mem[k+1024] = 8'h10 | ( (c>>8) & 8'b11);
	end
end
`else 
integer j;
initial 
	for(j=0;j<1024;j=j+1) begin
		mem[j]=j;
		mem[j+1024]=8'b11;
	end
`endif

assign d = !ce_b && !oe_b ? dread : 8'hzz;

always @(*)
	if(!ce_b && we_b) mem[addr] = d;

endmodule // M58725
