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
    Date: 8-2-2019 */

`default_nettype wire

module jtbiocom_zxdos(
    input wire        CLOCK_50,
   // 6-bit output (add-on)
    output wire [5:0]  VGA_R,
    output wire [5:0]  VGA_G,
    output wire [5:0]  VGA_B,
    output wire        VGA_HS,
    output wire       VGA_VS,
   // Composite output
    //output wire       STDN,
   // SRAM interface
     output [20:0] sram_addr,
     inout  [7:0]  sram_data,
     output sram_we_n,
   // SDRAM interface
    inout wire [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output wire[12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output wire         SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output wire         SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output wire         SDRAM_nWE,      // SDRAM Write Enable
    output wire         SDRAM_nCAS,     // SDRAM Column Address Strobe
    output wire         SDRAM_nRAS,     // SDRAM Row Address Strobe
    output wire          SDRAM_nCS,      // SDRAM Chip Select
    output wire [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output wire     SDRAM_CLK,      // SDRAM Clock
    output wire         SDRAM_CKE,      // SDRAM Clock Enable
	// SPI interface to SD
	 output wire         SD_CS_N,
	 output wire         SD_CLK,
	 output wire         SD_MOSI,
	 input  wire         SD_MISO,
    // sound
     output wire         AUDIO_L,
     output wire         AUDIO_R,
   // keyboard
    inout wire        PS2_CLK,
    inout wire        PS2_DATA,
    output wire       [1:0] LED,                    
	 input wire		[1:0] BTN,
   // joystick
    output wire       JOY_CLK,
    output wire        JOY_LOAD,
    input wire        JOY_DATA
);

localparam CLK_SPEED=48;

wire          rst, rst_n, clk_sys, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire [21:0]   sdram_addr;
wire [31:0]   data_read;
wire          loop_rst;
wire          downloading;
wire [21:0]   ioctl_addr;
wire [ 7:0]   ioctl_dout;
wire          ioctl_wr;

wire rst_req = status[0];

wire sdram_req;

wire [21:0]   prog_addr;
wire [ 7:0]   prog_data;
wire [ 1:0]   prog_mask;
wire          prog_we;

wire [3:0] red;
wire [3:0] green;
wire [3:0] blue;

wire LHBL, LHBL_dly, LVBL, LVBL_dly, hs, vs;
wire [15:0] snd_right, snd_left;

`ifndef STEREO_GAME
assign snd_right = snd_left;
`endif

wire [9:0] game_joy1, game_joy2;
wire [1:0] game_coin, game_start;
wire game_rst;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;
wire refresh_en;
wire clk_vga, pll_locked;
wire CLKFB_OUT;
jtgng_pll u_pll(
    .inclk0    ( CLOCK_50  ),
    .c1        ( clk_rom   ), // 48 MHz
	 .c2        ( SDRAM_CLK ),	// 48 MHz 6944 PS 120 Degree
    .c3        ( clk_vga   ), // 25 Mhz
    .locked     ( pll_locked   )//,
    //.CLKFB_IN   ( 1'b0      )
	 );

assign clk_sys   = clk_rom;

wire [7:0] dipsw_a, dipsw_b;
wire [1:0] dip_fxlevel;
wire       enable_fm, enable_psg;
wire       dip_pause, dip_flip, dip_test;

assign sram_we_n = 1'b1; //Lectura
assign sram_addr = 21'h008FD5; 
wire [1:0]videoconf = sram_data[1:0];

jtframe_zxdos u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_rom        ),
    .clk_vga        ( clk_vga        ),
    .pll_locked     ( pll_locked     ),
    .status         ( status         ),
    // Base video
    .game_r         ( red            ),
    .game_g         ( green          ),
    .game_b         ( blue           ),
    .LHBL           ( LHBL_dly       ),
    .LVBL           ( LVBL_dly       ),
    .hs             ( hs             ),
    .vs             ( vs             ),
    .pxl_cen        ( cen6           ),
    .pxl2_cen       ( cen12          ),
    // MiST VGA pins
    .VGA_R          ( VGA_R          ),
    .VGA_G          ( VGA_G          ),
    .VGA_B          ( VGA_B          ),
    .VGA_HS         ( VGA_HS         ),
    .VGA_VS         ( VGA_VS         ),
    // SDRAM interface
    .SDRAM_CLK      ( SDRAM_CLK      ),
    .SDRAM_DQ       ( SDRAM_DQ       ),
    .SDRAM_A        ( SDRAM_A        ),
    .SDRAM_DQML     ( SDRAM_DQML     ),
    .SDRAM_DQMH     ( SDRAM_DQMH     ),
    .SDRAM_nWE      ( SDRAM_nWE      ),
    .SDRAM_nCAS     ( SDRAM_nCAS     ),
    .SDRAM_nRAS     ( SDRAM_nRAS     ),
    .SDRAM_nCS      ( SDRAM_nCS      ),
    .SDRAM_BA       ( SDRAM_BA       ),
    .SDRAM_CKE      ( SDRAM_CKE      ),
    // SPI interface to zpu io controller
    .SD_CS_N        ( SD_CS_N        ),
    .SD_CLK         ( SD_CLK         ),
    .SD_MOSI        ( SD_MOSI        ),
    .SD_MISO        ( SD_MISO        ),
    // ROM
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_dout     ( ioctl_dout     ),
    .ioctl_wr       ( ioctl_wr       ),
    .prog_addr      ( prog_addr      ),
    .prog_data      ( prog_data      ),
    .prog_mask      ( prog_mask      ),
    .prog_we        ( prog_we        ),
    .downloading    ( downloading    ),
    // ROM access from game
    .loop_rst       ( loop_rst       ),
    .sdram_addr     ( sdram_addr     ),
    .sdram_req      ( sdram_req      ),
    .sdram_ack      ( sdram_ack      ),
    .data_read      ( data_read      ),
    .data_rdy       ( data_rdy       ),
    .refresh_en     ( refresh_en     ),
//////////// board
    .rst            ( rst            ),
    .rst_n          ( rst_n          ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // reset forcing signals:
    .rst_req        ( rst_req        ),
    // Sound
	 .snd_left       ( snd_left       ),
    .snd_right      ( snd_right      ),
    .AUDIO_L        ( AUDIO_L        ),
    .AUDIO_R        ( AUDIO_R        ),
    // joystick
    .game_joystick1 ( game_joy1      ),
    .game_joystick2 ( game_joy2      ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_service   (                ), // unused
	 //Leds y Botones
    .LED            ( LED            ),
	 .BTN            ( BTN            ),
	 //Keyboard y Joy (Entradas)
    .PS2_CLK         ( PS2_CLK       ),
    .PS2_DATA        ( PS2_DATA      ),
	 .JOY_CLK         ( JOY_CLK       ),
    .JOY_LOAD        ( JOY_LOAD      ),
    .JOY_DATA        ( JOY_DATA      ),
	 .VIDEOCONF       ( VIDEOCONF     ),	 
    // DIP and OSD settings
    .enable_fm      ( enable_fm      ),
    .enable_psg     ( enable_psg     ),
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    // Debug
    .gfx_en         ( gfx_en         )
);

jtbiocom_game #(.CLK_SPEED(CLK_SPEED))
u_game(
    .rst         ( game_rst       ),
    .clk         ( clk_sys        ),
    .cen12       ( cen12          ),
    .cen6        ( cen6           ),
    .cen3        ( cen3           ),
    .cen1p5      ( cen1p5         ),
    .red         ( red            ),
    .green       ( green          ),
    .blue        ( blue           ),
    .LHBL        ( LHBL           ),
    .LVBL        ( LVBL           ),
    .LHBL_dly    ( LHBL_dly       ),
    .LVBL_dly    ( LVBL_dly       ),
    .HS          ( hs             ),
    .VS          ( vs             ),

    .start_button( game_start     ),
    .coin_input  ( game_coin      ),
    .joystick1   ( game_joy1[6:0] ),
    .joystick2   ( game_joy2[6:0] ),

    // Sound control
    .enable_fm   ( enable_fm      ),
    .enable_psg  ( enable_psg     ),
    // PROM programming
    .ioctl_addr  ( ioctl_addr     ),
    .ioctl_dout  ( ioctl_dout     ),
    .ioctl_wr    ( ioctl_wr       ),
    .prog_addr   ( prog_addr      ),
    .prog_data   ( prog_data      ),
    .prog_mask   ( prog_mask      ),
    .prog_we     ( prog_we        ),

    // ROM load
    .downloading ( downloading    ),
    .loop_rst    ( loop_rst       ),
    .sdram_req   ( sdram_req      ),
    .sdram_addr  ( sdram_addr     ),
    .data_read   ( data_read      ),
    .sdram_ack   ( sdram_ack      ),
    .data_rdy    ( data_rdy       ),
    .refresh_en  ( refresh_en     ),

    // DIP switches
    .status      ( status         ),
    .dip_pause   ( dip_pause      ),
    .dip_flip    ( dip_flip       ),
    .dip_test    ( dip_test       ),
    .dip_fxlevel ( dip_fxlevel    ),  

    // sound
    `ifndef STEREO_GAME
    .snd         ( snd_left       ),
    `else
    .snd_left    ( snd_left       ),
    .snd_right   ( snd_right      ),
    `endif
    .sample      (                ),
    // Debug
    .gfx_en      ( gfx_en         )
);

endmodule