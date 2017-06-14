`timescale 1ns/1ps

module jtgng(
);

jtgng_timer jtgng_timer (.clk(), .rst(), .V(), .H(), .Hinit(), .LHBL(), .LVBL());

jtgng_char jtgng_char (
	.clk      (),
	.AB       (),
	.V128     (),
	.H128     (),
	.char_cs  (),
	.flip     (),
	.din      (),
	.dout     (),
	.rd       (),
	.MRDY_b   (),
	.char_addr(),
	.char_data(),
	.char_col ()
);



endmodule // jtgng