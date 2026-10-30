/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

module jtcps3_scene(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               ln_hs,
    input               ln_vs,
    input               ln_lvbl,
    input       [ 8:0]  ln_v,
    input       [ 9:0]  objlim,

    output      [12:2]  scn_vaddr,
    input       [31:0]  scn_vdata,

    output              tiles_rd,
    output      [22:4]  tiles_addr,
    input       [127:0] tiles_data,
    input               tiles_ok,

    output              scrmap_rd,
    output      [18:2]  scrmap_addr,
    input       [31:0]  scrmap_data,
    input               scrmap_ok,

    input       [14:0]  scene_rgb,
    output      [16:0]  scene_pxl,

    input       [ 9:0]  vb_end, vcnt_end,
    input       [ 8:0]  h_step, v_step,

    input       [ 9:0]  gscr0x,
    input       [ 9:0]  gscr0y,
    input       [ 9:0]  gscr1x,
    input       [ 9:0]  gscr1y,
    input       [ 9:0]  gscr2x,
    input       [ 9:0]  gscr2y,
    input       [ 9:0]  gscr3x,
    input       [ 9:0]  gscr3y,
    input       [ 9:0]  gscr4x,
    input       [ 9:0]  gscr4y,
    input       [ 9:0]  gscr5x,
    input       [ 9:0]  gscr5y,
    input       [ 9:0]  gscr6x,
    input       [ 9:0]  gscr6y,
    input       [ 9:0]  gscr7x,
    input       [ 9:0]  gscr7y,
    input       [15:0]  tmap0_scrx,
    input       [15:0]  tmap0_scry,
    input       [ 4:0]  tmap0_width,
    input       [ 5:0]  tmap0_ctrl,
    input       [ 6:0]  tmap0_lscr_base,
    input       [ 6:0]  tmap0_tile_base,
    input       [15:0]  tmap1_scrx,
    input       [15:0]  tmap1_scry,
    input       [ 4:0]  tmap1_width,
    input       [ 5:0]  tmap1_ctrl,
    input       [ 6:0]  tmap1_lscr_base,
    input       [ 6:0]  tmap1_tile_base,
    input       [15:0]  tmap2_scrx,
    input       [15:0]  tmap2_scry,
    input       [ 4:0]  tmap2_width,
    input       [ 5:0]  tmap2_ctrl,
    input       [ 6:0]  tmap2_lscr_base,
    input       [ 6:0]  tmap2_tile_base,
    input       [15:0]  tmap3_scrx,
    input       [15:0]  tmap3_scry,
    input       [ 4:0]  tmap3_width,
    input       [ 5:0]  tmap3_ctrl,
    input       [ 6:0]  tmap3_lscr_base,
    input       [ 6:0]  tmap3_tile_base,
    input       [ 1:0]  flip,

    output      [ 9:0]  ln_addr,
    output      [15:0]  ln_data,
    output              ln_we,
    output              ln_done,
    input       [ 3:0]  gfx_en,
    output              scan_busy
);

`ifndef NOVIDEO
localparam CMDW=96;

wire              obj_draw;
wire              scr_draw;
wire [CMDW-1:0]   cmd;
wire [ 8:0]       scan_v;
wire              scan_line_done, scan_line_busy,
                  scan_wait_linebuf;
wire              obj_busy, obj_done, scr_busy, scr_done, obj_wr_en;
wire              obj_tiles_rd, scr_tiles_rd;
wire [ 9:0]       obj_addr;
wire [22:4]       obj_tiles_addr, scr_tiles_addr;
wire [16:0]       scr_wr_pxl, obj_wr_pxl, linebuf_dout;
wire              scr_wr_en;
wire [ 9:0]       scr_addr;
wire [17:0]       render_width_prod, render_width_round;
wire [ 9:0]       render_width;

assign tiles_rd   = obj_tiles_rd | scr_tiles_rd;
assign tiles_addr = obj_tiles_rd ? obj_tiles_addr : scr_tiles_addr;
assign render_width_prod  = { 1'b0, h_step, 8'd0 } +
                            { 2'b00, h_step, 7'd0 };
assign render_width_round = render_width_prod + 18'd255;
assign render_width       = 10'd64 + render_width_round[17:8];

jtcps3_scan #(
    .CMDW( CMDW )
) u_scan(
    .rst         ( rst            ),
    .clk         ( clk            ),
    .ln_hs       ( ln_hs          ),
    .ln_vs       ( ln_vs          ),
    .ln_lvbl     ( ln_lvbl        ),
    .ln_v        ( ln_v           ),
    .vb_end      ( vb_end         ),
    .vcnt_end    ( vcnt_end       ),
    .xfer_busy   ( scan_line_busy ),
    .obj_busy    ( obj_busy       ),
    .scr_busy    ( scr_busy       ),
    .objlim      ( objlim         ),
    .v_step      ( v_step         ),
    .scan_v      ( scan_v         ),
    .scn_vaddr   ( scn_vaddr      ),
    .scn_vdata   ( scn_vdata      ),
    .obj_draw    ( obj_draw       ),
    .scr_draw    ( scr_draw       ),
    .cmd         ( cmd            ),
    .line_done   ( scan_line_done ),
    .busy        ( scan_busy      ),
    .gfx_en      ( gfx_en         )
);

jtcps3_obj #(
    .CMDW( CMDW )
) u_obj(
    .rst         ( rst            ),
    .clk         ( clk            ),
    .draw        ( obj_draw       ),
    .cmd         ( cmd            ),
    .draw_v      ( scan_v         ),
    .busy        ( obj_busy       ),
    .done        ( obj_done       ),
    .tiles_rd    ( obj_tiles_rd   ),
    .tiles_addr  ( obj_tiles_addr ),
    .tiles_data  ( tiles_data     ),
    .tiles_ok    ( tiles_ok       ),
    .buf_dout    ( linebuf_dout   ),
    .wr_en       ( obj_wr_en      ),
    .wr_addr     ( obj_addr       ),
    .wr_pxl      ( obj_wr_pxl     )
);

jtcps3_scr #(
    .CMDW( CMDW )
) u_scr(
    .rst         ( rst            ),
    .clk         ( clk            ),
    .draw        ( scr_draw       ),
    .cmd         ( cmd            ),
    .draw_v      ( scan_v         ),
    .draw_width  ( render_width    ),
    .tmap0_scrx  ( tmap0_scrx     ),
    .tmap0_scry  ( tmap0_scry     ),
    .tmap0_ctrl  ( tmap0_ctrl     ),
    .tmap0_lscr_base( tmap0_lscr_base ),
    .tmap0_tile_base( tmap0_tile_base ),
    .tmap1_scrx  ( tmap1_scrx     ),
    .tmap1_scry  ( tmap1_scry     ),
    .tmap1_ctrl  ( tmap1_ctrl     ),
    .tmap1_lscr_base( tmap1_lscr_base ),
    .tmap1_tile_base( tmap1_tile_base ),
    .tmap2_scrx  ( tmap2_scrx     ),
    .tmap2_scry  ( tmap2_scry     ),
    .tmap2_ctrl  ( tmap2_ctrl     ),
    .tmap2_lscr_base( tmap2_lscr_base ),
    .tmap2_tile_base( tmap2_tile_base ),
    .tmap3_scrx  ( tmap3_scrx     ),
    .tmap3_scry  ( tmap3_scry     ),
    .tmap3_ctrl  ( tmap3_ctrl     ),
    .tmap3_lscr_base( tmap3_lscr_base ),
    .tmap3_tile_base( tmap3_tile_base ),
    .busy        ( scr_busy       ),
    .done        ( scr_done       ),
    .tiles_rd    ( scr_tiles_rd   ),
    .tiles_addr  ( scr_tiles_addr ),
    .tiles_data  ( tiles_data     ),
    .tiles_ok    ( tiles_ok       ),
    .scrmap_rd   ( scrmap_rd      ),
    .scrmap_addr ( scrmap_addr    ),
    .scrmap_data ( scrmap_data    ),
    .scrmap_ok   ( scrmap_ok      ),
    .buf_dout    ( linebuf_dout   ),
    .wr_en       ( scr_wr_en      ),
    .wr_addr     ( scr_addr       ),
    .wr_pxl      ( scr_wr_pxl     )
);

jtcps3_linebuf u_linebuf(
    .rst         ( rst            ),
    .clk         ( clk            ),
    .pxl_cen     ( pxl_cen        ),

    .ln_hs       ( ln_hs          ),
    .ln_vs       ( ln_vs          ),
    .ln_lvbl     ( ln_lvbl        ),
    .ln_v        ( ln_v           ),
    .ln_addr     ( ln_addr        ),
    .ln_data     ( ln_data        ),
    .ln_we       ( ln_we          ),
    .ln_done     ( ln_done        ),

    .transfer    ( scan_line_done ),
    .busy        ( scan_line_busy ),

    .obj_busy    ( obj_busy       ),
    .obj_wr_en   ( obj_wr_en      ),
    .obj_addr    ( obj_addr       ),
    .obj_pxl     ( obj_wr_pxl     ),

    .scr_busy    ( scr_busy       ),
    .scr_wr_en   ( scr_wr_en      ),
    .scr_addr    ( scr_addr       ),
    .scr_pxl     ( scr_wr_pxl     ),

    .scene_rgb   ( scene_rgb      ),
    .scene_pxl   ( scene_pxl      ),

    .buf_dout    ( linebuf_dout   )
);

`else
assign scn_vaddr   = 11'd0;
assign tiles_rd    = 1'b0;
assign tiles_addr  = 19'd0;
assign scrmap_rd   = 1'b0;
assign scrmap_addr = 17'd0;
assign scene_pxl   = 17'd0;
assign ln_addr     = 10'd0;
assign ln_data     = 16'd0;
assign ln_we       = 1'b0;
assign ln_done     = 1'b0;
assign scan_busy   = 1'b0;
`endif

endmodule
