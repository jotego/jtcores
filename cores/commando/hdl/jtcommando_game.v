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


module jtcommando_game(
    input           rst,
    input           clk,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [21:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = downloading;

parameter CLK_SPEED=48;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire snd_cs;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout, scr_dout;
wire rd, cpu_cen;
wire char_busy, scr_busy;

// ROM data
wire [15:0] char_data;
wire [23:0] scr_data;
wire [15:0] obj_data, obj_pre;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;
// ROM address
wire [15:0] main_addr;
wire [14:0] snd_addr;
wire [12:0] char_addr;
wire [14:0] scr_addr;
wire [15:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;


wire main_ok, snd_ok, obj_ok, obj_ok0;
wire cen12, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = ~flip;

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

wire LHBL_obj, LVBL_obj;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire RnW;
// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [7:0] main_ram;

wire [5:0] prom_we;

jtcommando_prom_we u_prom_we(
    .clk         ( clk           ),
    .downloading ( downloading   ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .prom_we     ( prom_we       ),
    .sdram_ack   ( sdram_ack     )
);

wire prom_1d = prom_we[0];
wire prom_2d = prom_we[1];
wire prom_3d = prom_we[2];
wire prom_1h = prom_we[3];
wire prom_6l = prom_we[4];
wire prom_6e = prom_we[5];

wire scr_cs;
wire [8:0] scr_hpos, scr_vpos;


`ifndef NOMAIN

jtcommando_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd_int    ( snd_int       ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
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

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( prog_addr[7:0]),
    .prom_6l_we ( prom_6l       ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 16'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
assign cpu_cen     = cen3;
`endif

`ifndef NOSOUND
jtgng_sound #(.LAYOUT(1)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
    // sound control
    .enable_psg     ( enable_psg     ),
    .enable_fm      ( enable_fm      ),
    .psg_level      ( dip_fxlevel    ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .ym_snd         ( snd            ),
    .sample         ( sample         ),
    .peak           ( game_led       )
);
`else
assign snd_addr = 15'd0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

wire scr1_ok, scr2_ok, char_ok;
wire scr_ok = scr1_ok & scr2_ok;

reg pause;
always @(posedge clk) pause <= ~dip_pause;

jtgng_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0),
    .PALETTE_RED  ("../../../rom/commando/vtb1.1d"),
    .PALETTE_GREEN("../../../rom/commando/vtb2.2d"),
    .PALETTE_BLUE ("../../../rom/commando/vtb3.3d"),
    .AVATAR_MAX   (9)
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( pause         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_red_we  ( prom_1d       ),
    .prom_green_we( prom_2d       ),
    .prom_blue_we ( prom_3d       ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

wire [7:0] scr_nc; // no connect

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 13              ), // Char
    .SLOT1_AW    ( 15              ), // Scroll 1, bytes 0-1
    .SLOT2_AW    ( 15              ), // Scroll 1, byte 2
    .SLOT6_AW    ( 15              ), // Sound
    .SLOT7_AW    ( 16              ), // Main
    .SLOT8_AW    ( 16              ), // OBJ

    .SLOT0_DW    ( 16              ), // Char
    .SLOT1_DW    ( 16              ), // Scroll 1, bytes 0-1
    .SLOT2_DW    ( 16              ), // Scroll 1, byte 2
    .SLOT6_DW    (  8              ), // Sound
    .SLOT7_DW    (  8              ), // Main
    .SLOT8_DW    ( 16              ), // OBJ

    .SLOT6_OFFSET( 22'h0_C000 >> 1 ),
    .SLOT0_OFFSET( 22'h1_0000 >> 1 ),
    .SLOT1_OFFSET( 22'h1_4000 >> 1 ),
    .SLOT2_OFFSET( (22'h1_4000 >> 1) + 22'h0_8000 ),
    .SLOT8_OFFSET( (22'h1_4000 >> 1) + 22'h1_0000 )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    //.pause       ( pause         ),
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
    .slot8_ok    ( obj_ok0       ),

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
    .slot8_dout  ( obj_pre       ),

    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

jtframe_avatar #(.AW(14)) u_avatar(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .pause       ( pause         ),
    .obj_addr    ( obj_addr[13:0]),
    .obj_data    ( obj_pre       ),
    .obj_mux     ( obj_data      ),
    .ok_in       ( obj_ok0       ),
    .ok_out      ( obj_ok        )
);

endmodule
