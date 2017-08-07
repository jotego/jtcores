`timescale 1ns/1ps

module jtgng_scroll(
	input		clk,	// 6 MHz
	input	[10:0]	AB,
	input	[ 7:0] V128, // V128-V1
	input	[ 7:0] H128, // H128-H1
	input		scr_cs,
	input		flip,
	input	[7:0] din,
	output	[7:0] dout,
	input		rd,
	output		MRDY_b

	// ROM
	/*
	output reg [12:0] char_addr,
	input  [15:0] chrom_data,
	output reg [3:0] char_pal,
	output reg [ 1:0] char_col*/
);

reg [10:0]	addr;
wire sel = ~H128[2];
reg	we;

always @(*)
	if( !sel ) begin
		addr = AB;
		we   = scr_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { H128[1], {10{flip}}^{V128[7:3],H128[7:3]}};
	end

jtgng_chram	RAM(
	.address( addr 	),
	.clock	( clk 	),
	.data	( din	),
	.wren	( we	),
	.q		( dout	)
);

assign MRDY_b = !( scr_cs && ( &H128[2:1]==1'b0 ) );

endmodule // jtgng_char