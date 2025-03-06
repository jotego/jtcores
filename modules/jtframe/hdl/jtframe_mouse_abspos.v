/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Gyorgy Szombathelyi Copyright: Miki Saito
*/

module jtframe_mouse_abspos(
    input            clk,
    input      [7:0] dx,
    input      [7:0] dy,
    input            strobe,
    output reg [8:0] x,
    output reg [8:0] y,
    output reg [8:0] x_abs,
    output reg [8:0] y_abs
);

parameter W = 384, H = 224, XOFFSET=0, YOFFSET=0;

wire [9:0] x_next, y_next;

assign x_next = {1'b0, x_abs} + {{2{dx[7]}}, dx};
assign y_next = {1'b0, y_abs} - {{2{dy[7]}}, dy};

always @(posedge clk) begin
    x <= x_abs + XOFFSET[8:0];
    y <= y_abs + YOFFSET[8:0];
    if (strobe) begin
        if (x_next[9] && dx[7])
            x_abs <= 0;
        else if (x_next[8:0] > W[8:0])
            x_abs <= W[8:0];
        else
            x_abs <= x_next[8:0];

        if (y_next[9] && !dy[7])
            y_abs <= 0;
        else if (y_next[8:0] > H[8:0])
            y_abs <= H[8:0];
        else
            y_abs <= y_next[8:0];
    end
end

endmodule
