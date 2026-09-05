/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-8-2026 */

module jtharier_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              video_en,
    input              preLHBL,
    input              preLVBL,
    output             LVBL,
    output             LHBL,

    input      [10:0]  tm_addr,
    input              tm_fix,
    input              tm_sa,
    input              tm_sb,
    input              tm_obj,
    input      [10:0]  road_pxl,
    input              road_op,
    input      [ 1:0]  road_plycont,

    output     [10:0]  pal_addr,
    input      [15:0]  pal_data,
    input              shadow,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,

    input      [ 3:0]  gfx_en
);

// The original board does the layer mixing via the PAL 315-5171. Here, we
// take the S16A subsystem output and mix it with the road in an equivalent way
wire [ 4:0] rpal, gpal, bpal; // palette output, before shading
wire [14:0] rgb;
reg  [14:0] rgb_shade;
wire        road_fg  = road_plycont != 2'd0;
wire        road_win = gfx_en[1] & road_op & ~(tm_fix | tm_obj) &
                       (road_fg | ~(tm_sa | tm_sb));

assign pal_addr = road_win ? road_pxl : tm_addr;
assign { red, green, blue } = rgb;


assign rpal = { pal_data[ 3:0], pal_data[12] };
assign gpal = { pal_data[ 7:4], pal_data[13] };
assign bpal = { pal_data[11:8], pal_data[14] };

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

// SHADE from 315-5171, sheet 6/7.
always @(*) begin
    rgb_shade = (shadow & ~pal_data[15]) ? { dim(rpal), dim(gpal), dim(bpal) } :
                                           {     rpal,      gpal,      bpal  };
    if( !video_en ) rgb_shade = 0;
end

jtframe_blank #(.DLY(2),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( rgb_shade ),
    .rgb_out    ( rgb       )
);

endmodule
