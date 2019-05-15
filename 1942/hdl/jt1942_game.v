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
    Date: 20-1-2019 */

`timescale 1ns/1ps

module jt1942_game(
    input           rst,
    input           rst_n,
    input           clk_rom,
    input           clk,        // 24   MHz
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
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,

    // SDRAM interface
    input           downloading,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,

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
    input           dip_flip,
    input   [1:0]   dip_planes,
    input   [1:0]   dip_bonus,
    input           dip_upright,
    input   [2:0]   dip_price,
    // DIP Switch B
    input           dip_pause,   // DWB - bit 7
    input   [1:0]   dip_level, // difficulty level
    input           dip_test,
    output          coin_cnt,
    // Sound output
    output  [8:0]   snd,
    output          sample
);

parameter CLK_SPEED=12;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout,scram_dout;
wire rd;
wire rom_ready;
wire main_ok, snd_ok;

assign sample=1'b1;

wire LHBL_obj, Hsub;

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
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs, obj_cs;
wire [1:0] scrpos_cs;
wire [2:0] scr_br;

// ROM data
wire  [11:0]  char_addr;
wire  [14:0]  obj_addr;
wire  [15:0]  char_data, obj_data;
wire  [ 7:0]  main_data, snd_data;
wire  [23:0]  scr_data;
wire  [14:0]  scr_addr;
wire  [16:0]  main_addr;
wire  [14:0]  snd_addr;

wire snd_latch0_cs, snd_latch1_cs, snd_int;
wire char_busy, scr_busy;

wire [9:0] prom_we;
jt1942_prom_we u_prom_we(
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

wire prom_k6_we  = prom_we[0];
wire prom_d1_we  = prom_we[1];
wire prom_d2_we  = prom_we[2];
wire prom_d6_we  = prom_we[3];
wire prom_e8_we  = prom_we[4];
wire prom_e9_we  = prom_we[5];
wire prom_e10_we = prom_we[6];
wire prom_f1_we  = prom_we[7];
wire prom_k3_we  = prom_we[8];
wire prom_m11_we = prom_we[9];

jt1942_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    // sound
    .sres_b        ( sres_b        ),
    .snd_latch0_cs ( snd_latch0_cs ),
    .snd_latch1_cs ( snd_latch1_cs ),
    .snd_int       ( snd_int       ),

    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    // Char
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .char_dout  ( chram_dout    ),
    // Scroll
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_dout   ( scram_dout    ),
    // video (other)
    .scr_br     ( scr_br        ),
    .scrpos_cs  ( scrpos_cs     ),
    .obj_cs     ( obj_cs        ),
    .flip       ( flip          ),
    .V          ( V[7:0]        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // SDRAM / ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // PROM K6
    .prog_addr  ( prog_addr[7:0]),
    .prom_k6_we ( prom_k6_we    ),
    .prog_din   ( prog_data[3:0]),
    // Cheat
    .cheat_invincible( cheat_invincible ),
    // DIP switches
    .dip_flip   ( dip_flip      ),
    .dipsw_a    ( {dip_planes, dip_bonus, dip_upright, dip_price } ),
    .dipsw_b    ( {dip_pause, dip_level, 1'b1, dip_test, 3'd7}     ),
    .coin_cnt   ( coin_cnt      )
);

`ifndef NOSOUND
jt1942_sound u_sound (
    .rst            ( rst_game       ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .sres_b         ( sres_b         ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( snd_latch0_cs  ),
    .main_latch1_cs ( snd_latch1_cs  ),
    .snd_int        ( snd_int        ),
    .rom_cs         ( snd_cs         ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),
    .snd            ( snd            )
);
`else
assign snd_addr = 15'd0;
assign snd = 9'd0;
assign snd_cs = 1'b0;
`endif

jt1942_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( ~dip_pause    ), //dipsw_a[7]    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_br     ( scr_br        ),
    // OBJ
    .obj_cs     ( obj_cs        ),
    .HINIT      ( HINIT         ),
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_data      ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL       ( LVBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    .prom_f1_we ( prom_f1_we    ),
    .prom_d1_we ( prom_d1_we    ),
    .prom_d2_we ( prom_d2_we    ),
    .prom_d6_we ( prom_d6_we    ),
    .prom_e8_we ( prom_e8_we    ),
    .prom_e9_we ( prom_e9_we    ),
    .prom_e10_we( prom_e10_we   ),
    .prom_k3_we ( prom_k3_we    ),
    .prom_m11_we( prom_m11_we   )
);

wire [7:0] nc;

jtframe_rom #(
    .SND_OFFSET (22'h0A000),
    .CHAR_OFFSET(22'h0C000),
    .SCR1_OFFSET(22'h0D000),
    .OBJ_OFFSET (22'h15000),
    .MAIN_AW    ( 17      ),
    .SND_AW     ( 15      ),
    .CHAR_AW    ( 12      ),
    .SCR1_AW    ( 15      ),
    .OBJ_AW     ( 15      )
) u_rom (
    .rst_n       ( rst_n         ),
    .clk         ( clk           ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),

    .main_cs     ( main_cs       ),
    .snd_cs      ( snd_cs        ),

    .main_ok     ( main_ok       ),
    .snd_ok      ( snd_ok        ),

    .main_addr   ( main_addr     ),
    .snd_addr    ( snd_addr      ),
    .char_addr   ( char_addr     ),
    .scr1_addr   ( scr_addr      ),
    .obj_addr    ( obj_addr      ),

    .main_dout   ( main_data     ),
    .snd_dout    ( snd_data      ),
    .char_dout   ( char_data     ),
    .scr1_dout   ( {nc, scr_data} ),
    .obj_dout    ( obj_data      ),
    .ready       ( rom_ready     ),
    // Unused
    .scr2_addr   (               ),
    .scr2_dout   (               ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

endmodule // jtgng