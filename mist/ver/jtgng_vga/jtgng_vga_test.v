`timescale 1ns/1ps

module jtgng_vga_test;

initial begin
	$dumpfile("test.lxt");
	`ifndef SIMPLL
	$dumpvars;
	`else 
	//$dumpvars;
	$dumpvars(0,UUT);
	$dumpvars(0,timer);
	$dumpvars(0,clk_rom);
	$dumpvars(0,clk_rgb);
	`endif
	$dumpon;
	//#(50*1000*1000) $finish;	
	#(4*1000*1000) $finish;	
end

reg rst;

initial begin
	rst = 0;
	#10 rst=1;
	#800 rst = 0;
end

`ifndef SIMPLL
reg clk_gng;
reg clk_vga;

initial begin
	clk_vga = 1'b0;
	//forever #20 clk_vga = ~clk_vga; // 25MHz
	forever #20.063 clk_vga = ~clk_vga; // 25MHz
end

initial begin
	clk_gng = 1'b0;
	forever #83.340 clk_gng = ~clk_gng; // 6MHz
end
`else
reg clk27;
wire clk_rom; // 81
wire clk_gng; //  6
wire clk_rgb; // 36
wire clk_vga; // 25
wire locked;

initial begin
	clk27 = 1'b0;
	forever #18.52 clk27 = ~clk27; // 27MHz
end

jtgng_pll0 clk_gen (
	.inclk0	( clk27 	),
	.c0		( clk_gng	), //  6
	.c1		( clk_rgb	), // 36
	.c2		( clk_rom	), // 81
	.c3		( clk_vga	), // 24.923, would prefer 25.0!!
	.locked	( locked	)
);
`endif
reg [3:0] red, green, blue;
wire [4:0] vga_red;
wire [4:0] vga_green;
wire [4:0] vga_blue;

always @(posedge clk_gng) begin
	red   <= $random%16;
	green <= $random%16;
	blue  <= $random%16;
end

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
	.LHBL     (LHBL     ),
	.LVBL     (LVBL     ),
	.vga_red  (vga_red  ),
	.vga_green(vga_green),
	.vga_blue (vga_blue ),
	.vga_hsync(vga_hsync),
	.vga_vsync(vga_vsync)
);


endmodule // jtgng_vga_test