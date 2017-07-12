`timescale 1ns/1ps

module jtgng_vga_test;

initial begin
	$dumpfile("test.lxt");
	$dumpvars;
	$dumpon;
	#(50*1000*1000) $finish;
end

reg clk_gng;
reg clk_vga;
reg rst;

initial begin
	rst = 0;
	#10 rst=1;
	#200 rst = 0;
end

initial begin
	clk_vga = 1'b0;
	forever #20 clk_vga = ~clk_vga; // 25MHz
end

initial begin
	clk_gng = 1'b0;
	forever #83.333 clk_gng = ~clk_gng; // 25MHz
end

wire [3:0] red		=4'd0;
wire [3:0] green	=4'd0;
wire [3:0] blue		=4'd0;
wire [3:0] vga_red;
wire [3:0] vga_green;
wire [3:0] vga_blue;

`define SIM_SYNCONLY


wire [8:0] V;
wire [8:0] H;

jtgng_timer timer (
	.clk  (clk_gng),
	.rst  (rst    ),
	.V    (V      ),
	.H    (H      ),
	.Hinit(Hinit  ),
	.LHBL (LHBL   ),
	.LVBL (LVBL   ),
	.G4_3H(G4_3H  ),
	.G4H  (G4H    ),
	.OH   (OH     )
);


jtgng_vga UUT (
	.clk_gng  (clk_gng  ),
	.clk_vga  (clk_vga  ),
	.rst      (rst      ),
	.red      (red      ),
	.green    (green    ),
	.blue     (blue     ),
	.Hinit    (Hinit    ),
	.LHBL     (LHBL     ),
	.LVBL     (LVBL     ),
	.vga_red  (vga_red  ),
	.vga_green(vga_green),
	.vga_blue (vga_blue ),
	.vga_hsync(vga_hsync),
	.vga_vsync(vga_vsync)
);


endmodule // jtgng_vga_test