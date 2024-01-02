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

module jttrojan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = ioctl_rom;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire snd_cs, snd2_cs, map_cs;
wire char_cs, blue_cs, redgreen_cs;
wire flip;
wire [7:0] cpu_dout, char_dout, scr_dout;
wire [15:0] scr2_hpos;
wire rd, cpu_cen;
wire char_busy, scr_busy;

localparam SCRW=18, SCR2W=15, OBJW=18;

// ROM data
wire [15:0] char_data, scr_data, scr2_data, map_data;
wire [15:0] obj_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data, snd2_data;
// ROM address
wire [16:0] main_addr;
wire [14:0] snd_addr;
wire [13:0] map_addr;
wire [13:0] snd2_addr;
wire [13:0] char_addr;
wire [SCRW-1:0] scr_addr;
wire [SCR2W-1:0] scr2_addr;
wire [OBJW-1:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;

wire main_ok, snd_ok, snd2_ok, obj_ok;
wire cen12, cen8, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = flip;
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // unused:
    .cen16  (           ),
    .cen8   ( cen8      ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);
/* verilator lint_on PINMISSING */
wire RnW;
// sound
wire sres_b, snd_int;
wire [7:0] snd_latch, snd2_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [ 7:0] main_ram, game_cfg;

localparam [21:0] CPU_OFFSET  = 22'h0;
localparam [21:0] SND_OFFSET  = 22'h1_8000 >> 1;
localparam [21:0] SND2_OFFSET = 22'h2_0000 >> 1;
localparam [21:0] MAP_OFFSET  = 22'h2_4000 >> 1;
localparam [21:0] CHAR_OFFSET = 22'h4_0000 >> 1;
localparam [21:0] SCR_OFFSET  = 22'h4_4000 >> 1;
localparam [21:0] SCR2_OFFSET = 22'h2_C000 >> 1;
localparam [21:0] OBJ_OFFSET  = 22'h8_4000 >> 1;

jtsectnz_prom_we #(
    .CPU_OFFSET     ( CPU_OFFSET    ),
    .SND_OFFSET     ( SND_OFFSET    ),
    .CHAR_OFFSET    ( CHAR_OFFSET   ),
    .SCR_OFFSET     ( SCR_OFFSET    ),
    .OBJ_OFFSET     ( OBJ_OFFSET    ))
u_prom_we(
    .clk         ( clk           ),
    .ioctl_rom   ( ioctl_rom     ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr[21:0] ),
    .ioctl_dout  ( ioctl_dout    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .sdram_ack   ( sdram_ack     ),
    .game_cfg    ( game_cfg      )
);

wire scr_cs;
wire [10:0] scr_hpos, scr_vpos;


`ifndef NOMAIN

jtcommnd_main #(.GAME(2)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel    ( 1'b0          ), // 3MHz CPU
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd2_latch ( snd2_latch    ),
    .snd_int    ( snd_int       ),
    // Palette
    .redgreen_cs( redgreen_cs   ),
    .blue_cs    ( blue_cs       ),
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
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
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
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( 8'd0          ),
    .prom_6l_we ( 1'b0          ),
    .prog_din   ( 4'd0          ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    // Unused
    .char_on    (               ),
    .scr1_on    (               ),
    .scr2_on    (               ),
    .obj_on     (               ),
    .scr1_pal   (               ),
    .scr2_pal   (               )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 0;
assign scr_vpos    = 0;
assign cpu_cen     = cen3;
`endif

jttrojan_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd2_latch     ( snd2_latch     ),
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
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .ym_snd         ( snd            ),
    .sample         ( sample         ),
    .peak           ( game_led       ),
    .debug_view     ( debug_view     )
);

wire scr_ok, scr2_ok, map_ok, char_ok;

jttrojan_video #(
    .SCRW   ( SCRW      ),
    .OBJW   ( OBJW      )
)
u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .game_sel   ( game_cfg[0]   ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
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
    .scr_hpos   ( scr_hpos[8:0] ),
    .scr_vpos   ( scr_vpos[8:0] ),
    .scr_ok     ( scr_ok        ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .map2_addr  ( map_addr      ), // 32kB in 8 bits or 16kW in 16 bits
    .map2_data  ( map_data      ),
    .map2_cs    ( map_cs        ),
    .map2_ok    ( map_ok        ),
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
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 14              ), // Char
    .SLOT1_AW    ( SCRW            ), // Scroll
    .SLOT2_AW    ( 14              ), // Scroll 2 Map
    .SLOT3_AW    ( SCR2W           ), // Scroll 2
    .SLOT4_AW    ( 14              ), // Sound 2
    .SLOT6_AW    ( 15              ), // Sound
    .SLOT7_AW    ( 17              ), // Main
    .SLOT8_AW    ( OBJW            ), // OBJ

    .SLOT0_DW    ( 16              ), // Char
    .SLOT1_DW    ( 16              ), // Scroll
    .SLOT2_DW    ( 16              ), // Scroll Map
    .SLOT3_DW    ( 16              ), // Scroll 2
    .SLOT4_DW    (  8              ), // Sound 2
    .SLOT6_DW    (  8              ), // Sound
    .SLOT7_DW    (  8              ), // Main
    .SLOT8_DW    ( 16              ), // OBJ

    .SLOT0_OFFSET( CHAR_OFFSET ),
    .SLOT1_OFFSET( SCR_OFFSET  ),
    .SLOT2_OFFSET( MAP_OFFSET  ),
    .SLOT3_OFFSET( SCR2_OFFSET ),
    .SLOT4_OFFSET( SND2_OFFSET ),
    .SLOT6_OFFSET( SND_OFFSET  ),
    .SLOT7_OFFSET( CPU_OFFSET  ),
    .SLOT8_OFFSET( OBJ_OFFSET  )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // Char
    .slot1_cs    ( LVBL          ), // Scroll
    .slot2_cs    ( map_cs        ), // Map
    .slot3_cs    ( LVBL          ), // Scroll 2
    .slot4_cs    ( snd2_cs       ),
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // OBJ

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr_ok        ),
    .slot2_ok    ( map_ok        ),
    .slot3_ok    ( scr2_ok       ),
    .slot4_ok    ( snd2_ok       ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( map_addr      ),
    .slot3_addr  ( scr2_addr     ),
    .slot4_addr  ( snd2_addr     ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data      ),
    .slot2_dout  ( map_data      ),
    .slot3_dout  ( scr2_data     ),
    .slot4_dout  ( snd2_data     ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
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
