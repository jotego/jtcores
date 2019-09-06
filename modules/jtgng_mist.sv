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
    Date: 22-2-2019 */

`timescale 1ns/1ps

// This is the MiST top level
// It will instantiate the appropriate game core according
// to the macro GAMETOP
// It will get the config string for the microcontroller
// from the include file conf_str.v

module `MISTTOP(
    input   [1:0]   CLOCK_27,
    output  [5:0]   VGA_R,
    output  [5:0]   VGA_G,
    output  [5:0]   VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    // SDRAM interface
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable
   // SPI interface to arm io controller
    output          SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // sound
    output          AUDIO_L,
    output          AUDIO_R,
    // user LED
    output          LED
    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vs,
    output          sim_hs
    `endif
);

localparam CLK_SPEED=48;

`ifdef SIMULATION
localparam CONF_STR="JTGNG;;";
`else
// Config string
`define SEPARATOR "",
`include "conf_str.v"

localparam CONF_STR = {
    `CORENAME,";;",
    "O1,Credits,OFF,ON;",
    `SEPARATOR
    // Common MiSTer options
    "F,rom;",
    //"O2,Aspect Ratio,Original,Wide;",
    `ifdef VERTICAL_SCREEN
    "OD,Rotate controls,No,Yes;",
    "OC,Flip screen,OFF,ON;",
    `endif
    `ifdef MISTER_VIDEO_MIXER
    "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    `else
        //`ifdef JTFRAME_VGA
    "O9,Screen filter,ON,OFF;",
        //`endif
    `endif
    `ifdef HAS_TESTMODE
    "O6,Test mode,OFF,ON;",
    `endif
    "O7,PSG,ON,OFF;",
    `ifdef JT12
    "O8,FM ,ON,OFF;",
    "OAB,FX volume, high, very high, very low, low;",
    `endif
    `SEPARATOR
    `CORE_OSD
    "T0,RST;",
    "V,patreon.com/topapate;"
};

`undef SEPARATOR`endif

wire          rst, rst_n, clk_sys, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire [21:0]   sdram_addr;
wire [31:0]   data_read;
wire          loop_rst;
wire          downloading;
wire [21:0]   ioctl_addr;
wire [ 7:0]   ioctl_data;
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
wire [15:0] snd;

wire [9:0] game_joy1, game_joy2;
wire [1:0] game_coin, game_start;
wire game_rst;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;
wire refresh_en;


// PLL's
// 24 MHz or 12 MHz base clock
wire clk_vga_in, clk_vga, pll_locked;
jtgng_pll0 u_pll_game (
    .inclk0 ( CLOCK_27[0] ),
    .c1     ( clk_rom     ), // 48 MHz
    .c2     ( SDRAM_CLK   ),
    .c3     ( clk_vga_in  ),
    .locked ( pll_locked  )
);

// assign SDRAM_CLK = clk_rom;
assign clk_sys   = clk_rom;

jtgng_pll1 u_pll_vga (
    .inclk0 ( clk_vga_in ),
    .c0     ( clk_vga    ) // 25
);

wire [7:0] dipsw_a, dipsw_b;
wire [1:0] dip_fxlevel;
wire       enable_fm, enable_psg;
wire       dip_pause, dip_flip, dip_test;

`ifdef SIMULATION
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
assign sim_vs = ~LVBL_dly;
assign sim_hs = ~LHBL_dly;
`endif


jtframe_mist #( .CONF_STR(CONF_STR),
    .SIGNED_SND(1'b1), .THREE_BUTTONS(1'b1))
u_frame(
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
    // SPI interface to arm io controller
    .SPI_DO         ( SPI_DO         ),
    .SPI_DI         ( SPI_DI         ),
    .SPI_SCK        ( SPI_SCK        ),
    .SPI_SS2        ( SPI_SS2        ),
    .SPI_SS3        ( SPI_SS3        ),
    .SPI_SS4        ( SPI_SS4        ),
    .CONF_DATA0     ( CONF_DATA0     ),
    // ROM
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_data     ( ioctl_data     ),
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
    .snd            ( snd            ),
    .AUDIO_L        ( AUDIO_L        ),
    .AUDIO_R        ( AUDIO_R        ),
    // joystick
    .game_joystick1 ( game_joy1      ),
    .game_joystick2 ( game_joy2      ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_service   (                ), // unused
    .LED            ( LED            ),
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

`ifdef SIMULATION
`ifdef TESTINPUTS
    test_inputs u_test_inputs(
        .loop_rst       ( loop_rst       ),
        .LVBL           ( LVBL           ),
        .game_joystick1 ( game_joy1[6:0] ),
        .button_1p      ( game_start[0]  ),
        .coin_left      ( game_coin[0]   )
    );
    assign game_start[1] = 1'b1;
    assign game_coin[1]  = 1'b1;
    assign game_joystick2 = ~10'd0;
    assign game_joystick1[9:7] = 3'b111;
    assign sim_vs = vs;
    assign sim_hs = hs;
`endif
`endif

`GAMETOP #(.CLK_SPEED(CLK_SPEED))
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
    .ioctl_data  ( ioctl_data     ),
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
    .snd         ( snd            ),
    .sample      (                ),
    // Debug
    .gfx_en      ( gfx_en         )
);

endmodule