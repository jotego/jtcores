`timescale 1ns/1ps

module jtgng_game(
	input			rst,
	input			soft_rst,
	input			clk,  	 	//   6   MHz
	input			clk_rgb,	// 6*4 = 24MHz
	output	 [3:0] 	red,
	output	 [3:0] 	green,
	output	 [3:0] 	blue,
	output			LHBL,
	output			LVBL,
	// cabinet I/O
	input	[7:0]	joystick1,
	input	[7:0]	joystick2,	
	// SDRAM interface
	input 			SDRAM_CLK, 		// SDRAM Clock 81 MHz
	inout  [15:0]  	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output      	SDRAM_nWE, 		// SDRAM Write Enable
	output      	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output      	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output      	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output        	SDRAM_CKE, 		// SDRAM Clock Enable
	// ROM load
	input			downloading,
	input	[24:0]	romload_addr,
	input	[15:0]	romload_data,
	input			romload_wr,
	// DEBUG
	input			enable_char,
	// DIP switches
	input			dip_game_mode,
	input			dip_attract_snd,
	input			dip_upright	
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
	wire [ 7:0] chram_dout,scram_dout;
	wire [15:0] chrom_data;
	wire [1:0] char_col;
	wire rom_ready;

wire [31:0] crc;

reg rst_game;
reg rst_aux;

always @(posedge clk or posedge rst or negedge rom_ready)
	if( rst || !rom_ready ) begin
		{rst_game,rst_aux} <= 2'b11;
	end
	else begin
		{rst_game,rst_aux} <= {rst_aux, downloading };
	end

jtgng_timer timers (.clk(clk),
 .rst(rst),
 .V(V),
 .H(H),
 .Hinit(Hinit),
 .LHBL(LHBL),
 .LVBL(LVBL),
 .LHBL_short(LHBL_short)
);

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

wire scr_mrdy;
wire [14:0] scr_addr;
wire [23:0] scr_dout;
wire [ 2:0] scr_col;
wire [ 2:0] scr_pal;
wire [ 2:0] HS;

jtgng_scroll scrollgen (
	.clk        ( clk      		),
	.AB         ( cpu_AB[10:0]	),
	.V128       ( V[7:0]   		),
	.H	        ( H		   		),
	.HSlow      ( HS	   		),
	.scr_cs  	( scr_cs 		),
	.scrpos_cs	( scrpos_cs		),
	.flip       ( flip     		),
	.din        ( cpu_dout 		),
	.dout       ( scram_dout	),
	.rd         ( RnW      		),
	.MRDY_b     ( scr_mrdy		),
	.scr_addr   ( scr_addr		),
	.scr_col    ( scr_col 		),
	.scr_pal    ( scr_pal    	),
	.scrom_data ( scr_dout		)
);


	wire [3:0] cc;
	wire blue_cs;
	wire redgreen_cs;
jtgng_colmix colmix (
	.rst        ( rst        	),
	.clk_rgb    ( clk_rgb    	),
	// .clk_pxl	( clk			),
	// .H			( H[2:0]		),
	// characters
	.chr_col    ( char_col   	),
	.chr_pal    ( char_pal   	),
	// scroll
	.scr_col	( scr_col		),
	.scr_pal	( scr_pal		),
	// DEBUG
	.enable_char( enable_char	),
	// CPU interface
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
	wire [16:0] main_addr;
	wire [7:0] main_dout;
	wire [15:0]	sdram_din;
	wire [12:0] wr_row;
	wire [ 8:0]	wr_col;	
	wire		main_cs;
// OBJ	
	wire [ 8:0] obj_AB;
	wire OKOUT;
	wire [7:0] main_ram;
	wire blcnten;
jtgng_main main (
	.clk      	( clk      		),
	.rst      	( rst_game 		),
	.soft_rst	( soft_rst		),
	.ch_mrdy  	( char_mrdy		),
	.scr_mrdy  	( scr_mrdy		),
	.char_dout	( chram_dout	),
	.scr_dout   ( scram_dout	),
	// bus sharing
	.ram_dout	( main_ram		),
	.obj_AB		( obj_AB		),
	.OKOUT		( OKOUT			),
	.blcnten	( blcnten		),
	.bus_req	( bus_req		),
	
	.LVBL     	( LVBL     		),
	.main_cs	( main_cs		),
	.cpu_dout 	( cpu_dout 		),
	.char_cs  	( char_cs  		),
	.scr_cs  	( scr_cs  		),
	.scrpos_cs	( scrpos_cs		),
	.blue_cs    ( blue_cs    	),
	.redgreen_cs( redgreen_cs	),
	.flip		( flip			),
	.bus_ack 	( bus_ack  		),
	.cpu_AB	 	( cpu_AB		),
	.RnW	 	( RnW			),
	.rom_addr	( main_addr 	),
	.rom_dout	( main_dout 	),
	.joystick1	( joystick1		),
	.joystick2	( joystick2		),	
	// SDRAM programming
	.sdram_din	( sdram_din		),
	.wr_row		( wr_row		),
	.wr_col		( wr_col		),
	.sdram_we	( sdram_we		),
	.crc		( crc			),	
	// DIP switches
	.dip_flip		( 1'b0		),
	.dip_game_mode	( dip_game_mode		),
	.dip_attract_snd( dip_attract_snd	),
	.dip_upright	( dip_upright		)
);


jtgng_obj obj (
	.clk	 (clk     ),
	.rst	 (rst     ),
	.AB 	 (obj_AB  ),
	.DB 	 (main_ram),
	.OKOUT   (OKOUT   ),
	.bus_req (bus_req ),
	.bus_ack (bus_ack ),
	.blen	 (blcnten ),
	.LVBL	 ( LVBL	  ),
	.HINIT	 ( Hinit  ),
	.flip	 ( flip	  ),
	.V		 ( V[7:0] )
);



	wire [14:0] snd_addr=0;
	wire [14:0] obj_addr=0;
	wire [7:0] snd_dout;
	wire [15:0] obj_dout;
jtgng_rom2 rom (
	.clk      	( SDRAM_CLK		),
	.clk_pxl	( clk			),
	.rst      	( rst      		),
	.char_addr	( char_addr		),
	.main_addr	( main_addr		),
	.snd_addr 	( snd_addr 		),
	.obj_addr 	( obj_addr 		),
	.scr_addr 	( scr_addr 		),
	.main_cs	( main_cs		),
	.snd_cs		( 1'b0			),
	.LHBL		( LHBL_short	),
	.HS			( HS			),

	.char_dout	( chrom_data	),
	.main_dout	( main_dout		),
	.snd_dout 	( snd_dout 		),
	.obj_dout 	( obj_dout 		),
	.scr_dout_pxl( scr_dout 	),
	.ready	  	( rom_ready		),
	// SDRAM programming
	.din		( sdram_din		),
	.wr_row		( wr_row		),
	.wr_col		( wr_col		),
	.we			( sdram_we		),	
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
	.SDRAM_CKE	( SDRAM_CKE		),
	// ROM load
	.downloading( downloading ),
	.romload_addr( romload_addr ),
	.romload_data( romload_data ),
	.romload_wr	( romload_wr	),
	.crc_out	( crc			)
);


endmodule // jtgng