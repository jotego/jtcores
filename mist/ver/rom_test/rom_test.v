`timescale 1ns/1ps

module rom_test;

	reg clk;
	reg rst;
	reg [13:0] char_addr;
	reg [17:0] main_addr;
	reg [14:0] snd_addr;
	reg [14:0] obj_addr;
	reg [15:0] scr_addr;

	wire [7:0] char_dout;
	wire [7:0] main_dout;
	wire [7:0] snd_dout;
	wire [15:0] obj_dout;
	wire [23:0] scr_dout;

initial begin
	clk = 1'b0;
	forever #6 clk=~clk;
end

initial begin
	rst = 1'b0;
	char_addr  = 0;
	main_addr  = 0;
	snd_addr   = 0;
	obj_addr   = 0;
	scr_addr   = 0;
	#10 rst=1'b1;
	#100 rst=1'b0;
end

initial begin
	$display("DUMP ON");
	$dumpfile("test.lxt");
	$dumpvars;
	$dumpon;
end

initial #(12*11*100+200*1000) $finish;

jtgng_rom uut (
	.clk      (clk      ),
	.rst      (rst      ),
	.char_addr(char_addr),
	.main_addr(main_addr),
	.snd_addr (snd_addr ),
	.obj_addr (obj_addr ),
	.scr_addr (scr_addr ),
	.char_dout(char_dout),
	.main_dout(main_dout),
	.snd_dout (snd_dout ),
	.obj_dout (obj_dout ),
	.scr_dout (scr_dout )
);


endmodule