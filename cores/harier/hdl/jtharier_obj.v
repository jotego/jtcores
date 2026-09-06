/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-8-2026 */

/*  Sprite engine for the Space Harrier custom (315-5011/5012), Hang-On/Out Run
    family shape (jtoutrun_obj):

      jtharier_obj_scan  walks the object table, per-line address stepping
      jtharier_obj_draw  fetches the 32-bit sprite ROM, 8 px/word, h-shrink
      jtframe_obj_buffer   double line buffer, scanned out as obj_pxl

    Output pxl feeds jts16_tilemap.obj_pxl (contract in jts16_prio.v):
    { prio[1:0], pal[5:0], pix[3:0] }; pix==0 transparent, pal==6'h3f shadow.

    Unlike jtoutrun_obj (which double-buffers a private 2 kB table), the object
    table is the CPU-visible, scene-restorable `objram` in mem.yaml, read here
    through its `obj` port (tbl_addr/tbl_dout). The scanner keeps the per-line
    running address privately, so it needs no write-back to that RAM.
*/

module jtharier_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    output     [11:1]  tbl_addr,
    input      [15:0]  tbl_dout,

    // Zoom table ROM epr-6844
    output     [12:0]  zoom_addr,
    input      [ 7:0]  zoom_data,

    // Sprite ROM (1 MB = 8 banks x 0x20000, 32-bit reads)
    input              obj_ok,
    output             obj_cs,
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,

    input              flip,
    input              hstart,
    input              LHBL,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,

    output     [11:0]  pxl
);

wire        dr_start, dr_busy;
wire [ 8:0] dr_xpos;
wire [15:0] dr_offset;   // [15] = hflip
wire [ 2:0] dr_bank;
wire        dr_prio;
wire [ 5:0] dr_pal;
wire        dr_shadow;
wire [ 6:0] dr_hzoom;

wire [11:0] bf_data;
wire [ 8:0] bf_addr;
wire        bf_we;

jtharier_obj_scan u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .vrender    ( vrender   ),
    .hstart     ( hstart    ),

    .tbl_addr   ( tbl_addr  ),
    .tbl_dout   ( tbl_dout  ),
    .zoom_addr  ( zoom_addr ),
    .zoom_data  ( zoom_data ),

    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),
    .dr_xpos    ( dr_xpos   ),
    .dr_offset  ( dr_offset ),
    .dr_bank    ( dr_bank   ),
    .dr_prio    ( dr_prio   ),
    .dr_pal     ( dr_pal    ),
    .dr_shadow  ( dr_shadow ),
    .dr_hzoom   ( dr_hzoom  )
);

jtharier_obj_draw u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .hstart     ( hstart    ),

    .start      ( dr_start  ),
    .busy       ( dr_busy   ),
    .xpos       ( dr_xpos   ),
    .offset     ( dr_offset ),
    .bank       ( dr_bank   ),
    .sh_prio    ( dr_prio   ),
    .pal        ( dr_pal    ),
    .shadow     ( dr_shadow ),
    .hzoom      ( dr_hzoom  ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    .bf_data    ( bf_data   ),
    .bf_we      ( bf_we     ),
    .bf_addr    ( bf_addr   )
);

// Line-buffer scan-out. The sharrier device origin is (189,-1) (sega16sp.cpp),
// so HOBJ_START = 189 reads device x 189 out on column 0, and HOBJ_FLIP = 508 is
// the same column flipped -- the buffer's own flip pivots on 511, the wrong point
// for a 189..508 window. HB_END must track jts16_tilemap's parameter of the same
// name, so the reload lands one pixel before active video. A uniform sprite shift
// is registration, not logic: move these by the observed pixel count.
localparam [8:0] HB_END     = 9'h0bf;
localparam [8:0] HOBJ_START = 9'h0bd;
localparam [8:0] HOBJ_FLIP  = 9'h1fc;

// hobj must free-run through blanking, not park on HOBJ_START:
// jtframe_obj_buffer erases each entry as it is read, so parking would wipe
// column 0 every line.
reg [8:0] hobj;
always @(posedge clk) if( pxl_cen ) begin
    if( hdump==HB_END )
        hobj <= flip ? HOBJ_FLIP : HOBJ_START;
    else
        hobj <= flip ? hobj - 1'd1 : hobj + 1'd1;
end

// ALPHA=0 over the low 4 bits: pix 0 transparent, the jts16_prio contract.
jtframe_obj_buffer #(
    .DW     ( 12    ),
    .AW     (  9    ),
    .ALPHAW (  4    ),
    .ALPHA  ( 32'd0 )
) u_buffer(
    .clk     ( clk      ),
    .LHBL    ( LHBL     ),
    .flip    ( 1'b0     ),   // handled by the hobj direction above

    .wr_data ( bf_data  ),
    .wr_addr ( bf_addr  ),
    .we      ( bf_we    ),

    .rd_addr ( hobj     ),
    .rd      ( pxl_cen  ),
    .rd_data ( pxl      )
);

endmodule
