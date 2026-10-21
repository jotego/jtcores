/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_video #(
    parameter OBJECTS=1, LANDSCAPE=1, ROAD=1
)(
    input rst,
    input clk,
    input pxl_cen,
    input [9:0] text_scroll_y,
    input [15:0] control,
    input road_enable,
    input [7:0] road_top,
    input [15:0] road_yclip,
    input road_bank,
    output [11:1] road_ctrl_addr,
    input [15:0] road_ctrl_data,
    output [11:1] road_pixel_addr,
    input [15:0] road_pixel_data,
    output [11:1] road_color_addr,
    input [15:0] road_color_data,
    input [15:0] bg_back_x,
    input [15:0] bg_scroll_x,
    input [15:0] bg_scroll_y,
    output [16:0] bg_gfx_addr,
    input [7:0] bg_gfx_data,
    output [13:1] objram_addr,
    input [15:0] objram_data,
    output [8:1] obj_ctrl_addr,
    input [15:0] obj_ctrl_data,
    output [19:2] sprites_l_addr,
    output sprites_l_cs,
    input [31:0] sprites_l_data,
    input sprites_l_ok,
    output [19:2] sprites_h_addr,
    output sprites_h_cs,
    input [31:0] sprites_h_data,
    input sprites_h_ok,
    output obj_overflow,
    output [13:1] txmap_addr,
    input [15:0] txmap_data,
    output [16:0] tx_gfx_addr,
    input [7:0] tx_gfx_data,
    output [10:1] palette_video_addr,
    input [15:0] palette_video_data,
    output [4:0] red,
    output [4:0] green,
    output [4:0] blue,
    output reg LHBL,
    output reg LVBL,
    output reg HS,
    output reg VS
);

wire [8:0] h, v;
wire [6:0] text_pxl;
wire vt_lhbl, vt_lvbl, vt_hs, vt_vs;
reg blank_sh;

jtframe_vtimer #(
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd271 ),
    .VS_START ( 9'd244 ),
    .VS_END   ( 9'd248 ),
    .HB_START ( 9'd319 ),
    .HB_END   ( 9'd399 ),
    .HS_START ( 9'd336 ),
    .HS_END   ( 9'd367 ),
    .H_VNEXT  ( 9'd399 )
) u_vtimer (
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .vdump    ( v       ),
    .vrender  (         ),
    .vrender1 (         ),
    .H        ( h       ),
    .Hinit    (         ),
    .Vinit    (         ),
    .LHBL     ( vt_lhbl ),
    .LVBL     ( vt_lvbl ),
    .HS       ( vt_hs   ),
    .VS       ( vt_vs   )
);

jtroundu_text u_text (
    .rst      ( rst           ),
    .clk      ( clk           ),
    .pxl_cen  ( pxl_cen       ),
    .h        ( h             ),
    .v        ( v             ),
    .scroll_y ( text_scroll_y ),
    .map_addr ( txmap_addr    ),
    .map_data ( txmap_data    ),
    .gfx_addr ( tx_gfx_addr   ),
    .gfx_data ( tx_gfx_data   ),
    .pxl      ( text_pxl      )
);

wire [9:0] obj_pxl;
wire [8:0] bg_pxl;
wire bg_solid;
wire [8:0] road_pxl;
wire road_solid;

generate
    if (ROAD) begin : g_road
        jtroundu_road u_road (
            .rst        ( rst             ),
            .clk        ( clk             ),
            .pxl_cen    ( pxl_cen         ),
            .h          ( h               ),
            .v          ( v               ),
            .enable     ( road_enable     ),
            .top        ( road_top        ),
            .yclip      ( road_yclip      ),
            .bank       ( road_bank       ),
            .ctrl_addr  ( road_ctrl_addr  ),
            .ctrl_data  ( road_ctrl_data  ),
            .pixel_addr ( road_pixel_addr ),
            .pixel_data ( road_pixel_data ),
            .color_addr ( road_color_addr ),
            .color_data ( road_color_data ),
            .pxl        ( road_pxl        ),
            .solid      ( road_solid      )
        );
    end else begin : g_no_road
        assign road_ctrl_addr = 0;
        assign road_pixel_addr = 0;
        assign road_color_addr = 0;
        assign road_pxl = 0;
        assign road_solid = 0;
    end
    if (OBJECTS) begin : g_objects
        jtroundu_obj u_obj (
            .rst        ( rst            ),
            .clk        ( clk            ),
            .pxl_cen    ( pxl_cen        ),
            .h          ( h              ),
            .v          ( v              ),
            .ram_addr   ( objram_addr    ),
            .ram_data   ( objram_data    ),
            .ctrl_addr  ( obj_ctrl_addr  ),
            .ctrl_data  ( obj_ctrl_data  ),
            .rom_l_addr ( sprites_l_addr ),
            .rom_l_cs   ( sprites_l_cs   ),
            .rom_l_data ( sprites_l_data ),
            .rom_l_ok   ( sprites_l_ok   ),
            .rom_h_addr ( sprites_h_addr ),
            .rom_h_cs   ( sprites_h_cs   ),
            .rom_h_data ( sprites_h_data ),
            .rom_h_ok   ( sprites_h_ok   ),
            .pxl        ( obj_pxl        ),
            .overflow   ( obj_overflow   )
        );
    end else begin : g_no_objects
        assign obj_pxl = 0;
        assign obj_overflow = 0;
        assign objram_addr = 0;
        assign obj_ctrl_addr = 0;
        assign sprites_l_addr = 0;
        assign sprites_h_addr = 0;
        assign sprites_l_cs = 0;
        assign sprites_h_cs = 0;
    end
    if (LANDSCAPE) begin : g_landscape
        jtroundu_bg u_bg (
            .rst      ( rst         ),
            .clk      ( clk         ),
            .pxl_cen  ( pxl_cen     ),
            .h        ( h           ),
            .v        ( v           ),
            .back_x   ( bg_back_x   ),
            .scroll_x ( bg_scroll_x ),
            .scroll_y ( bg_scroll_y ),
            .gfx_addr ( bg_gfx_addr ),
            .gfx_data ( bg_gfx_data ),
            .pxl      ( bg_pxl      ),
            .solid    ( bg_solid    )
        );
    end else begin : g_no_landscape
        assign bg_pxl = 0;
        assign bg_solid = 0;
        assign bg_gfx_addr = 0;
    end
endgenerate

jtroundu_colmix u_colmix (
    .rst                ( rst                 ),
    .clk                ( clk                 ),
    .pxl_cen            ( pxl_cen             ),
    .blank_n            ( blank_sh            ),
    .obj_top            ( control[7]          ),
    .text_pxl           ( text_pxl            ),
    .obj_pxl            ( obj_pxl             ),
    .bg_pxl             ( bg_pxl              ),
    .bg_solid           ( bg_solid            ),
    .road_pxl           ( road_pxl            ),
    .road_solid         ( road_solid          ),
    .palette_video_addr ( palette_video_addr  ),
    .palette_video_data ( palette_video_data  ),
    .red                ( red                 ),
    .green              ( green               ),
    .blue               ( blue                )
);

always @(posedge clk) begin
    if (rst) begin
        blank_sh <= 0;
        LHBL <= 0;
        LVBL <= 0;
        HS <= 0;
        VS <= 0;
    end else if (pxl_cen) begin
        blank_sh <= vt_lhbl & vt_lvbl;
        LHBL <= vt_lhbl;
        LVBL <= vt_lvbl;
        HS <= vt_hs;
        VS <= vt_vs;
    end
end

endmodule
