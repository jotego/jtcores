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

module jtgng_mist(
    input   [1:0]   CLOCK_27,
    output  [5:0]   VGA_R,
    output  [5:0]   VGA_G,
    output  [5:0]   VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    // SDRAM interface
    inout [15:0]    SDRAM_DQ,       // SDRAM Data bus 16 Bits
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
);

localparam CONF_STR = {
    //   000000000111111111122222222223
    //   123456789012345678901234567890
        "JTGNG;;",
        "O1,Test mode,OFF,ON;",
        "O2,Cabinet mode,OFF,ON;",
        "O3,PSG ,ON,OFF;",
        "O4,FM  ,ON,OFF;",
        "O56,Lives,3,4,5,6;",
        "O78,Difficulty,easy,normal,hard,very hard;",
        "O9,Screen filter,ON,OFF;",
        "TA,Reset;",
        "V,http://patreon.com/topapate;"
};

localparam CONF_STR_LEN = 7+20+23+15+15+ 18+42+ 24+9+30;

wire          rst, clk_rgb, clk_vga, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire          ps2_kbd_clk, ps2_kbd_data;
wire [ 5:0]   board_r, board_g, board_b;
wire          board_hsync, board_vsync, hs, vs;
wire [21:0]   sdram_addr;
wire [15:0]   data_read;
wire          loop_rst, autorefresh, H0; 
wire          downloading;
wire [24:0]   romload_addr;
wire [15:0]   romload_data;
wire          coin_cnt = 1'b0; // To do: check if GnG provided this output

wire [1:0]    dip_level = ~status[8:7];
wire [1:0]    dip_lives = ~status[6:5];
wire [1:0]    dip_bonus = 2'b11;


assign LED = ~downloading | coin_cnt | rst;

jtgng_mist_base #(.CONF_STR(CONF_STR), .CONF_STR_LEN(CONF_STR_LEN)) u_base(
    .rst            ( rst           ),
    .clk_rgb        ( clk_rgb       ),
    .clk_vga        ( clk_vga       ),
    .clk_rom        ( clk_rom       ),
    .SDRAM_CLK      ( SDRAM_CLK     ),
    .cen12          ( cen12         ),
    .H0             ( H0            ),
    // Base video
    .board_r        ( board_r       ),
    .board_g        ( board_g       ),
    .board_b        ( board_b       ),
    .board_hsync    ( board_hsync   ),
    .board_vsync    ( board_vsync   ),
    .hs             ( hs            ),
    .vs             ( vs            ),
    // VGA
    .CLOCK_27       ( CLOCK_27      ),
    .VGA_R          ( VGA_R         ),
    .VGA_G          ( VGA_G         ),
    .VGA_B          ( VGA_B         ),
    .VGA_HS         ( VGA_HS        ),
    .VGA_VS         ( VGA_VS        ),
    // SDRAM interface
    .SDRAM_DQ       ( SDRAM_DQ      ),
    .SDRAM_A        ( SDRAM_A       ),
    .SDRAM_DQML     ( SDRAM_DQML    ),
    .SDRAM_DQMH     ( SDRAM_DQMH    ),
    .SDRAM_nWE      ( SDRAM_nWE     ),
    .SDRAM_nCAS     ( SDRAM_nCAS    ),
    .SDRAM_nRAS     ( SDRAM_nRAS    ),
    .SDRAM_nCS      ( SDRAM_nCS     ),
    .SDRAM_BA       ( SDRAM_BA      ),
    .SDRAM_CKE      ( SDRAM_CKE     ),
    // SPI interface to arm io controller
    .SPI_DO         ( SPI_DO        ),
    .SPI_DI         ( SPI_DI        ),
    .SPI_SCK        ( SPI_SCK       ),
    .SPI_SS2        ( SPI_SS2       ),
    .SPI_SS3        ( SPI_SS3       ),
    .SPI_SS4        ( SPI_SS4       ),
    .CONF_DATA0     ( CONF_DATA0    ),
    // control
    .status         ( status        ), 
    .joystick1      ( joystick1     ), 
    .joystick2      ( joystick2     ),
    .ps2_kbd_clk    ( ps2_kbd_clk   ),
    .ps2_kbd_data   ( ps2_kbd_data  ),
    // ROM
    .romload_addr   ( romload_addr  ),
    .romload_data   ( romload_data  ),
    .downloading    ( downloading   ),
    .loop_rst       ( loop_rst      ),
    .autorefresh    ( autorefresh   ),
    .sdram_addr     ( sdram_addr    ),
    .data_read      ( data_read     )
);

jtgng_cen #(.CLK_SPEED(12)) u_cen(
    .clk    ( clk_rgb   ),    // 12 MHz
	.cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

wire [3:0] red;
wire [3:0] green;
wire [3:0] blue;
wire LHBL;
wire LVBL;
wire signed [15:0] ym_snd;

wire [5:0] game_joystick1, game_joystick2;
wire [1:0] game_coin, game_start;

jtgng_game game(
    .rst         ( rst           ),
    .soft_rst    ( status[10]    ),
    .clk         ( clk_rgb       ),
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
    .joystick1   ( game_joystick1 ),
    .joystick2   ( game_joystick2 ),

    // ROM load
    .downloading ( downloading   ),
    .romload_addr( romload_addr  ),
    .romload_data( romload_data  ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .H0          ( H0            ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // DEBUG
    .enable_char ( 1'b1          ),
    .enable_scr  ( 1'b1          ),
    .enable_obj  ( 1'b1          ),
    // DIP switches
    .dip_lives      ( dip_lives  ),
    .dip_level      ( dip_level  ),
    .dip_bonus      ( dip_bonus  ),
    .dip_game_mode  ( ~status[1] ),
    .dip_upright    ( status[2]  ),
    .dip_attract_snd( 1'b1       ), // 0 for sound
    // sound
    .enable_psg  ( ~status[3]    ),
    .enable_fm   ( ~status[4]    ),
    .ym_snd      ( ym_snd        ),
    .sample      (               )
);


assign AUDIO_R = AUDIO_L;

jtgng_board #(.SIGNED_SND(1'b1))u_board(
    .rst            ( rst             ),
    .clk_rgb        ( clk_rgb         ),
    .clk_dac        ( clk_rom         ),
    // audio
    .snd            ( ym_snd          ),
    .snd_pwm        ( AUDIO_L         ),
    // VGA
    .cen6           ( cen6            ),
    .clk_vga        ( clk_vga         ),
    .en_mixing      ( ~status[9]      ),    
    .game_r         ( red             ),
    .game_g         ( green           ),
    .game_b         ( blue            ),
    .LHBL           ( LHBL            ),
    .LVBL           ( LVBL            ),
    .vga_r          ( board_r         ),
    .vga_g          ( board_g         ),
    .vga_b          ( board_b         ),    
    .vga_hsync      ( board_hsync     ),
    .vga_vsync      ( board_vsync     ),
    // joystick
    .ps2_kbd_clk    ( ps2_kbd_clk     ),
    .ps2_kbd_data   ( ps2_kbd_data    ),
    .board_joystick1( joystick1[8:0]  ),
    .board_joystick2( joystick2[8:0]  ),
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
    .game_pause     ( game_pause      )
);

endmodule // jtgng_mist