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

    Author: Chris Watson (niknak)
    Version: 1.0
    Date: 8-8-2026 */

// Video board 171-5320: the S16A tile map generator (315-5049 x2) as
// jts16_tilemap, a per-game colour mux, the road and the sprite engine.

module jtsharrier_video(
    input              rst,
    input              clk,
    input              pxl2_cen,
    input              pxl_cen,
    input              video_en,
    input              colscr_en,   // SCONT1 from PPI0 port C (main.v)
    input              rowscr_en,   // SCONT0 from PPI0 port C (main.v)
    input              vfix_en,     // optional 'V' glyph fix, see below

    // Main CPU interface
    input              dip_pause,
    input              char_cs,
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,
    output     [15:0]  char_dout,

    input              flip,

    // Palette read port
    output     [10:0]  pal_vaddr,
    input      [15:0]  pal_vdata,

    // Road (315-5025); its control RAM is external, read through rdram_*
    output     [10:0]  rdram_addr,
    input      [15:0]  rdram_data,
    output     [13:0]  rdrom_addr,
    input      [15:0]  rdrom_data,

    // SDRAM - tile graphics and scroll maps
    input              char_ok,
    output     [16:2]  char_addr,
    input      [31:0]  char_data,
    input              map1_ok,
    output     [15:1]  map1_addr,
    input      [15:0]  map1_data,
    input              scr1_ok,
    output     [16:2]  scr1_addr,
    input      [31:0]  scr1_data,
    input              map2_ok,
    output     [15:1]  map2_addr,
    input      [15:0]  map2_data,
    input              scr2_ok,
    output     [16:2]  scr2_addr,
    input      [31:0]  scr2_data,

    // Sprite engine (315-5011/5012): object table, zoom ROM epr-6844, 1 MB
    // graphics ROM
    output     [11:1]  objdma_addr,
    input      [15:0]  objdma_dout,
    output     [12:0]  zoom_addr,
    input      [ 7:0]  zoom_data,
    input              obj_ok,
    output             obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output     [ 8:0]  vrender,
    output     [ 8:0]  hdump,      // H phase, drives main.v's VWAIT model
    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    input      [ 7:0]  st_addr,
    output     [ 7:0]  st_dout,    // tilemap status
    output     [ 7:0]  st_road,    // road status: control/hpos/color0/color1
    output             scr_bad
);

wire        preLHBL, preLVBL, hstart, flipx, shadow;
wire [ 8:0] vdump;
wire [10:0] pal_addr;
wire [11:0] obj_pxl;

// fix/sa/sb/obj report which layer the tilemap selected as opaque; none selected
// means it is transparent there and a lower layer shows.
wire [10:0] road_pxl;
wire        road_op;
wire [ 1:0] road_plycont;
wire        tm_fix, tm_sa, tm_sb, tm_obj;
// Layer order, segahang.cpp screen_update, bottom to top: ROAD_BACKGROUND,
// tilemap bg (sa/sb), tilemap fg, ROAD_FOREGROUND, sprites, text (fix). plycont
// picks the pass PER SCANLINE (segaic16_road.cpp:100): 0 draws under the scroll
// tiles, non-zero over them. The road writes every pixel, so on a foreground line
// it replaces sa/sb, while sprites and text cover it.
wire        road_fg  = road_plycont != 2'd0;
// road_op drops the warm-up pixels; without it a held pxl paints over the tiles.
wire        road_win = road_op & ~(tm_fix | tm_obj) & (road_fg | ~(tm_sa | tm_sb));

// Tilemap SDRAM addresses into the 128 kB gfx1 region. S16A has no tile bank
// register, so char (the fix layer) has zero top bits, scr's 12-bit code never
// sets tilemap bit 17 and it is dropped, and map is 1:1.
wire [13:2] tmg_char_addr;
wire [17:2] tmg_scr1_addr, tmg_scr2_addr;

// 'V' glyph fix -- OPTIONAL, off by default, and a DEVIATION from the PCB: the
// glyph for 'V' in EPR-7196/7197/7198 has its rows rotated down by one, so
// reading row (n+1)%8 gives a 'V' whose top and bottom match 'U' and 'W'. The
// fault is in the mask ROM, confirmed on the cabinet and in MAME. jts16_char
// builds char_addr as { code, row[2:0] } and is ASCII-indexed at MODEL 0, so
// 0x056 is 'V' and +1 on the low three bits wraps inside the tile without
// carrying. Done here rather than in jts16_char because that module is shared.
wire [ 2:0] vfix_row = (vfix_en && tmg_char_addr[13:5]==9'h056) ?
                        tmg_char_addr[4:2] + 3'd1 : tmg_char_addr[4:2];

assign char_addr = { 3'd0, tmg_char_addr[13:5], vfix_row };
assign scr1_addr = tmg_scr1_addr[16:2];
assign scr2_addr = tmg_scr2_addr[16:2];
assign pal_vaddr = road_win ? road_pxl : pal_addr;

jts16_tilemap #(.MODEL(0)) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .dswn       ( dsn       ),
    .char_dout  ( char_dout ),
    .vint       (           ),  // the game uses ~LVBL

    .flip       ( flip      ),
    .ext_flip   (           ),  // inout, driven by flip inside the module
    .colscr_en  ( colscr_en ),  // SCONT1 (PPI0 port C) -- high-score/attract scroll
    .rowscr_en  ( rowscr_en ),
    .alt_en     ( 1'b0      ),  // S16A alternate char layout off (jts16 MODEL 0)

    .char_ok    ( char_ok       ),
    .char_addr  ( tmg_char_addr ),
    .char_data  ( char_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .scr1_ok    ( scr1_ok       ),
    .scr1_addr  ( tmg_scr1_addr ),
    .scr1_data  ( scr1_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .scr2_ok    ( scr2_ok       ),
    .scr2_addr  ( tmg_scr2_addr ),
    .scr2_data  ( scr2_data     ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .hstart     ( hstart    ),
    .flipx      ( flipx     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .hdump      ( hdump     ),

    .obj_pxl    ( obj_pxl   ),  // sprite engine below
    .pal_addr   ( pal_addr  ),
    .shadow     ( shadow    ),
    // Text/HUD is at the very front: segahang.cpp inflates the text priority so
    // sprites never cover the high scores.
    .set_fix    ( 1'b1      ),

    .obj        ( tm_obj    ),
    .sa         ( tm_sa     ),
    .sb         ( tm_sb     ),
    .fix        ( tm_fix    ),
    .tprio      (           ),
    .s1_pri     (           ),
    .s2_pri     (           ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_dout   ),
    .scr_bad    ( scr_bad   )
);

jtsharrier_road u_road(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( HS           ),
    .vdump      ( vdump        ),

    .rdram_addr ( rdram_addr   ),
    .rdram_data ( rdram_data   ),
    .rdrom_addr ( rdrom_addr   ),
    .rdrom_data ( rdrom_data   ),

    .pxl        ( road_pxl     ),
    .pxl_op     ( road_op      ),
    .plycont    ( road_plycont ),

    .st_addr    ( st_addr      ),
    .st_dout    ( st_road      )
);

jtsharrier_obj u_obj(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),

    .tbl_addr   ( objdma_addr  ),
    .tbl_dout   ( objdma_dout  ),
    .zoom_addr  ( zoom_addr    ),
    .zoom_data  ( zoom_data    ),

    .obj_ok     ( obj_ok       ),
    .obj_cs     ( obj_cs       ),
    .obj_addr   ( obj_addr     ),
    .obj_data   ( obj_data     ),

    .flip       ( flipx        ),
    .hstart     ( hstart       ),
    .LHBL       ( ~HS          ),
    .vrender    ( vrender      ),
    .hdump      ( hdump        ),

    .pxl        ( obj_pxl      )
);

jtsharrier_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .video_en   ( video_en  ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .pal_data   ( pal_vdata ),
    .shadow     ( shadow    ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      )
);

endmodule
