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
    Date: 2-8-2020 */

module jtsarms_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [8:0] V;
wire [8:0] H;

wire [12:0] cpu_AB;
wire [ 7:0] cpu_dout, char_dout, scr_dout;
wire        map_cs, snd_cs;
wire        char_cs, blue_cs, redgreen_cs;
wire        eres_n, wrerr_n;
wire        flip;
wire        star_hscan, star_vscan;
wire        rd, cpu_cen;
wire        char_wait;
wire        star_fix_n;

localparam CHARW=14,SCRW=17, OBJW=17, MAPW=14, STARW=15;

// ROM data
wire [15:0] char_data, scr_data, map_data;
wire [15:0] obj_data;
wire [ 7:0] main_data, star_data;
wire [ 7:0] snd_data;
// ROM address
wire [MAPW-1 :0] map_addr;
wire [STARW-1:0] star_addr;
wire [CHARW-1:0] char_addr;
wire [SCRW-1 :0] scr_addr;
wire [OBJW-1 :0] obj_addr;
wire [17:0] main_addr;
wire [14:0] snd_addr;
wire [ 7:0] dipsw_a, dipsw_b, dipsw_c;
wire        CHON, SCRON, STARON, OBJON;

wire        prom_we;
wire        main_ok, snd_ok, snd2_ok, obj_ok, obj_ok0;
wire        cen16, cen12, cen8, cen6, cen4, cen3;

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = ioctl_rom;
assign dip_flip   = flip;

assign pxl2_cen = cen16;
assign pxl_cen  = cen8;

assign star_fix_n = status[13];

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dipsw_c = 8'hff; // Only the freeze is contained here, and users often get
    // confused with it, so I'd rather leave it fixed and hidden
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen16  ( cen16     ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen8   ( cen8      ),
    .cen4   ( cen4      ),
    // unused:
    .cen1p5 (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);
/* verilator lint_on PINMISSING */
wire rd_n, wr_n;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;
wire [ 7:0] main_ram;

wire        scr_cs;
wire [15:0] scr_hpos, scr_vpos;

assign cpu_cen = cen8;


localparam [21:0] CPU_OFFSET  = 22'h0;
localparam [21:0] SND_OFFSET  = 22'h1_8000 >> 1;
localparam [21:0] STAR_OFFSET = 22'h2_0000 >> 1;
localparam [21:0] CHAR_OFFSET = 22'h2_8000 >> 1;
localparam [21:0] SCR_OFFSET  = 22'h2_C000 >> 1;
localparam [21:0] OBJ_OFFSET  = 22'h6_C000 >> 1;
localparam [21:0] MAP_OFFSET  = 22'hA_C000 >> 1;
localparam [21:0] PROM_START  = 22'hB_4000;

wire [21:0] pre_prog;
wire [ 7:0] nc2;

assign prog_addr = (ioctl_addr[22:1]>=OBJ_OFFSET && ioctl_addr[22:1]<MAP_OFFSET) ?
    { pre_prog[21:6],pre_prog[4:1],pre_prog[5],pre_prog[0]} :
    pre_prog;

jtframe_dwnld #(
    .PROM_START ( PROM_START )
)
u_dwnld(
    .clk         ( clk           ),
    .ioctl_rom   ( ioctl_rom     ),

    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),
    .ioctl_wr    ( ioctl_wr      ),

    .prog_addr   ( pre_prog      ),
    .prog_data   ({nc2,prog_data}),
    .prog_mask   ( prog_mask     ),
    .prog_we     ( prog_we       ),
    .prom_we     ( prom_we       ),

    .sdram_ack   ( sdram_ack     ),
    .gfx8_en     ( 1'b0          ),
    .gfx16_en    ( 1'b0          ),
    .header      (               )
);

`ifndef NOMAIN

wire [13:0] nc;

jt1943_main #(.GAME(1)) u_main(
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
    // Palette
    .redgreen_cs( redgreen_cs   ),
    .blue_cs    ( blue_cs       ),
    .eres_n     ( eres_n        ),
    .wrerr_n    ( wrerr_n       ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scr1posh   ( scr_hpos      ),
    .scrposv    ( scr_vpos      ),
    .SC1ON      ( SCRON         ),
    .SC2ON      ( STARON        ),
    // Star Field
    .scr2posh   ( { nc, star_hscan, star_vscan } ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .OBJON      ( OBJON         ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dipsw_c    ( dipsw_c       ),
    // unused
    .coin_cnt   (               )
);
`else
assign main_addr   = 18'd0;
assign char_cs     = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign wr_n        = 1'b1;
assign scr_hpos    = 16'd0;
assign scr_vpos    = 16'd0;
`endif

`ifndef NOSOUND
jtgng_sound #(.LAYOUT(8)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen4           ),
    .cen1p5         (                ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd2_latch     (                ),
    .snd_int        (                ),
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
    .debug_bus      ( 8'd0           ),
    .debug_view     ( debug_view     )
);
`else
assign snd_addr  = 0;
assign snd_cs    = 0;
assign snd       = 0;
assign sample    = 0;
`endif

wire scr_ok, star_ok, map_ok, char_ok;

jtsarms_video #(
    .SCRW   ( SCRW      ),
    .OBJW   ( OBJW      ),
    .STARW  ( STARW     )
)
u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cen12      ( cen12         ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( wr_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .eres_n     ( eres_n        ),
    .wrerr_n    ( wrerr_n       ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_wait     ),
    .char_ok    ( char_ok       ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    .map_addr   ( map_addr      ), // 32kB in 8 bits or 16kW in 16 bits
    .map_data   ( map_data      ),
    .map_cs     ( map_cs        ),
    .map_ok     ( map_ok        ),
    .SCRON      ( SCRON         ),
    // STAR FIELD
    .star_hscan ( star_hscan    ),
    .star_vscan ( star_vscan    ),
    .star_addr  ( star_addr     ),
    .star_data  ( star_data     ),
    .star_ok    ( star_ok       ),
    .star_fix_n ( star_fix_n    ),
    .STARON     ( STARON        ),
    // OBJ
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .OBJON      ( OBJON         ),
    // PROMs
    // .prog_addr    ( prog_addr[7:0] ),
    // .prom_prio_we ( prom_we        ),
    // .prom_din     ( prog_data[3:0] ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( CHARW           ), // Char
    .SLOT1_AW    ( SCRW            ), // Scroll
    .SLOT2_AW    ( MAPW            ), // Scroll Map
    .SLOT3_AW    ( STARW           ), // Star field
    .SLOT6_AW    ( 15              ), // Sound
    .SLOT7_AW    ( 18              ), // Main
    .SLOT8_AW    ( OBJW            ), // OBJ

    .SLOT0_DW    ( 16              ), // Char
    .SLOT1_DW    ( 16              ), // Scroll
    .SLOT2_DW    ( 16              ), // Scroll Map
    .SLOT3_DW    (  8              ), // Star
    .SLOT6_DW    (  8              ), // Sound
    .SLOT7_DW    (  8              ), // Main
    .SLOT8_DW    ( 16              ), // OBJ

    .SLOT0_OFFSET( CHAR_OFFSET ),
    .SLOT1_OFFSET( SCR_OFFSET  ),
    .SLOT2_OFFSET( MAP_OFFSET  ),
    .SLOT3_OFFSET( STAR_OFFSET ),
    .SLOT6_OFFSET( SND_OFFSET  ),
    .SLOT7_OFFSET( CPU_OFFSET  ),
    .SLOT8_OFFSET( OBJ_OFFSET  )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // Char
    .slot1_cs    ( LVBL          ), // Scroll
    .slot2_cs    ( map_cs        ), // Map
    .slot3_cs    ( LVBL          ), // Star
    .slot4_cs    ( 1'b0          ),
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // OBJ

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr_ok        ),
    .slot2_ok    ( map_ok        ),
    .slot3_ok    ( star_ok       ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( map_addr      ),
    .slot3_addr  ( star_addr     ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data      ),
    .slot2_dout  ( map_data      ),
    .slot3_dout  ( star_data     ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule
