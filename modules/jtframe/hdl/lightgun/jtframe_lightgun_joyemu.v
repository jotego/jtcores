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
    Date: 02-10-2025 */

module jtframe_lightgun_joyemu(
    input            clk,
    input            vs_edge,
    output           strobe,
    input      [1:0] rotate,
    input      [1:0] sensty,
    input      [3:0] game_joy,
    input      [7:0] debug_bus,
    output     [8:0] x, y
);

parameter W = 384, H = 224;

reg  [7:0] dx_in, dy_in;
wire [7:0] dx, dy;
reg  [6:0] base_val;
reg        joystr;
wire       joy_on;

assign joy_on   = |game_joy;

always @(*) begin
    base_val =  7'h7 /*+ debug_bus[6:0]*/;
    case (sensty)
        1: base_val = base_val + 7'h2;
        0: base_val = base_val + 7'h0;
        3: base_val = base_val - 7'h2;
        2: base_val = base_val - 7'h4;
        default :;
    endcase
end

always @(posedge clk) begin
    joystr <= 0;
    if(vs_edge) begin
        joystr <= joy_on;
        {dx_in, dy_in} <= 0;
        if(game_joy[0]) dx_in <= {1'b0, base_val};
        if(game_joy[1]) dx_in <= {1'b1,-base_val};
        if(game_joy[2]) dy_in <= {1'b1,-base_val};
        if(game_joy[3]) dy_in <= {1'b0, base_val};
    end
end

jtframe_mouse_rotation u_rotation(
    .clk        ( clk      ),
    .strobe     ( joystr   ),
    .strobe_dly ( strobe   ),
    .rotate     ( rotate   ),
    .dx_in      ( dx_in    ),
    .dy_in      ( dy_in    ),
    .dx         ( dx       ),
    .dy         ( dy       )
);

jtframe_mouse_abspos #(.W(W),.H(H)
) u_abspos(
    .clk        ( clk      ),
    .dx         ( dx       ),
    .dy         ( dy       ),
    .strobe     ( strobe   ),
    .x          ( x        ),
    .y          ( y        )
);


endmodule