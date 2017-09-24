`timescale 1ns/1ps

module jtgng_sound(
	input	clk6,	// 6   MHz
	input	clk,	// 3   MHz
	input	clk_ym, // 1.5 MHz
	input	rst,
	input	soft_rst,
	// Interface with main CPU
	input			sres_b,	// Z80 reset
	input	[7:0]	snd_latch,
	input			V32,	
	// ROM access
	output	[14:0] 	rom_addr,
	output			rom_cs,
	input	[ 7:0] 	rom_dout,
	input			snd_wait,
	// Sound output
	output 	signed [8:0] ym_mux_right,
	output 	signed [8:0] ym_mux_left,
	output 	ym_mux_sample
);

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n;

always @(negedge clk)
	reset_n <= ~( rst | soft_rst /*| ~sres_b*/ );

wire ym_cs, latch_cs, ram_cs;
reg [3:0] map_cs;

assign { rom_cs, ym_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
	casex(A[15:11])
		8'b0xxx_x: map_cs = 4'h8; // 0000-7FFF, ROM
		8'b1100_0: map_cs = 4'h1; // C000-C7FF, RAM
		8'b1100_1: map_cs = 4'h2; // C800-C8FF, Sound latch
		8'b1110_0: map_cs = 4'h4; // E000-E0FF, Yamaha
		default: map_cs = 4'h0;
	endcase


// RAM, 8kB
wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, cpu_dout;

jtgng_chram RAM(	// 2 kB, just like CHARs
	.address	( A[10:0]	),
	.clock		( clk6		),
	.data		( cpu_dout	),
	.wren		( RAM_we	),
	.q			( ram_dout	)
);

reg [7:0] cpu_din;

always @(negedge clk)
 	cpu_din <=  ({8{  ram_cs}} & ram_dout  ) | 
				({8{  rom_cs}} & rom_dout  ) |
				({8{latch_cs}} & snd_latch ) ;

	wire int_n = V32;
	wire m1_n;
	wire mreq_n;
	wire iorq_n;
	wire rfsh_n;
	wire halt_n;
	wire busak_n;
	wire busy;
	wire wait_n = !( busy || !snd_wait);

tv80s Z80 (
	.reset_n(reset_n ),
	.clk    (clk     ),
	.wait_n (wait_n	 ),
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
	.dout   (cpu_dout)
);

wire [6:0] nc;

jt12 fm(
	.rst		( ~reset_n	),
	// CPU interface
	.cpu_clk	( clk		),
	.cpu_din	( cpu_dout	),
	.cpu_addr	( A[1:0]	),
	.cpu_cs_n	( ~ym_cs	),
	.cpu_wr_n	( wr_n		),
	.cpu_limiter_en( 1'b1	),

	.cpu_dout	( { busy, nc } ),
	//output			cpu_irq_n,
	// Synthesizer clock domain
	.syn_clk	( clk_ym	),
	// combined output
	// output	signed	[11:0]	syn_snd_right,
	// output	signed	[11:0]	syn_snd_left,
	// output			syn_snd_sample,
	// multiplexed output
	.syn_mux_right	( ym_mux_right	),	
	.syn_mux_left	( ym_mux_left	),
	.syn_mux_sample	( ym_mux_sample)
);


endmodule // jtgng_sound