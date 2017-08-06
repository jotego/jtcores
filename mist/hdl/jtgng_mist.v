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
	input			CONF_DATA0
);

wire clk_rom; // 81
wire clk_gng; //  6
wire clk_rgb; // 36
wire clk_vga; // 25
wire locked;


parameter CONF_STR = {
        "JTGNG;JTGNG;"
};

parameter CONF_STR_LEN = 12;

wire downloading;
// wire [4:0] index;
wire romload_wr;
wire [24:0] romload_addr;
wire [7:0] romload_data, romload_data_prev;
data_io datain (
	.sck        (SPI_SCK      ),
	.ss         (SPI_SS2      ),
	.sdi        (SPI_DI       ),
	.downloading(downloading  ),
	// .index      (index        ),
	.clk        (SDRAM_CLK    ),
	.wr         (romload_wr   ),
	.addr       (romload_addr ),
	.data       (romload_data ),
	.data_prev  (romload_data_prev )
);

wire [7:0] joystick1, joystick2; //, joystick;

// assign joystick = joystick_0; // | joystick_1;

user_io #(.STRLEN(CONF_STR_LEN)) userio(
	.conf_str	( CONF_STR	),
	.SPI_SCK	( SPI_SCK	),
	.CONF_DATA0	( CONF_DATA0),
	.SPI_DO		( SPI_DO	),
	.SPI_DI		( SPI_DI	),
	.joystick_0	( joystick1	),
	.joystick_1	( joystick2	),
	// unused ports:
	.ps2_clk	( 1'b0		),
	.serial_strobe( 1'b0	),
	.serial_data( 8'd0		),
	.sd_lba		( 32'd0		),
	.sd_rd		( 1'b0		),
	.sd_wr		( 1'b0		),
	.sd_conf	( 1'b0		),
	.sd_sdhc	( 1'b0		),
	.sd_din		( 8'd0		)
);

wire clk24;

jtgng_pll0 clk_gen (
	.inclk0	( CLOCK_27[0] ),
	.c0		( clk_gng	), //  6
	.c1		( clk_rgb	), // 36
	.c2		( clk_rom	), // 81
	.c3		( clk24		), // 24
	.locked	( locked	)
);

jtgng_pll1 clk_gen2 (
	.inclk0	( clk24 	),
	.c0		( clk_vga	) // 25
);

// convert 4-bit colour to 6-bit colour
// 1 LSB error on codes 3 and 12, rest are exact
assign VGA_R[1:0] = VGA_R[5:4];
assign VGA_G[1:0] = VGA_G[5:4];
assign VGA_B[1:0] = VGA_B[5:4];


reg rst=1'b1;
reg [2:0] rst_aux=3'b111;

always @(posedge clk_gng)
	if(rst)
		{rst, rst_aux} <= {rst_aux,1'b0};

	wire [3:0] red;
	wire [3:0] green;
	wire [3:0] blue;
	wire LHBL;
	wire LVBL;
jtgng_game game (
	.rst    	( rst    	),
	.clk_rom	( clk_rom	),  // 81 MHz
	.clk    	( clk_gng	),  //  6 MHz
	.clk_rgb	( clk_rgb	),	// 36 MHz
	.red    	( red    	),
	.green  	( green  	),
	.blue   	( blue   	),
	.LHBL   	( LHBL   	),
	.LVBL   	( LVBL   	),

	.joystick1	(~joystick_0),
	.joystick2	(~joystick_1),

	.SDRAM_DQ	( SDRAM_DQ 	),
	.SDRAM_A	( SDRAM_A 	),
	.SDRAM_DQML	( SDRAM_DQML),
	.SDRAM_DQMH	( SDRAM_DQMH),
	.SDRAM_nWE	( SDRAM_nWE ),
	.SDRAM_nCAS	( SDRAM_nCAS),
	.SDRAM_nRAS	( SDRAM_nRAS),
	.SDRAM_nCS	( SDRAM_nCS ),
	.SDRAM_BA	( SDRAM_BA 	),
	.SDRAM_CLK	( SDRAM_CLK ),
	.SDRAM_CKE	( SDRAM_CKE ),
	// ROM load
	.downloading( downloading ),
	.romload_addr( romload_addr ),
	.romload_data( romload_data ),
	.romload_data_prev( romload_data_prev ),
	.romload_wr	( romload_wr	)
);

jtgng_vga vga_conv (
	.clk_gng  	( clk_gng		), //  6 MHz
	.clk_vga  	( clk_vga		), // 25 MHz
	.rst      	( rst			),
	.red      	( red			),
	.green    	( green			),
	.blue     	( blue			),
	.LHBL     	( LHBL			),
	.LVBL     	( LVBL			),
	.vga_red  	( VGA_R[5:2]	),
	.vga_green	( VGA_G[5:2]	),
	.vga_blue 	( VGA_B[5:2]	),
	.vga_hsync	( VGA_HS		),
	.vga_vsync	( VGA_VS		)
);


endmodule // jtgng_mist