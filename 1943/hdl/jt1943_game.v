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
    Date: 18-2-2019 */

`timescale 1ns/1ps

module jt1943_game(
    input           rst,
    input           clk,        // 24  or 12  MHz
    input           clk_rom,    // SDRAM clock
    output          cen12,      // 12   MHz
    output          cen6,       //  6   MHz
    output          cen3,       //  3   MHz
    output          cen1p5,     //  1.5 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    input           enable_fm,
    input           enable_psg,

    // SDRAM interface
    input           downloading,
    input           loop_rst,
    output          sdram_sync,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,

    // ROM LOAD
    input   [21:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,

    // cheat
    input           cheat_invincible,
    // DIP Switch A
    input           dip_test,
    input           dip_pause,
    input           dip_upright,
    input           dip_credits2p,
    input   [3:0]   dip_level, // difficulty level
    // DIP Switch B
    input           dip_demosnd,
    input           dip_continue,
    input   [2:0]   dip_price2,
    input   [2:0]   dip_price1,
    input           dip_flip,
    output          coin_cnt,
    // Sound output
    output  [15:0]  snd,
    output          sample,
    // Debug
    input   [3:0]   gfx_en
);

parameter CLK_SPEED=12;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [ 7:0] cpu_dout;
wire [ 7:0] chram_dout;
wire rd;
wire rom_ready;

assign sample=1'b1;

wire LHBL_obj, LVBL_obj, Hsub;

reg rst_game;

always @(negedge clk)
    rst_game <= rst || !rom_ready;

jtgng_cen #(.CLK_SPEED(CLK_SPEED)) u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);


jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen12     ( cen12    ),
    .cen6      ( cen6     ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
    .Hsub      ( Hsub     ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] scrposv, main_ram;

// ROM data
wire [17:0]  main_addr;
wire [16:0]  obj_addr;
wire [16:0]  scr1_addr;
wire [14:0]  scr2_addr;
wire [13:0]  char_addr, map1_addr, map2_addr;
wire [ 7:0]  main_dout;
wire [15:0]  char_dout, obj_dout, map1_dout, map2_dout, scr1_dout, scr2_dout;

wire snd_latch_cs;
wire char_wait;

wire [12:0] prom_we;

jt1943_prom_we u_prom_we(
    .clk_rom     ( clk_rom       ),
    .clk_rgb     ( clk           ),
    .downloading ( downloading   ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .prom_we     ( prom_we       )
);

wire prom_7l_we  = prom_we[ 0];
wire prom_12l_we = prom_we[ 1];
wire prom_12a_we = prom_we[ 2];
wire prom_12m_we = prom_we[ 3];
wire prom_13a_we = prom_we[ 4];
wire prom_14a_we = prom_we[ 5];
wire prom_12c_we = prom_we[ 6];
wire prom_7f_we  = prom_we[ 7];
// wire prom_4b_we  = prom_we[ 8]; // Video timing. Unused.
wire prom_7c_we  = prom_we[ 9];
wire prom_8c_we  = prom_we[10];
wire prom_6l_we  = prom_we[11];
wire prom_4k_we  = prom_we[12];

wire [1:0] scr1posh_cs, scr2posh_cs;

wire CHON, OBJON, SC2ON, SC1ON;
wire cpu_cen, main_cs;
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;
wire main_ok;

//wire video_flip = dip_flip ^ flip; // Original 1943 did not have this DIP bit.

`ifndef NOMAIN
jt1943_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .char_wait( char_wait     ),
    .rom_ok     ( main_ok       ),
    // sound
    .sres_b       ( sres_b        ),
    .snd_latch_cs ( snd_latch_cs  ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .cpu_cen    ( cpu_cen       ),
    .char_cs    ( char_cs       ),
    .char_dout  ( chram_dout    ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scr1posh_cs( scr1posh_cs   ),
    .scr2posh_cs( scr2posh_cs   ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // OBJ - bus sharing
    .OBJON      ( OBJON         ),
    .flip       ( flip          ),
    .V          ( V             ),
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_dout     ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // Cheat
    .cheat_invincible( cheat_invincible ),
    // DIP switches
    .dipsw_a    ( {dip_test, dip_pause, dip_upright, dip_credits2p, dip_level } ),
    .dipsw_b    ( {dip_demosnd, dip_continue, dip_price2, dip_price1} ),
    .coin_cnt   ( coin_cnt      )
);
`else
assign scr1posh_cs = 'b0;
assign scr2posh_cs = 'b0;
assign char_cs = 'b0;
assign SC1ON = 'b1;
assign SC2ON = 'b1;
assign OBJON = 'b1;
assign  CHON = 'b1;
assign main_addr = 'd0;
assign rd_n = 'b1;
assign wr_n = 'b1;
assign cpu_AB = 'b0;
assign sres_b = 'b1;
assign cpu_dout = 'b0;
`endif

`ifndef NOSOUND
jt1943_sound u_sound (
    .rst            ( rst_game       ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .main_cen       ( cpu_cen        ),
    .sres_b         ( sres_b         ),
    .main_dout      ( cpu_dout       ),
    .main_latch_cs  ( snd_latch_cs   ),
    // sound control
    .enable_psg     ( enable_psg     ),
    .enable_fm      ( enable_fm      ),
    .snd_int        ( V[5]           ),
    // PROM 4K
    .prog_addr      ( prog_addr[14:0]),
    .prom_4k_we     ( prom_4k_we     ),
    .prom_din       ( prog_data      ),
    // Sound
    .snd            ( snd            )
);
`else
assign snd = 9'd0;
`endif

jt1943_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .cpu_dout   ( cpu_dout      ),
`ifdef ALWAYS_PAUSE
    .pause      ( 1'b1          ),
    .flip       ( 1'b0          ),
`else
    .flip       ( flip          ),
    .pause      ( ~dip_pause    ),
`endif
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_dout     ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr1posh_cs( scr1posh_cs   ),
    .scr2posh_cs( scr2posh_cs   ),
    .scrposv    ( scrposv       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_dout     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_dout     ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // Scroll maps
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_dout     ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_dout     ),
    // OBJ
    .OBJON      ( OBJON         ),
    .HINIT      ( HINIT         ),
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_dout      ),
    .obj_DB     ( main_ram      ),
    .obj_AB     ( obj_AB        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL       ( LVBL          ),
    .LVBL_obj   ( LVBL_obj      ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    // Char
    .prom_7f_we ( prom_7f_we    ),
    // color mixer proms
    .prom_12a_we( prom_12a_we   ),
    .prom_13a_we( prom_13a_we   ),
    .prom_14a_we( prom_14a_we   ),
    .prom_12c_we( prom_12c_we   ),
    // scroll 1/2 proms
    .prom_6l_we ( prom_6l_we    ),
    .prom_7l_we ( prom_7l_we    ),
    .prom_12l_we( prom_12l_we   ),
    .prom_12m_we( prom_12m_we   ),
    // obj proms
    .prom_7c_we ( prom_7c_we    ),
    .prom_8c_we ( prom_8c_we    ),
    // Debug
    .gfx_en     ( gfx_en        )
);

jt1943_rom2 u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .cen12       ( cen12         ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),
    .sdram_sync  ( sdram_sync    ),
    .sdram_req   ( sdram_req     ),

    .main_cs     ( main_cs       ),
    .main_ok     ( main_ok       ),

    .char_addr   ( char_addr     ), //  32 kB
    .main_addr   ( main_addr     ), // 160 kB, addressed as 8-bit words
    .obj_addr    ( obj_addr      ),  // 256 kB
    .scr1_addr   ( scr1_addr     ), // 256 kB (16-bit words)
    .scr2_addr   ( scr2_addr     ), //  64 kB
    .map1_addr   ( map1_addr     ), //  32 kB
    .map2_addr   ( map2_addr     ), //  32 kB

    .char_dout   ( char_dout     ),
    .main_dout   ( main_dout     ),
    .obj_dout    ( obj_dout      ),
    .map1_dout   ( map1_dout     ),
    .map2_dout   ( map2_dout     ),
    .scr1_dout   ( scr1_dout     ),
    .scr2_dout   ( scr2_dout     ),

    .ready       ( rom_ready     ),
    // SDRAM interface
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule // jtgng