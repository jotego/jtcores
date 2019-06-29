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
    Date: 29-6-2019 */

`timescale 1ns/1ps

module jtcommando_mist(
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

localparam CONF_STR = {
    //   00000000011111111112222222222333333333344444444445
    //   12345678901234567890123456789012345678901234567890
        "JTCommando;;", //8
        "O1,Pause,OFF,ON;", // 16
        "F,rom;", // 6
        "O2,Difficulty,Hard,Normal;", // 42
        "O43,Start level,8,2,4,6;", // 20
        "O65,Lives,3,2,4,5;", // 20
        "O9,Screen filter,ON,OFF;", // 24
        "OB,Flip screen,OFF,ON;", // 22
        "TF,RST ,OFF,ON;", // 15
        "V,http://patreon.com/topapate;" // 30
};

localparam CONF_STR_LEN = $size(CONF_STR)>>>3; // System verilog is only used for this line!

wire          rst, clk_sys;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire [21:0]   sdram_addr;
wire [31:0]   data_read;
wire          loop_rst;
wire          downloading;
wire [21:0]   ioctl_addr;
wire [ 7:0]   ioctl_data;
wire          ioctl_wr;
wire          coin_cnt;

wire rst_req = status[32'hf];
wire cheat_invincible = status[32'd10];
wire dip_flip = status[32'hb];

wire game_pause;
wire sdram_req;
`ifdef SIMULATION
    wire dip_pause = 1'b1; // ~status[1];
    initial if(!dip_pause) $display("INFO: DIP pause enabled");
`else
wire dip_pause = ~status[1] & ~game_pause;
`endif

`ifdef SIMULATION
    `ifdef DIP_TEST
    wire dip_test  = 1'b0;
    `else
    wire dip_test  = 1'b1;
    `endif
    initial if(!dip_test) $display("INFO: DIP test mode enabled");
`else
wire dip_test  = ~status[4];
`endif

wire dip_upright = 1'b1;
wire [1:0] dip_level  = status[4:3];
wire [1:0] dip_start  = status[6:5];
wire [2:0] dip_price1 = 2'b00;
wire [2:0] dip_price2 = 2'b11;

wire [21:0]   prog_addr;
wire [ 7:0]   prog_data;
wire [ 1:0]   prog_mask;
wire          prog_we;

wire [3:0] red;
wire [3:0] green;
wire [3:0] blue;

wire LHBL, LVBL, hs, vs;
wire [15:0] snd;

wire [9:0] game_joystick1, game_joystick2;
wire [1:0] game_coin, game_start;
wire game_rst;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;
wire refresh_en;

reg LHBL_dly;
always @(posedge clk_sys)
    if(cen6) LHBL_dly <= LHBL;

// PLL's
// 24 MHz or 12 MHz base clock
wire clk_vga_in, clk_vga, pll_locked;
jtgng_pll0 u_pll_game (
    .inclk0 ( CLOCK_27[0] ),
    .c1     ( clk_sys     ), // 48 MHz
    .c2     ( SDRAM_CLK   ),
    .c3     ( clk_vga_in  ),
    .locked ( pll_locked  )
);

jtgng_pll1 u_pll_vga (
    .inclk0 ( clk_vga_in ),
    .c0     ( clk_vga    ) // 25
);

wire [5:0] vga_r, vga_g, vga_b;
wire vga_hsync, vga_vsync;
/*
jtgng_vga u_scandoubler (
    .clk_rgb    ( clk_sys       ),
    .cen6       ( cen6          ), //  6 MHz
    .clk_vga    ( clk_vga       ), // 25 MHz
    .rst        ( rst           ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .en_mixing  ( ~status[9]    ),
    .vga_red    ( vga_r[5:1]    ),
    .vga_green  ( vga_g[5:1]    ),
    .vga_blue   ( vga_b[5:1]    ),
    .vga_hsync  ( vga_hsync     ),
    .vga_vsync  ( vga_vsync     )
);
*/
// convert 5-bit colour to 6-bit colour
assign vga_r[0] = vga_r[5];
assign vga_g[0] = vga_g[5];
assign vga_b[0] = vga_b[5];

assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;


jtframe_mist #( .CONF_STR(CONF_STR), .CONF_STR_LEN(CONF_STR_LEN),
    .SIGNED_SND(1'b1), .THREE_BUTTONS(1'b0))
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_sys        ),
    .clk_vga        ( clk_vga        ),
    .pll_locked     ( pll_locked     ),
    .status         ( status         ),
    // Base video
    .osd_rotate     ( { dip_flip, 1'b1 } ),
    .game_r         ( red            ),
    .game_g         ( green          ),
    .game_b         ( blue           ),
    .LHBL           ( LHBL_dly       ),
    .LVBL           ( LVBL           ),
    .hs             ( hs             ),
    .vs             ( vs             ),
    // VGA video (without OSD)
    .vga_r          ( vga_r          ),
    .vga_g          ( vga_g          ),
    .vga_b          ( vga_b          ),
    .vga_hsync      ( vga_hsync      ),
    .vga_vsync      ( vga_vsync      ),  
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
    .rst_n          (                ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // reset forcing signals:
    .dip_flip       ( dip_flip       ),
    .rst_req        ( rst_req        ),
    // Sound
    .snd            ( snd            ),
    .AUDIO_L        ( AUDIO_L        ),
    .AUDIO_R        ( AUDIO_R        ),
    // joystick
    .game_joystick1 ( game_joystick1 ),
    .game_joystick2 ( game_joystick2 ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_pause     ( game_pause     ),
    .game_service   (                ), // unused
    .LED            ( LED            ),
    // Debug
    .gfx_en         ( gfx_en         )
);

assign sim_vs = vs;
assign sim_hs = hs;

jtcommando_game #(.CLK_SPEED(CLK_SPEED))
u_game(
    .rst         ( game_rst      ),
    .clk         ( clk_sys       ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .red         ( red           ),
    .green       ( green         ),
    .blue        ( blue          ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),
    .HS          ( hs            ),
    .VS          ( vs            ),

    .start_button( game_start     ),
    .coin_input  ( game_coin      ),
    .joystick1   ( game_joystick1[5:0] ),
    .joystick2   ( game_joystick2[5:0] ),

    // PROM programming
    .ioctl_addr  ( ioctl_addr     ),
    .ioctl_data  ( ioctl_data     ),
    .ioctl_wr    ( ioctl_wr       ),
    .prog_addr   ( prog_addr      ),
    .prog_data   ( prog_data      ),
    .prog_mask   ( prog_mask      ),
    .prog_we     ( prog_we        ),

    // ROM load
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_req   ( sdram_req     ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .refresh_en  ( refresh_en    ),
    // DIP switches
    .dip_start   ( dip_start      ),
    .dip_pause   ( dip_pause      ),
    .dip_upright ( 2'b00          ), // upright, one joystick
    .dip_level   ( dip_level      ),
    .dip_price2  ( 2'b11          ),
    .dip_price1  ( 2'b11          ),
    .dip_flip    ( dip_flip       ),
    .dip_bonus   ( 3'b111         ),
    // sound
    .snd         ( snd            ),
    .sample      (                ),
    // Debug
    .gfx_en      ( gfx_en         )
);

endmodule // jtcommando_mist