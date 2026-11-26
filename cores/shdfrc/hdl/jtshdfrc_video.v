/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-11-2026 */

module jtshdfrc_video #(parameter BG_START = 9'd160)(
    input                rst,
    input                clk,
    input                pxl_cen,

    output reg           line_start,
    output reg    [ 8:0] vpos,

    output        [13:1] bg_addr,
    output        [12:1] fg_rd_addr, spr_rd_addr,
    output        [14:1] pal_rd_addr,
    input         [15:0] bg_data, fg_rd_data, spr_rd_data, pal_rd_data,
    output               spr_copy_busy,
    input                spr_copy_ok,

    input         [ 8:0] scrx0, scry0, scrx1, scry1,
    input                video_en,
    input         [ 7:0] brt,

    output        [20:2] scr_addr,
    output               scr_cs,
    input                scr_ok,
    input         [31:0] scr_data,
    output        [19:2] scr2_addr,
    output               scr2_cs,
    input                scr2_ok,
    input         [31:0] scr2_data,

    output        [22:2] obj_addr,
    output               obj_cs,
    input                obj_ok,
    input         [31:0] obj_data,
    output        [20:1] obj4_addr,
    output               obj4_cs,
    input                obj4_ok,
    input         [15:0] obj4_data,

    output        [16:0] fgrom_addr,
    output               fgrom_cs,
    input                fgrom_ok,
    input         [ 7:0] fgrom_data,

    output               LHBL,
    output               LVBL,
    output               HS,
    output reg           VS,
    output        [ 7:0] red,
    output        [ 7:0] green,
    output        [ 7:0] blue,
    input         [ 3:0] gfx_en,

    output        [ 2:0] busy
);

localparam [8:0] HLAST = 9'd447, VLAST = 9'd271;
wire [8:0] hcnt, vcnt, vrender;
reg  [8:0] rline;
wire       line_wrap = pxl_cen && hcnt==HLAST;
wire       vs_pending;

jtframe_vtimer #(
    .HB_START ( 9'd319 ),
    .HB_END   ( HLAST  ),
    .HS_START ( 9'd351 ),
    .HS_END   ( 9'd383 ),
    .HCNT_END ( HLAST  ),
    .VB_START ( 9'd247 ),
    .VB_END   ( 9'd7   ),
    .VS_START ( 9'd251 ),
    .VS_END   ( 9'd254 ),
    .VCNT_END ( VLAST  ),
    .H_VB     ( HLAST  ),
    .H_VNEXT  ( HLAST  )
) u_vtimer(
    .clk      ( clk        ),
    .pxl_cen  ( pxl_cen    ),
    .vdump    ( vcnt       ),
    .vrender  ( vrender    ),
    .vrender1 (            ),
    .H        ( hcnt       ),
    .Hinit    (            ),
    .Vinit    (            ),
    .LHBL     ( LHBL       ),
    .LVBL     ( LVBL       ),
    .HS       ( HS         ),
    .VS       ( vs_pending )
);

always @(posedge clk) begin
    line_start <= line_wrap;
    vpos       <= vcnt;
    rline      <= vrender;
    if( line_wrap ) VS <= vs_pending;
end

wire [ 9:0] lb_ra = { vcnt[0], hcnt };
wire [ 7:0] lfg;
wire [ 9:0] lbg1;
wire [10:0] lbg0, lobj;
wire        ob_clr;

jtshdfrc_char u_char(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .line_start ( line_start ),
    .rline      ( rline      ),
    .lb_ra      ( lb_ra      ),
    .fg_rd_addr ( fg_rd_addr ),
    .fg_rd_data ( fg_rd_data ),
    .fgrom_addr ( fgrom_addr ),
    .fgrom_cs   ( fgrom_cs   ),
    .fgrom_ok   ( fgrom_ok   ),
    .fgrom_data ( fgrom_data ),
    .lfg        ( lfg        ),
    .busy       ( busy[0]    )
);

jtshdfrc_scroll u_scroll(
    .rst        ( rst                       ),
    .clk        ( clk                       ),
    .draw_start ( pxl_cen && hcnt==BG_START ),
    .rline      ( rline                     ),
    .lb_ra      ( lb_ra                     ),
    .scrx0      ( scrx0                     ),
    .scry0      ( scry0                     ),
    .scrx1      ( scrx1                     ),
    .scry1      ( scry1                     ),
    .bg_addr    ( bg_addr                   ),
    .bg_data    ( bg_data                   ),
    .scr_addr   ( scr_addr                  ),
    .scr_cs     ( scr_cs                    ),
    .scr_ok     ( scr_ok                    ),
    .scr_data   ( scr_data                  ),
    .scr2_addr  ( scr2_addr                 ),
    .scr2_cs    ( scr2_cs                   ),
    .scr2_ok    ( scr2_ok                   ),
    .scr2_data  ( scr2_data                 ),
    .lbg0       ( lbg0                      ),
    .lbg1       ( lbg1                      ),
    .busy       ( busy[2]                   )
);

jtshdfrc_obj u_obj(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .line_start    ( line_start    ),
    .vcnt          ( vcnt          ),
    .rline         ( rline         ),
    .lb_ra         ( lb_ra         ),
    .ob_clr        ( ob_clr        ),
    .spr_rd_addr   ( spr_rd_addr   ),
    .spr_rd_data   ( spr_rd_data   ),
    .spr_copy_busy ( spr_copy_busy ),
    .spr_copy_ok   ( spr_copy_ok   ),
    .obj_addr      ( obj_addr      ),
    .obj_cs        ( obj_cs        ),
    .obj_ok        ( obj_ok        ),
    .obj_data      ( obj_data      ),
    .obj4_addr     ( obj4_addr     ),
    .obj4_cs       ( obj4_cs       ),
    .obj4_ok       ( obj4_ok       ),
    .obj4_data     ( obj4_data     ),
    .lobj          ( lobj          ),
    .busy          ( busy[1]       )
);

jtshdfrc_colmix u_colmix(
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .video_en    ( video_en    ),
    .gfx_en      ( gfx_en      ),
    .brt         ( brt         ),
    .lfg         ( lfg         ),
    .lbg1        ( lbg1        ),
    .lbg0        ( lbg0        ),
    .lobj        ( lobj        ),
    .ob_clr      ( ob_clr      ),
    .pal_rd_addr ( pal_rd_addr ),
    .pal_rd_data ( pal_rd_data ),
    .red         ( red         ),
    .green       ( green       ),
    .blue        ( blue        )
);

endmodule
