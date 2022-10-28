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
    Date: 31-8-2019 */


module jtgunsmoke_game(
    input           rst,
    input           clk,
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
    output          dwnld_busy,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [21:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
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
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en,
    input   [ 7:0]  debug_bus,
    output  [ 7:0]  debug_view
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
wire snd_cs, map1_cs;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout, scr_dout;
wire cpu_cen;
wire char_busy;
wire [ 2:0] obj_bank;

// ROM data
wire [15:0] char_data;
wire [15:0] scr_data;
wire [15:0] obj_data, map_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;
// ROM address
wire [16:0] main_addr;
wire [14:0] snd_addr;
wire [13:0] map_addr;
wire [12:0] char_addr;
wire [16:0] scr_addr;
reg  [16:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;


wire main_ok, snd_ok;
wire cen12, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;

wire cen8;

assign {dipsw_b, dipsw_a} = dipsw[15:0];

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen8   ( cen8      ),
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
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire        main_cs;
wire CHON, OBJON, SCRON;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;
wire [ 7:0] main_ram;

wire [12:0] prom_we;

jt1943_prom_we #(
        .SND_BRAM   ( 0          ), // Sound ROM goes into the SDRAM
        .SNDADDR    ( 22'h1_8000 ),
        .CHARADDR   ( 22'h2_0000 ),
        .MAP1ADDR   ( 22'h2_4000 ),
        .SCR1ADDR   ( 22'h2_C000 ),
        .OBJADDR    ( 22'h6_C000 ),
        .PROMADDR   ( 22'hA_C000 ))
u_prom_we(
    .clk         ( clk           ),
    .downloading ( downloading   ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .prom_we     ( prom_we       ),
    .sdram_ack   ( sdram_ack     )
);

wire prom_red_we   = prom_we[0];
wire prom_green_we = prom_we[1];
wire prom_blue_we  = prom_we[2];
wire prom_char_we  = prom_we[3];
wire prom_scrlo_we = prom_we[4];
wire prom_scrhi_we = prom_we[5];
wire prom_objlo_we = prom_we[6];
wire prom_objhi_we = prom_we[7];
wire prom_prior_we = prom_we[9];

wire [7:0] scrposv;
wire [15:0] scrposh;

`ifndef NOMAIN

jtgunsmoke_main u_main(
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
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scrposh    ( scrposh       ),
    .SCRON      ( SCRON         ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .OBJON      ( OBJON         ),
    .obj_bank   ( obj_bank      ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .service     ( service      ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 17'd0;
assign rd_n        = 'b1;
assign wr_n        = 'b1;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
assign cpu_cen     = cen3;
assign obj_bank    = 3'd0;
`endif

`ifndef NOSOUND
jtgng_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( V[5]           ),
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
    .peak           ( game_led       ),
    .debug_view     ( debug_view     )
);
`else
assign snd_addr = 15'd0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

wire scr_ok, map1_ok, char_ok, obj_ok;

wire nc;
wire [15:0] pre_obj_addr;
reg         video_flip;

always @(posedge clk)
    video_flip <= ~dip_flip ^ flip; // Original Gun Smoke did not have this DIP bit.

jt1943_video #(
    .CHAR_PAL      ( "../../../rom/gunsmoke/g-01.03b" ),
    .CHAR_IDMSB0   ( 6                                ),
    .CHAR_VFLIP_XOR( 1'b1                             ),
    .CHAR_HFLIP_XOR( 1'b1                             ),
    // Scroll
    .SCRPLANES     ( 1                                ),
    .SCR1_PALHI    ( "../../../rom/gunsmoke/g-06.14a" ),
    .SCR1_PALLO    ( "../../../rom/gunsmoke/g-07.15a" ),
    // Objects
    // DMA timing measured on real PCB was roughly 130us
    // which correspons to these parameters:
    .OBJMAX        ( 10'h180                          ),
    .OBJMAX_LINE   ( 6'd24                            ),
    .OBJ_LAYOUT    ( 2                                ),
    .OBJ_ROM_AW    ( 16                               ),
    // Colour mixer
    .PALETTE_RED   ( "../../../rom/gunsmoke/g-01.03b" ),
    .PALETTE_GREEN ( "../../../rom/gunsmoke/g-02.04b" ),
    .PALETTE_BLUE  ( "../../../rom/gunsmoke/g-03.05b" ),
    .PALETTE_PRIOR ( "../../../rom/gunsmoke/g-05.01f" )
) u_video(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .cen12         ( cen12         ),
    .cen8          ( cen8          ),
    .cen6          ( cen6          ),
    .cen3          ( cen3          ),
    .cpu_cen       ( cpu_cen       ),
    .cpu_AB        ( cpu_AB[10:0]  ),
    .V             ( V[7:0]        ),
    .H             ( H             ),
    .rd_n          ( rd_n          ),
    .wr_n          ( wr_n          ),
    .cpu_dout      ( cpu_dout      ),
    .flip          ( video_flip    ), // no software support for DIP flip in GunSmoke
    // CHAR
    .char_cs       ( char_cs       ),
    .chram_dout    ( char_dout     ),
    .char_addr     ( {nc, char_addr}     ),
    .char_data     ( char_data     ),
    .char_wait     ( char_busy     ),
    .char_ok       ( char_ok       ),
    .CHON          ( CHON          ),
    // SCROLL - ROM
    .scr1posh      ( scrposh       ),
    .scr2posh      ( 16'd0         ),
    .scrposv       ( scrposv       ),
    .scr1_addr     ( scr_addr      ),
    .scr1_data     ( scr_data      ),
    .scr2_addr     (               ),
    .scr2_data     (               ),
    .SC1ON         ( SCRON         ),
    .SC2ON         (               ),
    // Scroll maps
    .map1_addr     ( map_addr      ),
    .map1_data     ( map_data      ),
    .map1_ok       ( map1_ok       ),
    .map1_cs       ( map1_cs       ),
    .map2_addr     (               ),
    .map2_data     (               ),
    // OBJ
    .OBJON         ( OBJON         ),
    .HINIT         ( HINIT         ),
    .obj_AB        ( obj_AB        ),
    .obj_DB        ( main_ram      ),
    .obj_addr      ( pre_obj_addr  ),
    .obj_data      ( obj_data      ),
    .obj_ok        ( obj_ok        ),
    .OKOUT         ( OKOUT         ),
    .bus_req       ( bus_req       ), // Request bus
    .bus_ack       ( bus_ack       ), // bus acknowledge
    .blcnten       ( blcnten       ), // bus line counter enable
    // Color Mix
    .preLHBL       ( preLHBL       ),
    .preLVBL       ( preLVBL       ),
    .LHBL          ( LHBL          ),
    .LVBL          ( LVBL          ),
    .LHBL_obj      ( LHBL_obj      ),
    .LVBL_obj      ( LVBL_obj      ),
    // PROM access
    .prog_addr     ( prog_addr[7:0]),
    .prog_din      ( prog_data[3:0]),
    // Char
    .prom_char_we  ( prom_char_we  ),
    // color mixer proms
    .prom_red_we   ( prom_red_we   ),
    .prom_green_we ( prom_green_we ),
    .prom_blue_we  ( prom_blue_we  ),
    .prom_prior_we ( prom_prior_we ),
    // scroll 1/2 proms
    .prom_scr1hi_we( prom_scrhi_we ),
    .prom_scr1lo_we( prom_scrlo_we ),
    .prom_scr2hi_we( 1'b0          ),
    .prom_scr2lo_we( 1'b0          ),
    // obj proms
    .prom_objhi_we ( prom_objhi_we ),
    .prom_objlo_we ( prom_objlo_we ),
    // Debug
    .gfx_en        ( gfx_en        ),
    // Pixel Output
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          )
);

always @(*) begin
    obj_addr[13:0]  = pre_obj_addr[13:0];
    obj_addr[16:14] = pre_obj_addr[15:14] == 2'b11 ? obj_bank + 3'b011 : {1'b0, pre_obj_addr[15:14]};
end

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 13              ), // char
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( 22'h2_0000 >> 1 ),

    .SLOT1_AW    ( 14              ), // map
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( 22'h2_4000 >> 1 ),

    .SLOT2_AW    ( 17              ), // scroll
    .SLOT2_DW    ( 16              ),
    .SLOT2_OFFSET( 22'h2_C000 >> 1 ),

    .SLOT6_AW    ( 15              ), // sound
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( 22'h1_8000 >> 1 ),

    .SLOT7_AW    ( 17              ), // main
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              ),

    .SLOT8_AW     ( 17              ),
    .SLOT8_DW     ( 16              ),
    .SLOT8_OFFSET ((22'h2_C000 >> 1) + 22'h2_0000 )

) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // char
    .slot1_cs    ( map1_cs       ), // map
    .slot2_cs    ( LVBL          ), // scroll
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( map1_ok       ),
    .slot2_ok    ( scr_ok        ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( map_addr      ),
    .slot2_addr  ( scr_addr      ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( map_data      ),
    .slot2_dout  ( scr_data      ),
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
