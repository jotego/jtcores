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
    input         gun_border_en,
    input  [ 1:0] rotate,
    input  [15:0] joyana1,
    input  [15:0] joyana2,
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

wire [1:0] strobe;

jtframe_lightgun_mux #(.W(WIDTH),.H(HEIGHT),
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) crosshair_left(
    .rst          ( rst             ),
    .clk          ( clk             ),
    .gun_border_en( gun_border_en   ),
    .rotate       ( rotate          ),
    .joyana       ( joyana1         ),
    .mouse        ( mouse_1p        ),
    .mouse_strobe ( mouse_strobe[0] ),
    .strobe       ( strobe[0]       ),
    .gun_x        ( gun_1p_x        ),
    .gun_y        ( gun_1p_y        ),
    .cross_x      ( cross1_x        ),
    .cross_y      ( cross1_y        )
);

jtframe_lightgun_mux #(.W(WIDTH),.H(HEIGHT),
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) crosshair_center(
    .rst          ( rst             ),
    .clk          ( clk             ),
    .gun_border_en( gun_border_en   ),
    .rotate       ( rotate          ),
    .joyana       ( joyana2         ),
    .mouse        ( mouse_2p        ),
    .mouse_strobe ( mouse_strobe[1] ),
    .strobe       ( strobe[1]       ),
    .gun_x        ( gun_2p_x        ),
    .gun_y        ( gun_2p_y        ),
    .cross_x      ( cross2_x        ),
    .cross_y      ( cross2_y        )
);


jtframe_crosshair_disable crosshair_disable(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .vs         ( vs              ),
    .strobe     ( strobe          ),
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

jtframe_mouse_rotation mouse_rot(
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
) crosshair_mouse(
    .clk        ( clk              ),
    .dx         ( dx               ),
    .dy         ( dy               ),
    .strobe     ( mouse_strobe_dly ),
    .x          ( mouse_x          ),
    .y          ( mouse_y          )
);

jtframe_joyana_abspos #(.W(W),.H(H)
) crosshair_joyana(
    .clk        ( clk             ),
    .joyana     ( joyana          ),
    .strobe     ( a_strobe        ),
    .x          ( joyana_x        ),
    .y          ( joyana_y        )
);

jtframe_lightgun_position #(
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) crosshair_mux(
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