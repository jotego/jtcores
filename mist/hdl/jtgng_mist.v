/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_mist(
	input	[1:0]	CLOCK_27,
	output	[5:0]	VGA_R,
	output	[5:0]	VGA_G,
	output	[5:0]	VGA_B,
	output			VGA_HS,
	output			VGA_VS,
	// SDRAM interface
	inout [15:0]  	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output        	SDRAM_nWE, 		// SDRAM Write Enable
	output       	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output        	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output        	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output 			SDRAM_CLK, 		// SDRAM Clock
	output        	SDRAM_CKE, 		// SDRAM Clock Enable	
   // SPI interface to arm io controller
	output			SPI_DO,
	input			SPI_DI,
	input			SPI_SCK,
	input			SPI_SS2,
	input			SPI_SS3,
	input			SPI_SS4,
	input			CONF_DATA0,
	// sound
	output			AUDIO_L,
	output			AUDIO_R
);

wire clk_gng; //  6
wire clk_rgb; // 36
wire clk_vga; // 25
wire locked;


parameter CONF_STR = {
	//	 000000000111111111122222222222
	//   123456789012345678901234567890
        "JTGNG;;",
        "O1,Test mode,OFF,ON;",
        "O2,Cabinet mode,OFF,ON;",
        "O3, SCR,ON,OFF;",
        "O4,OBJ ,ON,OFF;",
        "O5,Screen filter,ON,OFF;",
        "T6,Reset;",
        "V,v0.1;"
};

parameter CONF_STR_LEN = 7+20+23+15+15+24+9+7;

reg rst = 1'b1;

wire downloading;
// wire [4:0] index;
wire romload_wr;
wire [24:0] romload_addr;
wire [15:0] romload_data;
data_io datain (
	.sck        		( SPI_SCK      ),
	.ss         		( SPI_SS2      ),
	.sdi        		( SPI_DI       ),
	// .index      (index        ),
	.rst				( rst		   ),
	.clk_sdram  		( SDRAM_CLK    ),
	.downloading_sdram	( downloading  ),
	.wr_sdram   		( romload_wr   ),
	.addr_sdram 		( romload_addr ),
	.data_sdram 		( romload_data )
);

wire [7:0] status, joystick1, joystick2; //, joystick;

// assign joystick = joystick_0; // | joystick_1;

user_io #(.STRLEN(CONF_STR_LEN)) userio(
	.conf_str	( CONF_STR	),
	.SPI_SCK	( SPI_SCK	),
	.CONF_DATA0	( CONF_DATA0),
	.SPI_DO		( SPI_DO		),
	.SPI_DI		( SPI_DI		),
	.joystick_0	( joystick2	),
	.joystick_1	( joystick1	),
	.status		( status		),
	// unused ports:
	.ps2_clk		( 1'b0		),
	.serial_strobe( 1'b0	),
	.serial_data( 8'd0		),
	.sd_lba		( 32'd0		),
	.sd_rd		( 1'b0		),
	.sd_wr		( 1'b0		),
	.sd_conf		( 1'b0		),
	.sd_sdhc		( 1'b0		),
	.sd_din		( 8'd0		)
);

wire clk24;

jtgng_pll0 clk_gen (
	.inclk0	( CLOCK_27[0] ),
	.c0		( clk_gng	), //  6
	.c1		( clk_rgb	), // 24
	.c2		( SDRAM_CLK	), // 81
	.c3		( clk24		), // 24
	.locked	( locked		)
);

jtgng_pll1 clk_gen2 (
	.inclk0	( clk24 		),
	.c0		( clk_vga	) // 25
);

reg [2:0] rst_aux=3'b111;

always @(posedge clk_gng)
	/*if( status[5]) begin
		rst		<= 1'b1;
		rst_aux <= 3'b111;
	end
	else*/ {rst, rst_aux} <= {rst_aux,1'b0};

reg cen6;

reg [1:0] cen_cnt;
always @(posedge clk)
    if( rst )
        cen_cnt <= 2'b0;
    else
        cen_cnt <= cen_cnt+2'b1;

always @(negedge clk)
    cen6  <= cen_cnt==2'b0; // 6MHz clock divider


	wire [3:0] red;
	wire [3:0] green;
	wire [3:0] blue;
	wire LHBL;
	wire LVBL;
	wire signed [15:0] ym_snd;
	wire ym_mux_sample;
jtgng_game game (
	.rst    	( rst    	),
	.soft_rst	( status[6]	),
	.SDRAM_CLK	( SDRAM_CLK	),  // 81   MHz
	.clk    	( clk_gng	),  //  6   MHz
    .cen6       ( cen6      ),
	.red    	( red    	),
	.green  	( green  	),
	.blue   	( blue   	),
	.LHBL   	( LHBL   	),
	.LVBL   	( LVBL   	),

	.joystick1	(~joystick1	),
	.joystick2	(~joystick2	),

	.SDRAM_DQ	( SDRAM_DQ 	),
	.SDRAM_A	( SDRAM_A 	),
	.SDRAM_DQML	( SDRAM_DQML),
	.SDRAM_DQMH	( SDRAM_DQMH),
	.SDRAM_nWE	( SDRAM_nWE ),
	.SDRAM_nCAS	( SDRAM_nCAS),
	.SDRAM_nRAS	( SDRAM_nRAS),
	.SDRAM_nCS	( SDRAM_nCS ),
	.SDRAM_BA	( SDRAM_BA 	),
	.SDRAM_CKE	( SDRAM_CKE ),
	// ROM load
	.downloading( downloading ),
	.romload_addr( romload_addr ),
	.romload_data( romload_data ),
	.romload_wr	( romload_wr	),
	// DEBUG
	.enable_char( ~status[3]		),
	.enable_scr	( ~status[3]		),
	.enable_obj ( ~status[4]		),
	// DIP switches
	.dip_game_mode	( ~status[1]	),
	.dip_upright	( status[2]	),
	//.dip_flip		( ~status[3]),
	.dip_attract_snd( 1'b1			),
	// sound
	.ym_snd		( ym_snd		)
);

wire clk_dac = SDRAM_CLK;
assign AUDIO_R = AUDIO_L;

jt12_dac2 #(.width(16)) dac2_left (.clk(clk_dac), .rst(rst), .din(ym_snd), .dout(AUDIO_L));


wire [5:0] GNG_R, GNG_G, GNG_B;

// convert 5-bit colour to 6-bit colour
assign GNG_R[0] = GNG_R[5];
assign GNG_G[0] = GNG_G[5];
assign GNG_B[0] = GNG_B[5];

wire vga_hsync, vga_vsync;

jtgng_vga vga_conv (
	.clk_gng  	( clk_gng		), //  6 MHz
	.clk_vga  	( clk_vga		), // 25 MHz
	.rst      	( rst			),
	.red      	( red			),
	.green    	( green			),
	.blue     	( blue			),
	.LHBL     	( LHBL			),
	.LVBL     	( LVBL			),
	.en_mixing	( ~status[5]	),
	.vga_red  	( GNG_R[5:1]	),
	.vga_green	( GNG_G[5:1]	),
	.vga_blue 	( GNG_B[5:1]	),
	.vga_hsync	( vga_hsync		),
	.vga_vsync	( vga_vsync		)
);

// include the on screen display
osd #(0,0,4) osd (
   .pclk       ( clk_vga	  ),

   // spi for OSD
   .sdi        ( SPI_DI       ),
   .sck        ( SPI_SCK      ),
   .ss         ( SPI_SS3      ),

   .red_in     ( GNG_R		),
   .green_in   ( GNG_G		),
   .blue_in    ( GNG_B		),
   .hs_in      ( vga_hsync	),
   .vs_in      ( vga_vsync	),

   .red_out    ( VGA_R        ),
   .green_out  ( VGA_G        ),
   .blue_out   ( VGA_B        ),
   .hs_out     ( VGA_HS       ),
   .vs_out     ( VGA_VS       )
);

endmodule // jtgng_mist