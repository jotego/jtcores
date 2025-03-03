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

module jtframe_crosshair_draw(
    input        clk,
    input  [8:0] hcnt,
    input  [8:0] vcnt,
    input  [8:0] x,
    input  [8:0] y,
    output reg   crosshair
);

wire [8:0] x_diff, y_diff;

assign x_diff = hcnt - x;
assign y_diff = vcnt - y;

always @(posedge clk)
    crosshair <= ((x_diff[8:3] == 0 || (&x_diff[8:3] && |x_diff[2:0])) && y_diff == 0) ||
                 ((y_diff[8:3] == 0 || (&y_diff[8:3] && |y_diff[2:0])) && x_diff == 0);

endmodule
