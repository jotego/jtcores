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

module jtframe_crosshair(
    input        rst,
    input        clk,
    input        pxl_cen,
    input        lvbl,
    input        lhbl,
    input        flip,
    input        draw_en,
    input  [8:0] gun_1p_x,
    input  [8:0] gun_1p_y,
    input  [8:0] gun_2p_x,
    input  [8:0] gun_2p_y,
    output [1:0] crosshair
);

`ifdef JTFRAME_LIGHTGUN
wire [8:0] hcnt, vcnt;
wire [1:0] crosshairs;

assign crosshair = draw_en ? crosshairs : 2'b0;

jtframe_crosshair_draw crosshair_left(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_1p_x  ),
    .y          ( gun_1p_y  ),
    .crosshair  ( crosshairs[0] )
);

jtframe_crosshair_draw crosshair_center(
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vcnt       ( vcnt      ),
    .x          ( gun_2p_x  ),
    .y          ( gun_2p_y  ),
    .crosshair  ( crosshairs[1] )
);

jtframe_video_counter u_vidcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( flip      ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .v          ( vcnt      ),
    .h          ( hcnt      )
);
`else 
assign crosshair = 2'b0;
`endif

endmodule