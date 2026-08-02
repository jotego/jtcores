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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — video top

    Instantiates the System 16A tilemap generator (jts16_tilemap MODEL 0, 3bpp),
    jts16_colmix for the Sega palette decode, the road generator and the sprite
    engine, and mixes them.

      - Scroll tile RAM lives in SDRAM (xram), written by the CPU and read back
        through map1/map2. Tile graphics come from BA2 via char/scr1/scr2.
      - Text RAM and the scroll registers are the tilemap's internal BRAM,
        reached by the CPU through char_cs.
      - Palette RAM lives inside jts16_colmix, reached through pal_cs.

    Timing comes from the tilemap's own jtframe_vtimer, 400x262. The MCU's
    vblank (INT0) is derived from preLVBL so a dip-pause cannot stall the
    interrupt path.
*/

module jtsharrier_video #(parameter CW=`JTFRAME_COLORW)(
    input                rst,
    input                clk,
    input                pxl_cen,
    input                pxl2_cen,
    input                dip_pause,
    input                colscr_en,   // PPI0 port C SCONT1 (tilemap column scroll)
    input                rowscr_en,   // PPI0 port C SCONT0 (tilemap row scroll)

    // CPU interface (main 68000)
    input                char_cs,     // 108000-108FFF text + scroll registers
    input                vfix_en,     // 'V' glyph fix (dip)
    input                pal_cs,      // 110000-110FFF palette (inside colmix)
    input       [12:1]   cpu_addr,
    input       [15:0]   cpu_dout,
    input       [ 1:0]   dsn,
    output      [15:0]   char_dout,   // text/registers readback -> main din mux
    output      [15:0]   pal_dout,    // palette readback         -> main din mux

    // SDRAM tile buses (widths match cfg/mem.yaml)
    input                char_ok,
    output      [14:2]   char_addr,   // char addr_width 15 -> [14:2]
    input       [31:0]   char_data,
    input                map1_ok,
    output      [15:1]   map1_addr,   // map1 addr_width 16 -> [15:1]
    input       [15:0]   map1_data,
    input                scr1_ok,
    output      [16:2]   scr1_addr,   // scr1 addr_width 17 -> [16:2]
    input       [31:0]   scr1_data,
    input                map2_ok,
    output      [15:1]   map2_addr,
    input       [15:0]   map2_data,
    input                scr2_ok,
    output      [16:2]   scr2_addr,
    input       [31:0]   scr2_data,

    // video output
    output      [CW-1:0] red,
    output      [CW-1:0] green,
    output      [CW-1:0] blue,
    output               HS,
    output               VS,
    output               LHBL,
    output               LVBL,

    // to MCU (INT0)
    output               vbl,

    // ---- sprite engine ----
    // sprite RAM port B (shared with the CPU port in jtsharrier_game)
    output      [11:1]   objtbl_addr,
    input       [15:0]   objtbl_dout,
    output      [15:0]   objtbl_din,
    output               objtbl_we,
    // zoom table (epr-6844, 8KB BRAM)
    output      [12:0]   zoom_addr,
    input       [ 7:0]   zoom_data,
    // sprite ROM (1MB, 32-bit)
    input                obj_ok,
    output               obj_cs,
    output      [19:2]   obj_addr,
    input       [31:0]   obj_data,

    // road GFX ROM: two 16KB plane BRAMs (R2)
    output      [13:0]   road0_addr,
    input       [15:0]   road0_data,
    // roadram CPU write snoop (for the road engine's private copy)
    input       [10:0]   rr_main_addr,
    input       [15:0]   rr_main_din,
    input       [ 1:0]   rr_main_we,
    input       [10:0]   rr_sub_addr,
    input       [15:0]   rr_sub_din,
    input       [ 1:0]   rr_sub_we,

    // live debug (see jtsharrier_obj.v for the debug_bus map)
    input       [ 3:0]   gfx_en,
    input       [ 7:0]   debug_bus,
    output      [ 7:0]   debug_view
);

// ---- tilemap <-> colmix interconnect --------------------------------------
wire [10:0] pal_addr;
wire        shadow;
// STAGE R1: road GFX shown as a backdrop under the tilemap.
wire        tm_fix, tm_sa, tm_sb, tm_obj;   // tilemap active-layer flags

// ---- unified on-screen debug map (keyboard debug_bus -> debug_view) --------
//   debug_bus[7:5]==3'b101 -> TILEMAP REGISTER PROBE:
//        st_addr=debug_bus[4:0], debug_view=st_dout (live jts16_mmr registers).
//        st_addr map: 0/1 scr1_pages lo/hi  2/3 scr2_pages  4/5 scr1_vpos
//        6/7 scr2_vpos  8/9 scr1_hpos  a/b scr2_hpos  c row/col enables.
//        e.g. 0xA8=scr1_hpos lo, 0xA9=scr1_hpos hi, 0xA4=scr1_vpos lo.
//   otherwise the OBJ engine owns debug_view (its own probe map).
wire        tm_probe   = debug_bus[7:5]==3'b101;
wire        rd_probe   = debug_bus[7:5]==3'b110;   // ROAD ROM readback probe
wire [ 7:0] tm_st_addr = { 3'd0, debug_bus[4:0] };
wire [ 7:0] tm_st_dout;
wire [ 7:0] rd_st_dout;                            // from u_road
wire [ 7:0] obj_debug_view;
// DIAGNOSTIC: set debug_bus[7:5]==3'b111 (0xE0) to force tilemap col/row scroll OFF
// live -> if the mountains (F9) reappear, column scroll was pushing them off-screen.
wire        cs_dbg_off = debug_bus[7:5]==3'b111;
wire        gfx_probe  = debug_bus[7:5]==3'b100;   // scr2 GFX readback (0x80..0x87)
wire [ 7:0] tm_gfx_dbg;
wire        road_kill_md = debug_bus[7:5]==3'b011;  // road-layer kill diagnostic
wire [ 7:0] obj_debug_bus = (tm_probe||rd_probe||cs_dbg_off||gfx_probe||road_kill_md) ? 8'd0 : debug_bus;
assign      debug_view = tm_probe  ? tm_st_dout :
                         rd_probe  ? rd_st_dout :
                         gfx_probe ? tm_gfx_dbg : obj_debug_view;
wire [10:0] road_pal;
wire        road_op, road_fg;
// The road is drawn in two passes (MAME segahang.cpp screen_update):
// ROAD_BACKGROUND before the scroll tilemaps and
// ROAD_FOREGROUND after them. Which pass a scanline belongs to is per-LINE:
// road control word roadram[y] bits[11:10] (plycont) == 0 => background,
// != 0 => foreground. jtsharrier_road exposes that as road_fg.
wire        kill_road_fg = road_kill_md & debug_bus[0];
wire        kill_road_bg = road_kill_md & debug_bus[1];
wire        road_suppress = (road_fg & kill_road_fg) | (~road_fg & kill_road_bg);
wire        road_win = road_op & ~(tm_fix | tm_obj)
                               & (road_fg | ~(tm_sa | tm_sb))
                               & ~road_suppress;
wire [10:0] mix_pal   = road_win ? road_pal : pal_addr;
wire        mix_shadow= shadow;
wire        preLHBL, preLVBL, hstart, flipx, ext_flip;
wire [11:0] obj_pxl;   // sprite engine -> tilemap mixer
wire [ 8:0] hdump, vdump, vrender;
wire        vint;

// Native tilemap SDRAM address widths, adapted to the mem.yaml buses.
wire [13:2] tm_char_addr;
wire [15:1] tm_map1_addr, tm_map2_addr;
wire [17:2] tm_scr1_addr, tm_scr2_addr;

assign char_addr = { 1'b0, tm_char_addr };   // [14:2] : pad one high bit
assign map1_addr = tm_map1_addr;
assign map2_addr = tm_map2_addr;
assign scr1_addr = tm_scr1_addr[16:2];        // drop bank bit 17 (0 for SH tile count)
assign scr2_addr = tm_scr2_addr[16:2];

// vblank interrupt to the MCU. main.v drives the 8751 int0n = ~vbl.
// This is a short pulse at the start of vblank. MAME asserts INT0 for the
// whole vblank period; widening it here disturbs the FM effect timing.
assign vbl = vint;

jtsharrier_tilemap #(.MODEL(0)) u_tilemap(
    .vfix_en    ( vfix_en      ),
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl2_cen   ( pxl2_cen     ),
    .pxl_cen    ( pxl_cen      ),

    // CPU interface
    .dip_pause  ( dip_pause    ),
    .char_cs    ( char_cs      ),
    .cpu_addr   ( cpu_addr     ),   // [12:1]
    .cpu_dout   ( cpu_dout     ),
    .dswn       ( dsn          ),
    .char_dout  ( char_dout    ),
    .vint       ( vint         ),

    // Other configuration
    .flip       ( 1'b0         ),
    .ext_flip   ( ext_flip     ),
    .colscr_en  ( colscr_en & ~cs_dbg_off ),
    .rowscr_en  ( rowscr_en & ~cs_dbg_off ),
    .alt_en     ( 1'b0         ),

    // SDRAM interface
    .char_ok    ( char_ok      ),
    .char_addr  ( tm_char_addr ),
    .char_data  ( char_data    ),
    .map1_ok    ( map1_ok      ),
    .map1_addr  ( tm_map1_addr ),
    .map1_data  ( map1_data    ),
    .scr1_ok    ( scr1_ok      ),
    .scr1_addr  ( tm_scr1_addr ),
    .scr1_data  ( scr1_data    ),
    .map2_ok    ( map2_ok      ),
    .map2_addr  ( tm_map2_addr ),
    .map2_data  ( map2_data    ),
    .scr2_ok    ( scr2_ok      ),
    .scr2_addr  ( tm_scr2_addr ),
    .scr2_data  ( scr2_data    ),

    // Video signal
    .HS         ( HS           ),
    .VS         ( VS           ),
    .preLHBL    ( preLHBL      ),
    .preLVBL    ( preLVBL      ),
    .hstart     ( hstart       ),
    .flipx      ( flipx        ),
    .hdump      ( hdump        ),
    .vdump      ( vdump        ),
    .vrender    ( vrender      ),

    // Layer mixing
    .obj_pxl    ( obj_pxl      ),   // sprite engine (jts16_prio contract)
    .pal_addr   ( pal_addr     ),
    .shadow     ( shadow       ),
    // set_fix=1 keeps the char/text layer (HUD) on top: in jts16_prio it disables
    // sprites overlaying the text layer, so the score/HUD text is never covered by
    // objects. (Was 1'b0, which let high-priority sprites draw over the HUD.)
    .set_fix    ( 1'b1         ),

    // Active-layer flags -> R1 backdrop detect
    .fix        ( tm_fix       ),
    .sa         ( tm_sa        ),
    .sb         ( tm_sb        ),
    .obj        ( tm_obj       ),
    .tprio      (              ),
    .s1_pri     (              ),
    .s2_pri     (              ),

    // Debug: F7..F10 toggle gfx_en bits -> char / scr1 / scr2 / OBJ layers
    .gfx_en     ( gfx_en       ),
    .debug_bus  ( debug_bus    ),
    .st_addr    ( tm_st_addr   ),
    .st_dout    ( tm_st_dout   ),
    .gfx_dbg    ( tm_gfx_dbg   ),
    .scr_bad    (              )
);

// ---- STAGE R2 road: real generator, sim-verified vs the MAME model ---------
jtsharrier_road u_road(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .pxl2_cen   ( pxl2_cen     ),
    // vdump, not vrender. vrender is one line ahead of vdump, and the tilemap
    // layers render from vdump, so feeding the road vrender puts it one pixel
    // high relative to everything else. Verified against MAME frame captures.
    .vrender    ( vdump        ),
    .hdump      ( hdump        ),
    .hstart     ( hstart       ),   // real start-of-line strobe
    .LHBL       ( preLHBL      ),
    .rr_main_addr(rr_main_addr ), .rr_main_din( rr_main_din ), .rr_main_we( rr_main_we ),
    .rr_sub_addr ( rr_sub_addr ), .rr_sub_din ( rr_sub_din ), .rr_sub_we ( rr_sub_we ),
    .road0_addr ( road0_addr   ), .road0_data( road0_data ),
    .st_dout    ( rd_st_dout   ),
    .road_pal   ( road_pal     ),
    .road_op    ( road_op      ),
    .road_fg    ( road_fg      ),
    .debug_bus  ( debug_bus    )
);

jts16_colmix u_colmix(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl2_cen   ( pxl2_cen       ),
    .pxl_cen    ( pxl_cen        ),

    .video_en   ( 1'b1           ),

    .preLHBL    ( preLHBL        ),
    .preLVBL    ( preLVBL        ),

    // CPU interface (palette RAM)
    .pal_cs     ( pal_cs         ),
    .cpu_addr   ( cpu_addr[11:1] ),
    .cpu_dout   ( cpu_dout       ),
    .dswn       ( dsn            ),
    .cpu_din    ( pal_dout       ),

    .pal_addr   ( mix_pal        ),
    .shadow     ( mix_shadow     ),

    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           ),
    .LVBL       ( LVBL           ),
    .LHBL       ( LHBL           )
);

// ---- sprite engine (stage 1) ----------------------------------------------
// pxl feeds jts16_tilemap.obj_pxl -> jts16_prio does the layer/priority mixing.
jtsharrier_obj u_obj(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),

    .tbl_addr   ( objtbl_addr  ),
    .tbl_dout   ( objtbl_dout  ),
    .tbl_din    ( objtbl_din   ),
    .tbl_we     ( objtbl_we    ),

    .zoom_addr  ( zoom_addr    ),
    .zoom_data  ( zoom_data    ),

    .obj_ok     ( obj_ok       ),
    .obj_cs     ( obj_cs       ),
    .obj_addr   ( obj_addr     ),
    .obj_data   ( obj_data     ),

    .flip       ( flipx        ),
    .hstart     ( hstart       ),
    .LHBL       ( preLHBL      ),
    .vrender    ( vrender      ),
    .hdump      ( hdump        ),

    .debug_bus  ( obj_debug_bus ),
    .debug_view ( obj_debug_view ),

    .pxl        ( obj_pxl      )
);

endmodule
