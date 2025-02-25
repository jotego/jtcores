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
    input         clk,
    input         pxl_cen,
    input  [15:0] mouse_1p,
    input  [15:0] mouse_2p,
    input  [ 1:0] mouse_strobe,
    input         LVBL,
    input         LHBL,
    output [ 8:0] gun_1p_x,
    output [ 8:0] gun_1p_y,
    output [ 8:0] gun_2p_x,
    output [ 8:0] gun_2p_y
);

`ifdef JTFRAME_LIGHTGUN
jtframe_mouse_abspos crosshair_left (
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .dx         ( mouse_1p[ 7: 0] ),
    .dy         ( mouse_1p[15: 8] ),
    .strobe     ( mouse_strobe[0] ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .x          ( gun_1p_x  ),
    .y          ( gun_1p_y  )
);

jtframe_mouse_abspos crosshair_center (
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .dx         ( mouse_2p[ 7: 0] ),
    .dy         ( mouse_2p[15: 8] ),
    .strobe     ( mouse_strobe[1] ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .x          ( gun_2p_x  ),
    .y          ( gun_2p_y  )
);

`else
assign {gun_1p_x, gun_1p_y} = 18'b0;
assign {gun_2p_x, gun_2p_y} = 18'b0;
`endif

endmodule