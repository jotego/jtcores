/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 26-02-2025 */

module jtframe_crosshair #(parameter COLORW=4)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               flip,
    input               draw_en,
    input               pre_lvbl,
    input               pre_lhbl,
    output              lvbl,
    output              lhbl,
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
wire [         1:0] crosshair;

jtframe_crosshair_draw crosshair_left(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_1p_x  ),
    .y          ( gun_1p_y  ),
    .crosshair  ( crosshair[0] )
);

jtframe_crosshair_draw crosshair_center(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_2p_x  ),
    .y          ( gun_2p_y  ),
    .crosshair  ( crosshair[1] )
);

jtframe_video_counter u_vidcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( flip      ),
    .lhbl       ( pre_lhbl  ),
    .lvbl       ( pre_lvbl  ),
    .v          ( vcnt      ),
    .h          ( hcnt      )
);

jtframe_crosshair_color #(.COLORW(COLORW)) crosshair_color(
    .clk        ( clk            ),
    .draw_en    ( draw_en        ),
    .crosshair  ({1'b0,crosshair}),
    .rin        ( rin            ),
    .gin        ( gin            ),
    .bin        ( bin            ),
    .rgb_cross  ( rgb_cross      )
);

jtframe_blank #(.DLY(0),.DW(COLORW*3)) u_blank(
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
`endif

endmodule