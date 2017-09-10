`timescale 1ns/1ps

module jtgng_sound(
	input	clk,	// 3MHz
	input	rst,
	input	soft_rst,
	// Interface with main CPU
	input			sres_b,	// Z80 reset
	input	[7:0]	snd_latch,
	input			V32,	
	// ROM access
	output	reg [14:0] 	rom_addr,
	output				rom_cs,
	input		[ 7:0] 	rom_dout
);

wire [15:0] A;
reg reset_n;

always @(negedge clk)
	reset_n <= ~( rst | soft_rst | ~sres_b );

wire ym_cs, latch_cs, ram_cs;
reg [3:0] map_cs;

assign { rom_cs, ym_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
	casex(A[15:11])
		8'b0x_xxx: map_cs = 4'h8; // 0000-7FFF, ROM
		8'b11_000: map_cs = 4'h1; // C000-C7FF, RAM
		8'b11_001: map_cs = 4'h2; // C800-C8FF, Sound latch
		8'b11_010: map_cs = 4'h4; // E000-E0FF, Yamaha
		default: map_cs = 4'h0;
	endcase


// RAM, 8kB
wire RAM_we = ram_cs && !RnW;
wire [7:0] ram_dout;

jtgng_chram RAM(	// 2 kB, just like CHARs
	.address	( A[10:0]	),
	.clock		( clk		),
	.data		( cpu_dout	),
	.wren		( RAM_we	),
	.q			( ram_dout	)
);

reg [7:0] cpu_din;

always @(negedge clk)
 	cpu_din <=  ({8{  ram_cs}} & ram_dout  ) | 
				({8{  rom_cs}} & rom_dout  ) |
				({8{latch_cs}} & snd_latch ) ;

	wire wait_n = 1'b1;
	wire int_n = V32;
	wire m1_n;
	reg mreq_n;
	reg iorq_n;
	reg rd_n;
	reg wr_n;
	wire rfsh_n;
	wire halt_n;
	wire busak_n;
tv80s Z80 (
	.reset_n(reset_n ),
	.clk    (clk     ),
	.wait_n (wait_n  ),
	.int_n  (int_n   ),
	.nmi_n  (1'b1    ),
	.busrq_n(1'b1    ),
	.m1_n   (m1_n    ),
	.mreq_n (mreq_n  ),
	.iorq_n (iorq_n  ),
	.rd_n   (rd_n    ),
	.wr_n   (wr_n    ),
	.rfsh_n (rfsh_n  ),
	.halt_n (halt_n  ),
	.busak_n(busak_n ),
	.A      (A       ),
	.di     (cpu_din ),
	.dout   (ram_dout)
);



endmodule // jtgng_sound