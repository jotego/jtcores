/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-02-2025 */

module jtframe_crosshair #(parameter COLORW=4)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               flip,
    input               draw_en,
    input  [       1:0] cross_disable,
    input               pre_lvbl,
    input               pre_lhbl,
    input               pre_hs,
    input               pre_vs,
    output              lvbl,
    output              lhbl,
    output              hs,
    output              vs,
    input  [       8:0] gun_1p_x,
    input  [       8:0] gun_1p_y,
    input  [       8:0] gun_2p_x,
    input  [       8:0] gun_2p_y,
    input  [COLORW-1:0] rin,
    input  [COLORW-1:0] gin,
    input  [COLORW-1:0] bin,
    output [COLORW-1:0] rout,
    output [COLORW-1:0] gout,
    output [COLORW-1:0] bout
);

`ifdef JTFRAME_LIGHTGUN
wire [3*COLORW-1:0] rgb_cross;
wire [         8:0] hcnt, vcnt;
wire [         3:0] crosshair;

jtframe_crosshair_draw u_crosshair_left(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_1p_x  ),
    .y          ( gun_1p_y  ),
    .crosshair  ( crosshair[1:0] )
);

jtframe_crosshair_draw u_crosshair_center(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_2p_x  ),
    .y          ( gun_2p_y  ),
    .crosshair  ( crosshair[3:2] )
);

jtframe_video_counter u_vidcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( 1'b0      ),
    .lhbl       ( pre_lhbl  ),
    .lvbl       ( pre_lvbl  ),
    .v          ( vcnt      ),
    .h          ( hcnt      )
);

jtframe_crosshair_color #(.COLORW(COLORW)) u_crosshair_color(
    .clk          ( clk            ),
    .draw_en      ( draw_en        ),
    .hs_in        ( pre_hs         ),
    .vs_in        ( pre_vs         ),
    .hs_out       ( hs             ),
    .vs_out       ( vs             ),
    .cross_disable({1'b0,cross_disable}),
    .crosshair    ({2'b0,crosshair}),
    .rin          ( rin            ),
    .gin          ( gin            ),
    .bin          ( bin            ),
    .rgb_cross    ( rgb_cross      )
);

jtframe_blank #(.DLY(1),.DW(COLORW*3)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( pre_lhbl  ),
    .preLVBL    ( pre_lvbl  ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .preLBL     (           ),
    .rgb_in     ( rgb_cross ),
    .rgb_out    ( {rout,gout,bout} )
);
`else 
assign {rout,gout,bout} = {rin,gin,bin};
assign {lhbl,lvbl}      = {pre_lhbl,pre_lvbl};
assign {hs  , vs }      = {pre_hs,  pre_vs  };
`endif

endmodule
