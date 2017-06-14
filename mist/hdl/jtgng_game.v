`timescale 1ns/1ps

module jtgng_game(
);

	wire rst;
	wire [8:0] V;
	wire [8:0] H;
	wire Hinit;
	wire LHBL;
	wire LVBL;

	wire clk;
	wire [10:0] AB;
	wire char_cs;
	wire flip;
	wire [7:0] din;
	wire [7:0] ch_dout;
	wire rd;
	wire MRDY_b;
	wire [13:0] char_addr;
	wire [7:0] char_data;
	reg [1:0] char_col;

jtgng_char chargen (
	.clk      (clk      ),
	.AB       (AB       ),
	.V128     (V[7:0]   ),
	.H128     (H[7:0]   ),
	.char_cs  (char_cs  ),
	.flip     (flip     ),
	.din      (din      ),
	.dout     (ch_dout  ),
	.rd       (rd       ),
	.MRDY_b   (MRDY_b   ),
	.char_addr(char_addr),
	.char_data(char_data),
	.char_col (char_col )
);

jtgng_timer timers (.clk(clk), .rst(rst), .V(V), .H(H), .Hinit(Hinit), .LHBL(LHBL), .LVBL(LVBL));




endmodule // jtgng