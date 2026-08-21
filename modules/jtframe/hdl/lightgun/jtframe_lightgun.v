/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-02-2025 */

module jtframe_lightgun (
    input         rst,
    input         clk,
    input         vs,
    input  [ 7:0] debug_bus,
    input         gun_crossh_en,
    input  [ 1:0] rotate,
    input  [ 1:0] sensty,
    input  [ 3:0] game_joy1,
    input  [ 3:0] game_joy2,
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
wire       vs_edge;

jtframe_lightgun_mux #(.W(WIDTH),.H(HEIGHT),
    .XOFFSET(XOFFSET),.YOFFSET(YOFFSET)
) u_crosshair_left(
    .rst          ( rst             ),
    .clk          ( clk             ),
    .vs_edge      ( vs_edge         ),
    .debug_bus    ( debug_bus       ),
    .gun_crossh_en( gun_crossh_en   ),
    .rotate       ( rotate          ),
    .sensty       ( sensty          ),
    .game_joy     ( game_joy1       ),
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
) u_crosshair_center(
    .rst          ( rst             ),
    .clk          ( clk             ),
    .vs_edge      ( vs_edge         ),
    .debug_bus    ( debug_bus       ),
    .gun_crossh_en( gun_crossh_en   ),
    .rotate       ( rotate          ),
    .sensty       ( sensty          ),
    .game_joy     ( game_joy2       ),
    .joyana       ( joyana2         ),
    .mouse        ( mouse_2p        ),
    .mouse_strobe ( mouse_strobe[1] ),
    .strobe       ( strobe[1]       ),
    .gun_x        ( gun_2p_x        ),
    .gun_y        ( gun_2p_y        ),
    .cross_x      ( cross2_x        ),
    .cross_y      ( cross2_y        )
);


jtframe_crosshair_disable u_crosshair_disable(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .vs         ( vs              ),
    .strobe     ( strobe          ),
    .pulse      ( vs_edge         ),
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
