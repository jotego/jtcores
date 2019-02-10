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

module jt1942_mist(
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
);


localparam CONF_STR = {
    //   00000000011111111112222222222333333333344444444445
    //   12345678901234567890123456789012345678901234567890
        "JT1942;;", //8
        "O1,Pause,OFF,ON;", // 16
        "O23,Difficulty,Normal,Easy,Hard,Very hard;", // 42
        "O4,Test mode,OFF,ON;", // 20
        "O56,Lives,2,1,3,5;", // 18
        "O78,Bonus,30/100,30/80,20/100,20/80;", // 36
        "O9,Screen filter,OFF,ON;", // 24
        "TA,RST ,OFF,ON;", // 15
        "V,http://patreon.com/topapate;" // 30
};

localparam CONF_STR_LEN = 8+16+42+20+18+36+15+24+30;

wire          rst, clk_rgb, clk_vga, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire          ps2_kbd_clk, ps2_kbd_data;
wire [ 5:0]   board_r, board_g, board_b;
wire          board_hsync, board_vsync, hs, vs;
wire [21:0]   sdram_addr;
wire [15:0]   data_read;
wire          loop_rst, autorefresh; 
wire          downloading;
wire [24:0]   romload_addr;
wire [15:0]   romload_data;
wire          coin_cnt;

assign LED = ~downloading | coin_cnt | rst;

jtgng_mist_base #(.CONF_STR(CONF_STR), .CONF_STR_LEN(CONF_STR_LEN)) u_base(
    .rst            ( rst           ),
    .clk_rgb        ( clk_rgb       ),
    .clk_vga        ( clk_vga       ),
    .clk_rom        ( clk_rom       ),
    .SDRAM_CLK      ( SDRAM_CLK     ),
    .cen12          ( cen12         ),
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
    .clk    ( clk_rgb   ),
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
    wire [8:0] snd;

wire [9:0] prom_we;
jt1942_prom_we u_prom_we(
    .downloading    ( downloading   ), 
    .romload_addr   ( romload_addr  ),
    .prom_we        ( prom_we       )
);

reg soft_rst;
reg [7:0] soft_rst_cnt;
reg last_downloading;
always @(negedge clk_rgb) 
    if ( rst ) begin
        soft_rst <= 1'b0;
        soft_rst_cnt <= 8'h0;
    end else begin
        last_downloading <= downloading;
        if( last_downloading && !downloading ) begin
            soft_rst <= 1'b1;
            soft_rst_cnt <= ~8'h0;;
        end
        if( soft_rst_cnt != 8'h0 ) soft_rst_cnt <= soft_rst_cnt-8'b1;
        if( soft_rst_cnt == 8'h0 ) soft_rst <= status[10];
    end

wire [5:0] game_joystick1, game_joystick2;
wire [1:0] game_coin, game_start;
wire game_pause;

jt1942_game u_game(
    .rst         ( rst           ),
    .soft_rst    ( soft_rst      ),
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

    // PROM programming
    .prog_addr   ( romload_addr[7:0] ),
    .prog_din    ( romload_data[3:0] ),
    .prom_k6_we  ( prom_we[0]        ),
    .prom_d1_we  ( prom_we[1]        ),
    .prom_d2_we  ( prom_we[2]        ),
    .prom_d6_we  ( prom_we[3]        ),
    .prom_e8_we  ( prom_we[4]        ),
    .prom_e9_we  ( prom_we[5]        ),
    .prom_e10_we ( prom_we[6]        ),
    .prom_f1_we  ( prom_we[7]        ),  
    .prom_k3_we  ( prom_we[8]        ),  
    .prom_m11_we ( prom_we[9]        ),  

    // ROM load
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // DIP switches
    
    .dip_pause   ( ~(status[1]|game_pause)   ),
    .dip_level   ( ~status[3:2]  ),
    .dip_test    ( ~status[4]    ),
    .dip_upright ( 1'b0          ),
    .dip_planes  ( ~status[6:5]  ),
    .dip_price   ( 3'b111        ), // 1 credit, 1 coin
    .dip_bonus   ( ~status[8:7]  ),
    .coin_cnt    ( coin_cnt      ),
    // sound
    .snd         ( snd           ),
    .sample      (               )
);

assign AUDIO_R = AUDIO_L;

jtgng_board u_board(
    .rst            ( rst             ),
    .clk_rgb        ( clk_rgb         ),
    .clk_dac        ( clk_rom         ),
    // audio
    .snd            ( { snd, 7'd0 }   ),
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