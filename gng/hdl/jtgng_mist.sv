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
    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vs,
    output          sim_hs
    `endif       
);

parameter CLK_SPEED=48;

localparam CONF_STR = {
    //   000000000111111111122222222223
    //   123456789012345678901234567890
        "JTGNG;;", // 7
        "O1,Pause,OFF,ON;", // 16
        "F,rom;", // 6
        "O23,Difficulty,easy,normal,hard,very hard;", // 42
        "O4,Test mode,OFF,ON;", // 20
        "O7,PSG ,ON,OFF;", // 15
        "O8,FM  ,ON,OFF;", // 15
        "O9A,Lives,3,4,5,6;", // 18
        "OB,Screen filter,ON,OFF;", // 24
        "TF,Reset;", // 9
        "V,http://patreon.com/topapate;" // 30
};

localparam CONF_STR_LEN = $size(CONF_STR)>>>3; // System verilog is only used for this line!

wire          rst, clk_sys, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire          ps2_kbd_clk, ps2_kbd_data;
wire [ 5:0]   board_r, board_g, board_b;
wire          board_hsync, board_vsync, hs, vs;
wire [21:0]   sdram_addr;
wire [31:0]   data_read;
wire          loop_rst, autorefresh, H0;
wire          downloading;
wire [21:0]   ioctl_addr;
wire [ 7:0]   ioctl_data;
wire          coin_cnt = 1'b0; // To do: check if GnG provided this output

wire          game_pause;
wire          rst_req   = status[32'hf];
wire [1:0]    dip_level = ~status[3:2];
wire [1:0]    dip_lives = ~status[10:9];
wire [1:0]    dip_bonus = 2'b11;
wire          dip_pause = !(status[1] | game_pause); // DIPs are active low
wire          dip_test  = ~status[4];
wire          enable_psg = ~status[7], enable_fm = ~status[8];
wire          en_mixing = ~status['hb];


wire LHBL, LVBL;
wire signed [15:0] snd;

wire [9:0] game_joystick1, game_joystick2;
wire [1:0] game_coin, game_start;
wire game_rst;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;
wire refresh_en;

reg  [21:0]   prog_addr;
reg  [ 7:0]   prog_data;
reg  [ 1:0]   prog_mask;
reg           prog_we = 1'b0;
wire          ioctl_wr;

always @(posedge clk_rom) begin
    if ( ioctl_wr ) begin
        prog_addr <= { 1'b0, ioctl_addr[21:1] };
        prog_data <= ioctl_data;
        prog_mask <= { ioctl_addr[0], ~ioctl_addr[0] };
        prog_we   <= 1'b1;
    end
    else prog_we <= 1'b0;
end

wire [3:0] red, green, blue;
wire sdram_req, sdram_sync;

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

wire [5:0] vga_r, vga_g, vga_b;
wire vga_hsync, vga_vsync;

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
    .en_mixing  ( en_mixing     ),
    .vga_red    ( vga_r[5:1]    ),
    .vga_green  ( vga_g[5:1]    ),
    .vga_blue   ( vga_b[5:1]    ),
    .vga_hsync  ( vga_hsync     ),
    .vga_vsync  ( vga_vsync     )
);

// convert 5-bit colour to 6-bit colour
assign vga_r[0] = vga_r[5];
assign vga_g[0] = vga_g[5];
assign vga_b[0] = vga_b[5];

assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
assign sim_vs = vs;
assign sim_hs = hs;

jtframe_mist #( .CONF_STR(CONF_STR), .CONF_STR_LEN(CONF_STR_LEN),
    .SIGNED_SND(1'b1), .THREE_BUTTONS(1'b0))
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_rom        ),
    .clk_vga        ( clk_vga        ),
    .pll_locked     ( pll_locked     ),
    .status         ( status         ),
    // Base video
    .osd_rotate     ( 2'b0           ),
    .game_r         ( red            ),
    .game_g         ( green          ),
    .game_b         ( blue           ),
    .LHBL           ( LHBL           ),
    .LVBL           ( LVBL           ),
    .hs             ( hs             ),
    .vs             ( vs             ),
    // VGA
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
    .game_rst       ( game_rst       ),
    // reset forcing signals:
    .dip_flip       ( 1'b0           ),
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
    .gfx_en         (                )
);

jtgng_game #(.CLK_SPEED(CLK_SPEED)) game(
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

    // ROM load
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_req   ( sdram_req     ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .refresh_en  ( refresh_en    ),
    // DEBUG
    .enable_char ( 1'b1          ),
    .enable_scr  ( 1'b1          ),
    .enable_obj  ( 1'b1          ),
    // DIP switches
    .dip_pause      ( dip_pause  ),
    .dip_lives      ( dip_lives  ),
    .dip_level      ( dip_level  ),
    .dip_bonus      ( dip_bonus  ),
    .dip_game_mode  ( dip_test   ),
    .dip_upright    ( 1'b1       ),
    .dip_attract_snd( 1'b1       ), // 0 for sound
    // sound
    .enable_psg  ( enable_psg    ),
    .enable_fm   ( enable_fm     ),
    .ym_snd      ( snd           ),
    .sample      (               )
);

endmodule // jtgng_mist