/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner video: three scrolling tilemaps, a sprite line buffer and the
 * priority mixer, all driven from a 7 MHz pixel enable.
 *
 * The raster is the one the game programs into its HD6845S: 446 pixels per
 * line, 320 visible, 286 lines per frame, 240 visible (54.878 Hz).
 *
 * Layer semantics follow MAME's twincobr_v.cpp / toaplan_scu.cpp, which is
 * the reference the bench diffs against:
 *   - a tilemap pixel at screen (x,y) comes from pixmap column x+55+scrollx
 *     and row y+30+scrolly, wrapping at the map size;
 *   - the background is opaque, foreground and text are transparent on pen 0;
 *   - sprites are ordered so that entry 0 ends on top. A sprite pixel is
 *     hidden by the foreground and text layers according to its 2-bit
 *     priority, but only where it is the first sprite to touch that pixel:
 *     MAME marks every touched pixel as priority 31 whether it drew or not,
 *     after which nothing blocks later sprites there. The line buffer keeps a
 *     "multi" bit per pixel to reproduce that.
 *
 * Sprites are taken from a copy of the object RAM made when vertical
 * blanking starts, like the buffered sprite RAM on the board.
 *
 * Pipeline: a pixel's layer data is valid while hdump holds its position;
 * the mixer registers the palette address on the next pixel enable and the
 * colour on the one after, so red/green/blue lag hdump by two pixels.
 *
 * Screen flip mirrors the three tilemaps, as MAME's flipscreen_w does by
 * setting TILEMAP_FLIPX|TILEMAP_FLIPY on all of them. Mirroring the pixmap
 * and switching to the second scroll offsets (-134, -243) collapses into one
 * coordinate remap, so only the traversal direction changes: see the note in
 * jtwardner_tile. Sprites are left alone, because the sprite generator never
 * reads the screen flip - MAME's behaviour, which the bench diffs against.
 */

module jtwardner_video(
    input             rst,
    input             clk,
    input             pxl_cen,          // 7 MHz

    // registers from the main CPU
    input      [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry,
    input             flip, bg_bank, fg_bank, video_on,
    input      [ 3:0] gfx_en,           // OSD debug: 0 text, 1 bg, 2 fg, 3 sprites

    // video RAM read ports (registered, one clock of latency)
    output     [10:0] tx_vaddr,  input [15:0] tx_vq,
    output     [12:0] bg_vaddr,  input [15:0] bg_vq,
    output     [11:0] fg_vaddr,  input [15:0] fg_vq,
    output     [10:0] pal_vaddr, input [15:0] pal_vq,
    output     [10:0] obj_vaddr, input [15:0] obj_vq,

    // graphics ROMs: one tile row per 32-bit word, a byte per plane (byte 0 is
    // plane 0), MSB is the leftmost pixel. Address is {tile, row} for 8x8
    // tiles and {sprite, row, half} for 16x16 sprites. rom_ok must drop as
    // soon as the address changes and rise once the data matches it.
    output     [13:0] char_addr, input [31:0] char_data, output char_cs, input char_ok,
    output     [15:0] fg_addr,   input [31:0] fg_data,   output fg_cs,   input fg_ok,
    output     [14:0] bg_addr,   input [31:0] bg_data,   output bg_cs,   input bg_ok,
    output     [15:0] obj_addr,  input [31:0] obj_data,  output obj_cs,  input obj_ok,

    output            LVBL, LHBL, HS, VS,
    output     [ 8:0] hdump, vdump,
    output     [ 4:0] red, green, blue,
    output            obj_ovf           // a line ran out of sprite time (sticky)
);

wire [8:0] vrender, vrender1;
wire       Hinit, Vinit;

// ---- raster
jtframe_vtimer #(
    .HB_START ( 9'd319 ), .HB_END   ( 9'd445 ), .HCNT_END ( 9'd445 ),
    .HS_START ( 9'd352 ), .HS_END   ( 9'd382 ),
    .VB_START ( 9'd239 ), .VB_END   ( 9'd285 ), .VCNT_END ( 9'd285 ),
    .VS_START ( 9'd248 ), .VS_END   ( 9'd256 )
) u_vtimer(
    .clk      ( clk       ), .pxl_cen  ( pxl_cen   ),
    .vdump    ( vdump     ), .vrender  ( vrender   ), .vrender1 ( vrender1  ),
    .H        ( hdump     ), .Hinit    ( Hinit     ), .Vinit    ( Vinit     ),
    .LHBL     ( LHBL      ), .LVBL     ( LVBL      ), .HS       ( HS        ),
    .VS       ( VS        )
);

// The tile engines run over the visible 320 pixels and the last 16 counts of
// the blanking, so the first tile of a line is ready before it is needed.
// heff is the horizontal position as the engines see it, -16..319 (mod 512).
wire [8:0] heff = hdump >= 9'd430 ? hdump - 9'd446 : hdump;
wire       hact = hdump <  9'd320 || hdump >= 9'd430;

// ---- tilemaps, each pixel is {palette, pen}
wire [7:0] bg_pxl, fg_pxl;
wire [8:0] tx_pxl;

jtwardner_tile #(.VA(13),.MAP_VW(9),.CW(12),.PALW(4),.ROMAW(15),.BANK_VRAM(1)) u_bg(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(bg_scrx[8:0]), .scry(bg_scry[8:0]),
    .flip(flip), .bank(bg_bank), .vram_addr(bg_vaddr), .vram_q(bg_vq),
    .rom_addr(bg_addr), .rom_data(bg_data), .rom_cs(bg_cs), .rom_ok(bg_ok),
    .pxl(bg_pxl)
);
// the foreground bank selects tiles 4096-8191, which Wardner does not have;
// the ROM wraps the address the way MAME's code % total does
jtwardner_tile #(.VA(12),.MAP_VW(9),.CW(12),.PALW(4),.ROMAW(16),.BANK_CODE(1)) u_fg(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(fg_scrx[8:0]), .scry(fg_scry[8:0]),
    .flip(flip), .bank(fg_bank), .vram_addr(fg_vaddr), .vram_q(fg_vq),
    .rom_addr(fg_addr), .rom_data(fg_data), .rom_cs(fg_cs), .rom_ok(fg_ok),
    .pxl(fg_pxl)
);
jtwardner_tile #(.VA(11),.MAP_VW(8),.CW(11),.PALW(5),.ROMAW(14),.BPP(3)) u_tx(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(tx_scrx[8:0]), .scry(tx_scry[7:0]),
    .flip(flip), .bank(1'b0), .vram_addr(tx_vaddr), .vram_q(tx_vq),
    .rom_addr(char_addr), .rom_data(char_data), .rom_cs(char_cs), .rom_ok(char_ok),
    .pxl(tx_pxl)
);

// ---- sprites
wire [12:0] obj_pxl;                    // {multi, prio[1:0], colour[5:0], pen[3:0]}

jtwardner_obj u_obj(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .LVBL(LVBL), .hdump(hdump), .vrender(vrender),
    .ram_addr(obj_vaddr), .ram_q(obj_vq),
    .rom_addr(obj_addr), .rom_data(obj_data), .rom_cs(obj_cs), .rom_ok(obj_ok),
    .pxl(obj_pxl), .ovf(obj_ovf)
);

// ---- mixer, then palette
jtwardner_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    .video_on   ( video_on  ),
    .gfx_en     ( gfx_en    ),
    .bg_pxl     ( bg_pxl    ),
    .fg_pxl     ( fg_pxl    ),
    .tx_pxl     ( tx_pxl    ),
    .obj_pxl    ( obj_pxl   ),
    .pal_vaddr  ( pal_vaddr ),
    .pal_vq     ( pal_vq    ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
