`timescale 1ns/1ps

module jtgng_game(
	input			rst,
	input			clk_rom, 	//  81   MHz
	input			clk,  	 	//   6   MHz
	input			clk_rgb,	// 6*4 = 24MHz
	output	 [3:0] 	red,
	output	 [3:0] 	green,
	output	 [3:0] 	blue,
	output			LHBL,
	output			LVBL,
	// SDRAM interface
	inout  [15:0]  	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output      	SDRAM_nWE, 		// SDRAM Write Enable
	output      	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output      	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output      	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output 			SDRAM_CLK, 		// SDRAM Clock
	output        	SDRAM_CKE 		// SDRAM Clock Enable	
);

	wire [8:0] V;
	wire [8:0] H;
	wire Hinit;

	wire [12:0] cpu_AB;
	wire char_cs;
	wire flip;
	wire [7:0] cpu_dout, char_dout;
	wire rd;
	wire char_mrdy;
	wire [12:0] char_addr;
	wire [ 7:0] chram_dout;
	wire [15:0] chrom_data;
	wire [1:0] char_col;
	wire rom_ready;

reg rst_game;
reg rst_aux;

always @(posedge clk or posedge rst or negedge rom_ready)
	if( rst || !rom_ready ) begin
		{rst_game,rst_aux} <= 2'b11;
	end
	else begin
		{rst_game,rst_aux} <= {1'b0, rst_game};
	end

jtgng_timer timers (.clk(clk), .rst(rst), .V(V), .H(H), .Hinit(Hinit), .LHBL(LHBL), .LVBL(LVBL));

	wire RnW;
	wire [3:0] char_pal;

jtgng_char chargen (
	.clk        ( clk      		),
	.AB         ( cpu_AB[10:0]	),
	.V128       ( V[7:0]   		),
	.H128       ( H[7:0]   		),
	.char_cs    ( char_cs  		),
	.flip       ( flip     		),
	.din        ( cpu_dout 		),
	.dout       ( chram_dout	),
	.rd         ( RnW      		),
	.MRDY_b     ( char_mrdy		),
	.char_addr  ( char_addr		),
	.chrom_data ( chrom_data	),
	.char_col   ( char_col 		),
	.char_pal   ( char_pal    	)
);


	wire [3:0] cc;
	wire blue_cs;
	wire redgreen_cs;
jtgng_colmix colmix (
	.rst        ( rst        	),
	.clk_rgb    ( clk_rgb    	),
	.char       ( char_col   	),
	.cc         ( char_pal   	),
	.AB         ( cpu_AB[7:0]	),
	.blue_cs    ( blue_cs    	),
	.redgreen_cs( redgreen_cs	),
	.DB         ( cpu_dout   	),
	.LVBL       ( LVBL       	),
	.LHBL       ( LHBL       	),
	.red        ( red        	),
	.green      ( green      	),
	.blue       ( blue       	)
);


	wire bus_ack, bus_req;
	wire [17:0] main_addr;
	wire [7:0] main_dout;
jtgng_main main (
	.clk      	( clk      		),
	.rst      	( rst_game 		),
	.ch_mrdy  	( char_mrdy		),
	.char_dout	( chram_dout	),
	.LVBL     	( LVBL     		),
	.cpu_dout 	( cpu_dout 		),
	.char_cs  	( char_cs  		),
	.blue_cs    (blue_cs    	),
	.redgreen_cs(redgreen_cs	),
	.flip		( flip			),
	.bus_ack 	( bus_ack  		),
	.cpu_AB	 	( cpu_AB		),
	.RnW	 	( RnW			),
	.rom_addr	( main_addr 	),
	.rom_dout	( main_dout 	)
);


	wire [14:0] snd_addr=0;
	wire [14:0] obj_addr=0;
	wire [15:0] scr_addr=0;
	wire [7:0] snd_dout;
	wire [15:0] obj_dout;
	wire [23:0] scr_dout;
jtgng_rom rom (
	.clk      	( clk_rom  		),
	.rst      	( rst      		),
	.char_addr	( char_addr		),
	.main_addr	( main_addr		),
	.snd_addr 	( snd_addr 		),
	.obj_addr 	( obj_addr 		),
	.scr_addr 	( scr_addr 		),
	.char_dout	( chrom_data	),
	.main_dout	( main_dout		),
	.snd_dout 	( snd_dout 		),
	.obj_dout 	( obj_dout 		),
	.scr_dout 	( scr_dout 		),
	.ready	  	( rom_ready		),
	// SDRAM interface
	.SDRAM_DQ	( SDRAM_DQ		),
	.SDRAM_A	( SDRAM_A		),
	.SDRAM_DQML	( SDRAM_DQML	),
	.SDRAM_DQMH	( SDRAM_DQMH	),
	.SDRAM_nWE	( SDRAM_nWE		),
	.SDRAM_nCAS	( SDRAM_nCAS	),
	.SDRAM_nRAS	( SDRAM_nRAS	),
	.SDRAM_nCS	( SDRAM_nCS		),
	.SDRAM_BA	( SDRAM_BA		),
	.SDRAM_CLK	( SDRAM_CLK		),
	.SDRAM_CKE	( SDRAM_CKE		)
);


endmodule // jtgng