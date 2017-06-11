`timescale 1ns/1ps

module jtgng_char(
	input		clk,	// 6 MHz
	input		[10:0]	AB,
	input		[4:0] V128, // V128-V8
	input		[7:0] H128, // H128-H1
	input		char_cs,
	input		[7:0] din,
	output		[7:0] dout,
	input		rd,
	input		flip,
	output		MRDY_b,
);

reg [10:0]	addr;

always @(*)
	if( !sel ) begin
		addr = AB;
		we   = char_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { H[1], {10{FLIP}}^{V128,H128[7:3]}};
	end

// RAM
jtgng_m9k #(.addrw(11)) RAM(
	.clk ( clk  ),
	.addr( addr ),
	.din ( din  ),
	.dout( dout ),
	.we  ( we   )
);

assign MRDY_b = !( char_cs && ( &H[2:1]==1'b0 ) );

endmodule // jtgng_char