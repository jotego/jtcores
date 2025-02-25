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

module jts18_crosshair(
    input        clk,
    input        pxl_cen,
    input        LVBL,
    input        LHBL,
    input  [8:0] x,
    input  [8:0] y,
    output reg   crosshair
);

reg  [8:0] hcnt, vcnt;
reg  LHBLl;

wire [8:0] x_diff = hcnt - x;
wire [8:0] y_diff = vcnt - y;

always @(posedge clk) if (pxl_cen) begin
    LHBLl <= LHBL;
    if (!LVBL) begin
        hcnt <= 0;
        vcnt <= 0;
    end
    else if (LHBLl & !LHBL) begin
        hcnt <= 0;
        vcnt <= vcnt + 1'd1;
    end else if (LHBL)
        hcnt <= hcnt + 1'd1;
end

always @(posedge clk)
    crosshair <= ((x_diff[8:3] == 0 || (&x_diff[8:3] && |x_diff[2:0])) && y_diff == 0) ||
                 ((y_diff[8:3] == 0 || (&y_diff[8:3] && |y_diff[2:0])) && x_diff == 0);

endmodule
