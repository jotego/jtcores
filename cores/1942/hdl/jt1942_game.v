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


module jt1942_game(
    input           rst,
    input           clk,        // 24   MHz
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
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
    input   [ 6:0]  joystick1, // MSB unused
    input   [ 6:0]  joystick2, // MSB unused

    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dok,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,

    // ROM LOAD
    input   [22:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // ignored
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  [15:0]  snd,
    output          sample,
    output          game_led,
    input           enable_psg, // unused
    input           enable_fm,  // unused
    // Debug
    input   [ 3:0]  gfx_en
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = downloading;
assign game_led   = 0;

parameter CLK_SPEED=48;

wire [8:0] V;
wire [8:0] H;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [ 7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout,scram_dout;
wire [ 7:0] dipsw_a, dipsw_b;
wire rd;
wire rom_ready;
wire cpu_cen;
wire main_ok, snd_ok, char_ok, obj_ok;
wire cen12, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;
assign {dipsw_b, dipsw_a} = dipsw[15:0];
`ifndef VULGUS
    assign dip_flip = ~flip;
`endif

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire main_cs, snd_cs;
wire scr_cs, obj_cs;
wire [2:0] scr_br;
wire [8:0] scr_hpos, scr_vpos;

// ROM data
wire  [11:0]  char_addr;
wire  [14:0]  obj_addr;
wire  [15:0]  char_data, obj_data;
wire  [ 7:0]  main_data, snd_data;
wire  [23:0]  scr_data;
wire  [13:0]  scr_addr;
wire  [16:0]  main_addr;
wire  [14:0]  snd_addr;

wire snd_latch0_cs, snd_latch1_cs, snd_int;
wire char_busy, scr_busy;

`ifdef VULGUS
localparam VULGUS = 1'b1;
`else
localparam VULGUS = 1'b0;
`endif


wire [9:0] prom_we;
jt1942_prom_we
`ifdef VULGUS
#(
   .SOUNDADDR ( 22'h0_A000),
   .CHARADDR  ( 22'h0_E000),
   .SCRADDR   ( 22'h1_0000),
   .SCRUPPER  ( 22'h1_8000),
   .OBJADDR   ( 22'h2_0000),
   .PROMADDR  ( 22'h2_8000)    )
`endif
u_prom_we(
    .clk         ( clk               ),
    .downloading ( downloading       ),

    .ioctl_wr    ( ioctl_wr          ),
    .ioctl_addr  ( ioctl_addr[21:0]  ),
    .ioctl_dout  ( ioctl_dout        ),

    .prog_data   ( prog_data         ),
    .prog_mask   ( prog_mask         ),
    .prog_addr   ( prog_addr         ),
    .prog_we     ( prog_we           ),

    .prom_we     ( prom_we           ),
    .sdram_ack   ( sdram_ack         )
);

wire prom_irq_we   = prom_we[0];
wire prom_d1_we    = prom_we[1];
wire prom_d2_we    = prom_we[2];
wire prom_d6_we    = prom_we[3];
wire prom_red_we   = prom_we[4];
wire prom_green_we = prom_we[5];
wire prom_blue_we  = prom_we[6];
wire prom_char_we  = prom_we[7];
wire prom_obj_we   = prom_we[8];
wire prom_m11_we   = prom_we[9];

`ifndef NOMAIN
jt1942_main #(.VULGUS(VULGUS)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // sound
    .sres_b        ( sres_b        ),
    .snd_latch0_cs ( snd_latch0_cs ),
    .snd_latch1_cs ( snd_latch1_cs ),
    .snd_int       ( snd_int       ),

    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    .dip_pause  ( dip_pause     ),
    // Char
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .char_dout  ( chram_dout    ),
    // Scroll
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_dout   ( scram_dout    ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // video (other)
    .scr_br     ( scr_br        ),
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
    .service     ( service      ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),
    // PROM K6
    .prog_addr  ( prog_addr[7:0]),
    .prom_irq_we( prom_irq_we   ),
    .prog_din   ( prog_data[3:0]),
    // Cheat
    .cheat_invincible( 1'b0 ),
    // DIP switches
    .dip_flip   ( dip_flip      ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .coin_cnt   (               )
);
`else
assign main_cs   = 1'b0;
assign cpu_cen   = cen3;
assign char_cs   = 1'b0;
assign scr_cs    = 1'b0;
assign obj_cs    = 1'b0;
assign scr_hpos  = 9'd0;
assign scr_vpos  = 9'd0;
assign scr_br    = 2'b0;
assign flip      = 1'b0;
`endif

`ifndef NOSOUND
jt1942_sound u_sound (
    .rst            ( rst            ),
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
assign snd      = 16'd0;
assign snd_cs   = 1'b0;
`endif

wire scr1_ok, scr2_ok;
wire scr_ok = scr1_ok & scr2_ok;

jt1942_video u_video(
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
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( ~dip_pause    ), //dipsw_a[7]    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),
    .char_busy  ( char_busy     ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_br     ( scr_br        ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .obj_cs     ( obj_cs        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    .prom_char_we ( prom_char_we    ),
    .prom_d1_we ( prom_d1_we    ),
    .prom_d2_we ( prom_d2_we    ),
    .prom_d6_we ( prom_d6_we    ),
    .prom_e8_we ( prom_red_we   ),
    .prom_e9_we ( prom_green_we ),
    .prom_e10_we( prom_blue_we  ),
    .prom_obj_we( prom_obj_we   ),
    .prom_m11_we( prom_m11_we   )
);

wire [7:0] scr_nc;

jtframe_rom #(
    `ifdef VULGUS
    .SLOT6_OFFSET(22'h0A000>>1), // sound
    .SLOT0_OFFSET(22'h0E000>>1), // char
    .SLOT1_OFFSET(22'h10000>>1), // SCR1
    .SLOT2_OFFSET(22'h18000>>1), // scr2
    .SLOT8_OFFSET(22'h20000>>1),
    `else
    .SLOT6_OFFSET(22'h14000>>1),
    .SLOT0_OFFSET(22'h18000>>1),
    .SLOT1_OFFSET(22'h1A000>>1),
    .SLOT2_OFFSET(22'h22000>>1),
    .SLOT8_OFFSET(22'h2A000>>1),
    `endif
    .SLOT0_DW    ( 16         ),
    .SLOT1_DW    ( 16         ),
    .SLOT2_DW    ( 16         ),
    .SLOT6_DW    (  8         ),
    .SLOT7_DW    (  8         ),
    .SLOT8_DW    ( 16         ),

    .SLOT0_AW    ( 12         ),    // char
    .SLOT1_AW    ( 14         ),    // SCR1
    .SLOT2_AW    ( 14         ),    // SCR2
    .SLOT6_AW    ( 15         ),    // sound
    .SLOT7_AW    ( 17         ),    // main
    .SLOT8_AW    ( 15         )     // OBJ
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( LVBL          ),
    .slot2_cs    ( LVBL          ),
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr1_ok       ),
    .slot2_ok    ( scr2_ok       ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( scr_addr      ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data[15:0]),
    .slot2_dout  ( { scr_nc, scr_data[23:16]       } ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule
