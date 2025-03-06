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
    Date: 25-02-2025 */

module jtframe_lightgun (
    input         rst,
    input         clk,
    input         vs,
    input  [15:0] mouse_1p,
    input  [15:0] mouse_2p,
    input  [ 1:0] mouse_strobe,
    output [ 8:0] gun_1p_x,
    output [ 8:0] gun_1p_y,
    output [ 8:0] gun_2p_x,
    output [ 8:0] gun_2p_y,
    output [ 8:0] cross1_x,
    output [ 8:0] cross1_y,
    output [ 8:0] cross2_x,
    output [ 8:0] cross2_y,
    output [ 1:0] cross_disable
);

parameter WIDTH = 384, HEIGHT = 224,
          XOFFSET= `ifdef JTFRAME_LIGHTGUN_XOFFSET `JTFRAME_LIGHTGUN_XOFFSET `else 0 `endif,
          YOFFSET= `ifdef JTFRAME_LIGHTGUN_YOFFSET `JTFRAME_LIGHTGUN_YOFFSET `else 0 `endif;

`ifdef JTFRAME_LIGHTGUN
jtframe_mouse_abspos #(.W(WIDTH),.H(HEIGHT),
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) crosshair_left (
    .clk        ( clk             ),
    .dx         ( mouse_1p[ 7: 0] ),
    .dy         ( mouse_1p[15: 8] ),
    .strobe     ( mouse_strobe[0] ),
    .x          ( gun_1p_x        ),
    .y          ( gun_1p_y        ),
    .x_abs      ( cross1_x        ),
    .y_abs      ( cross1_y        )
);

jtframe_mouse_abspos #(.W(WIDTH),.H(HEIGHT),
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) crosshair_center (
    .clk        ( clk             ),
    .dx         ( mouse_2p[ 7: 0] ),
    .dy         ( mouse_2p[15: 8] ),
    .strobe     ( mouse_strobe[1] ),
    .x          ( gun_2p_x        ),
    .y          ( gun_2p_y        ),
    .x_abs      ( cross2_x        ),
    .y_abs      ( cross2_y        )
);

jtframe_crosshair_disable crosshair_disable(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .vs         ( vs              ),
    .strobe     ( mouse_strobe    ),
    .en_b       ( cross_disable   )
);

`else
assign {gun_1p_x, gun_1p_y} = 18'b0;
assign {gun_2p_x, gun_2p_y} = 18'b0;
assign {cross1_x, cross1_y} = 18'b0;
assign {cross2_x, cross2_y} = 18'b0;
assign  cross_disable   =  2'd3;
`endif

endmodule