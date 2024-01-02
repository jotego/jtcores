/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-2-2019 */

module jt1943_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = ioctl_rom;

parameter CLK_SPEED=48;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, chram_dout;
wire rd;
// ROM data
wire [15:0]  char_data, obj_data,
             map1_data, map2_data, scr1_data, scr2_data;
wire [ 7:0]  main_data;
// ROM address
wire [17:0]  main_addr;
wire [13:0]  char_addr, map1_addr, map2_addr;
wire [16:0]  obj_addr;
wire [16:0]  scr1_addr;
wire [14:0]  scr2_addr;
wire [ 7:0]  dipsw_a, dipsw_b;

wire main_ok, map1_ok, map2_ok, scr1_ok, scr2_ok, char_ok, obj_ok;
wire map1_cs, map2_cs;
wire cen12, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

wire LHBL_obj, LVBL_obj;
wire preLHBL, preLVBL;

wire cen8;

assign {dipsw_b, dipsw_a} = dipsw[15:0];

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen1p5 ( cen1p5    ),
    .cen3   ( cen3      ),
    .cen6   ( cen6      ),
    .cen8   ( cen8      ),
    .cen12  ( cen12     ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen16  (           ),
    .cen16b (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

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
wire [7:0] scrposv, main_ram;

wire char_wait;

wire [15:0] scr1posh, scr2posh;

wire CHON, OBJON, SC2ON, SC1ON;
wire cpu_cen, main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;

wire [12:0] prom_we;

jt1943_prom_we #(.SND_BRAM(1)) u_prom_we(
    .clk         ( clk           ),
    .ioctl_rom   ( ioctl_rom     ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  (ioctl_addr[21:0]),
    .ioctl_dout  ( ioctl_dout    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .prom_we     ( prom_we       ),
    .sdram_ack   ( sdram_ack     )
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

reg video_flip;

always @(posedge clk)
    video_flip <= dip_flip; // Original 1943 did not have this DIP bit.


// 1943 board supports three buttons, but the software only uses two
// to perform a loop with the plane, you have to press buttons 1 and 2
// this is hard to do.
// The assignment below forces buttons 1 and 2 whenever button 3 is pressed
// so the loop can be done with the 3rd button
reg [2:0] joy1_btn;
reg [2:0] joy2_btn;

always @(posedge clk) begin
    joy1_btn <= { {3{joystick1[6]}} & joystick1[6:4] };
    joy2_btn <= { {3{joystick2[6]}} & joystick2[6:4] };
end

assign cpu_cen = cen6;

`ifndef NOMAIN
jt1943_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LVBL       ( LVBL          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( chram_dout    ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
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
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
    .service     ( service      ),
    .joystick1   ( { joy1_btn, joystick1[3:0]}    ),
    .joystick2   ( { joy2_btn, joystick2[3:0]}    ),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dipsw_c    (               ),
    .dip_pause  ( dip_pause     ),
    .coin_cnt   (               ),
    // unused ports (used in SideArms only)
    .blue_cs    (               ),
    .redgreen_cs(               ),
    .eres_n     (               ),
    .wrerr_n    (               )
);
`else
    assign scr1posh  = 16'h5f3a;
    assign scr2posh  = 16'h6000;
    assign scrposv   = 0;
    assign char_cs   = 0;
    assign SC1ON     = 1;
    assign SC2ON     = 1;
    assign OBJON     = 1;
    assign  CHON     = 1;
    assign main_addr = 0;
    assign main_cs   = 0;
    assign main_ram  = 0;
    assign rd_n      = 1;
    assign wr_n      = 1;
    assign cpu_AB    = 0;
    assign sres_b    = 1;
    assign cpu_dout  = 0;
    assign OKOUT     = 0;
    assign bus_ack   = 1;
    assign flip      = 0;
`endif

`ifndef NOSOUND
reg  [ 7:0] snd_data;
wire [ 7:0] snd_data0, snd_data1;
wire [14:0] snd_addr;
wire        snd_cs;     // unused at this level

always @(posedge clk)
    snd_data <= snd_addr[14] ? snd_data1 : snd_data0;

jtgng_sound u_sound (
    .rst            ( rst        ),
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    // Interface with main CPU
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .snd2_latch     (            ),
    .snd_int        ( V[5]       ),
    // sound control
    .enable_psg     ( enable_psg ),
    .enable_fm      ( enable_fm  ),
    .psg_level      ( dip_fxlevel),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         ( snd_cs     ),
    .rom_ok         ( 1'b1       ),
    // sound output
    .ym_snd         ( snd        ),
    .sample         ( sample     ),
    .peak           ( game_led   ),
    .debug_bus      ( debug_bus  ),
    .debug_view     ( debug_view )
);

// full 32kB ROM is inside the FPGA to alleviate SDRAM bandwidth
// separated in two modules to make implementation easier
jtframe_prom #(.AW(14),.DW(8),.SIMFILE("audio_lo.bin")) u_prom0(
    .clk    ( clk               ),
    .cen    ( cen3              ),
    .data   ( prog_data         ),
    .rd_addr( snd_addr[13:0]    ),
    .wr_addr( prog_addr[13:0]   ),
    .we     ( prom_4k_we & !prog_addr[14] ),
    .q      ( snd_data0         )
);

jtframe_prom #(.AW(14),.DW(8),.SIMFILE("audio_hi.bin")) u_prom1(
    .clk    ( clk               ),
    .cen    ( cen3              ),
    .data   ( prog_data         ),
    .rd_addr( snd_addr[13:0]    ),
    .wr_addr( prog_addr[13:0]   ),
    .we     ( prom_4k_we & prog_addr[14]  ),
    .q      ( snd_data1         )
);
`else
    assign snd    = 0;
    assign sample = 0;
`endif

jt1943_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .cpu_dout   ( cpu_dout      ),
    .flip       ( video_flip    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_wait  ( char_wait     ),
    .char_ok    ( char_ok       ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .scrposv    ( scrposv       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // Scroll maps
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_cs    ( map1_cs       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_cs    ( map2_cs       ),
    // OBJ
    .OBJON      ( OBJON         ),
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .obj_DB     ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    // Char
    .prom_char_we  ( prom_7f_we    ),
    // color mixer proms
    .prom_red_we   ( prom_12a_we   ),
    .prom_green_we ( prom_13a_we   ),
    .prom_blue_we  ( prom_14a_we   ),
    .prom_prior_we ( prom_12c_we   ),
    // scroll 1/2 proms
    .prom_scr1hi_we( prom_6l_we    ),
    .prom_scr1lo_we( prom_7l_we    ),
    .prom_scr2hi_we( prom_12l_we   ),
    .prom_scr2lo_we( prom_12m_we   ),
    // obj proms
    .prom_objhi_we ( prom_7c_we    ),
    .prom_objlo_we ( prom_8c_we    ),
    // Debug
    .gfx_en        ( gfx_en        ),
    .debug_bus     ( debug_bus     ),
    // Pixel Output
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          )
);

// Sound is not used through the ROM interface because there is not enough banwidth
// when all the scroll ROMs have to be accessed
jtframe_rom #(
    .SLOT0_AW    ( 14              ), // Char
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( 22'h1_8000      ),

    .SLOT1_AW    ( 14              ), // Map 1
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( 22'h1_C000      ),

    .SLOT2_AW    ( 17              ), // Scroll 1
    .SLOT2_DW    ( 16              ),
    .SLOT2_OFFSET( 22'h2_4000      ),

    .SLOT3_AW    ( 14              ), // Map 2
    .SLOT3_DW    ( 16              ),
    .SLOT3_OFFSET( 22'h2_0000      ),

    .SLOT4_AW    ( 15              ), // Scroll 2
    .SLOT4_DW    ( 16              ),
    .SLOT4_OFFSET( 22'h4_4000      ),

    // .SLOT6_AW    ( 15              ), // Sound
    // .SLOT6_DW    (  8              ),
    // .SLOT6_OFFSET( 22'h1_4000 >> 1 ),

    .SLOT7_AW    ( 18              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              ), // Main

    .SLOT8_AW    ( 17              ), // objects
    .SLOT8_DW    ( 16              ),
    .SLOT8_OFFSET( 22'h4_C000      )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // char
    .slot1_cs    ( map1_cs       ), // map 1
    .slot2_cs    ( LVBL          ), // scroll 1
    .slot3_cs    ( map2_cs       ), // map 2
    .slot4_cs    ( LVBL          ), // scroll 2
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( 1'b0          ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( map1_ok       ),
    .slot2_ok    ( scr1_ok       ),
    .slot3_ok    ( map2_ok       ),
    .slot4_ok    ( scr2_ok       ),
    .slot5_ok    (               ),
    .slot6_ok    (               ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( map1_addr     ),
    .slot2_addr  ( scr1_addr     ),
    .slot3_addr  ( map2_addr     ),
    .slot4_addr  ( scr2_addr     ),
    .slot5_addr  (               ),
    .slot6_addr  (               ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( map1_data     ),
    .slot2_dout  ( scr1_data     ),
    .slot3_dout  ( map2_data     ),
    .slot4_dout  ( scr2_data     ),
    .slot5_dout  (               ),
    .slot6_dout  (               ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);


endmodule
