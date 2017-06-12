`timescale 1ns/1ps

module jtgng_char(
	input		clk,	// 6 MHz
	input		[10:0]	AB,
	input		[7:0] V128, // V128-V1
	input		[7:0] H128, // H128-H1
	input		char_cs,
	input		flip,
	input		[7:0] din,
	output		[7:0] dout,
	input		rd,
	input		flip,
	output		MRDY_b,

	output [13:0] char_addr
);

reg [10:0]	addr;

always @(*)
	if( !sel ) begin
		addr = AB;
		we   = char_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { H[1], {10{FLIP}}^{V128[7:3],H128[7:3]}};
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

reg [7:0] aux;
reg [5:0] aux2;
reg [9:0] AC; // ADDRESS - CHARACTER
reg char_hflip_prev;
reg [3:0] char_pal;

reg [3:0] vert_addr;
reg half_addr;

wire char_vflip = dout[5] ^ flip;
wire char_hflip = dout[4] ^ flip;

always @(negedge clk)
	case( H[2:0] )
		3'd0: {char_hflip_prev, char_pal } <= aux2;
		3'd2: aux <= dout;
		3'd3, 3'd7: half_addr <= char_hflip ^ H[2];
		3'd4: begin
			AC      <= {dout[7:6], aux};
			aux2    <= dout[3:0];
			vert_addr <= {3{char_vflip}}^V128[2:0];
		end
	endcase

assign char_addr = { AC, vert_addr, half_addr };
// ROM

endmodule // jtgng_char