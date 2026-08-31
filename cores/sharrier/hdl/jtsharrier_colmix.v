/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-8-2026 */

// Layer mixing, palette and colour output, CPU sheet 5/6. The palette RAM is
// external, so pal_data lands one pxl_cen after pal_vaddr -- what the
// jtframe_blank delay is sized for.

module jtsharrier_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              video_en,
    input              preLHBL,
    input              preLVBL,

    // Layers. fix/sa/sb/obj report which layer the tilemap selected as opaque;
    // none selected means it is transparent there and a lower layer shows.
    input      [10:0]  tm_addr,
    input              tm_fix,
    input              tm_sa,
    input              tm_sb,
    input              tm_obj,
    input      [10:0]  road_pxl,
    input              road_op,
    input      [ 1:0]  road_plycont,

    output     [10:0]  pal_vaddr,
    input      [15:0]  pal_data,
    input              shadow,

    input      [ 3:0]  gfx_en,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,
    output             LVBL,
    output             LHBL
);

// Layer order, segahang.cpp screen_update, bottom to top: ROAD_BACKGROUND,
// tilemap bg (sa/sb), tilemap fg, ROAD_FOREGROUND, sprites, text (fix). plycont
// picks the pass PER SCANLINE (segaic16_road.cpp:100): 0 draws under the scroll
// tiles, non-zero over them. The road writes every pixel, so on a foreground line
// it replaces sa/sb, while sprites and text cover it.
wire        road_fg  = road_plycont != 2'd0;
// road_op drops the warm-up pixels; without it a held pxl paints over the tiles.
// gfx_en[1] is the background-scroll toggle: four OSD bits for five planes, and
// the road shares the scroll tiles' plane -- under them on a background line,
// over them on a foreground one -- so it shares their switch. jotego's to pick.
wire        road_win = gfx_en[1] & road_op & ~(tm_fix | tm_obj) &
                       (road_fg | ~(tm_sa | tm_sb));

assign pal_vaddr = road_win ? road_pxl : tm_addr;

wire [ 4:0] rpal, gpal, bpal;
wire [14:0] rgb;
reg  [14:0] gated;

// Resistor ladder RA9-RA12, sheet 5/6.
assign rpal = { pal_data[ 3:0], pal_data[12] };
assign gpal = { pal_data[ 7:4], pal_data[13] };
assign bpal = { pal_data[11:8], pal_data[14] };

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

// /KILL sampled once per frame, at the start of active video. The board gates
// per pixel and un-blanks mid-scanline; this is a deliberate simplification,
// taken because our CPU reaches the write ~50 lines earlier in the frame.
// Reset to 0, the value Quartus powers these up at: hardware is unchanged and
// simulation stops driving x onto RGB before the first vertical edge.
reg lvbl_l, kill_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lvbl_l <= 0;
        kill_l <= 0;
    end else if( pxl_cen ) begin
        lvbl_l <= preLVBL;
        if( preLVBL & ~lvbl_l ) kill_l <= video_en;
    end
end

// SHADE from 315-5171, sheet 6/7.
always @(*) begin
    gated = (shadow & ~pal_data[15]) ? { dim(rpal), dim(gpal), dim(bpal) } :
                                       {     rpal,      gpal,      bpal  };
    if( !kill_l ) gated = 0;
end

jtframe_blank #(.DLY(2),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( gated     ),
    .rgb_out    ( rgb       )
);

assign { red, green, blue } = rgb;

endmodule
