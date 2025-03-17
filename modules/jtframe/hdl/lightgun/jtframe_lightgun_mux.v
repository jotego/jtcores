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
    Date: 14-03-2025 */

module jtframe_lightgun_mux(
    input         rst,
    input         clk,
    input         gun_border_en,
    input  [ 1:0] rotate,
    input  [15:0] joyana,
    input  [15:0] mouse,
    input         mouse_strobe,
    output        strobe,
    output [ 8:0] gun_x,
    output [ 8:0] gun_y,
    output [ 8:0] cross_x,
    output [ 8:0] cross_y
);

parameter W = 384, H = 224, XOFFSET=0, YOFFSET=0;

wire [8:0] mouse_x, mouse_y, joyana_x, joyana_y;
wire [7:0] dx, dy;
wire       a_strobe, mouse_strobe_dly;

jtframe_mouse_rotation u_mouse_rotation(
    .clk          ( clk                 ),
    .strobe       ( mouse_strobe        ),
    .strobe_dly   ( mouse_strobe_dly    ),
    .rotate       ( rotate              ),
    .dx_in        ( mouse[ 7: 0]        ),
    .dy_in        ( mouse[15: 8]        ),
    .dx           ( dx                  ),
    .dy           ( dy                  )
);

jtframe_mouse_abspos #(.W(W),.H(H)
) u_mouse_abspos(
    .clk        ( clk              ),
    .dx         ( dx               ),
    .dy         ( dy               ),
    .strobe     ( mouse_strobe_dly ),
    .x          ( mouse_x          ),
    .y          ( mouse_y          )
);

jtframe_lightgun_scaler #(.W(W),.H(H)
) u_lightgun_scaler(
    .clk        ( clk             ),
    .joyana     ( joyana          ),
    .strobe     ( a_strobe        ),
    .x          ( joyana_x        ),
    .y          ( joyana_y        )
);

jtframe_lightgun_position #(
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) u_lightgun_position(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .gun_border_en( gun_border_en ),
    .m_x        ( mouse_x         ),
    .m_y        ( mouse_y         ),
    .m_strobe   ( mouse_strobe    ),
    .a_x        ( joyana_x        ),
    .a_y        ( joyana_y        ),
    .a_strobe   ( a_strobe        ),
    .x          ( gun_x           ),
    .y          ( gun_y           ),
    .x_abs      ( cross_x         ),
    .y_abs      ( cross_y         ),
    .strobe     ( strobe          )
);

endmodule