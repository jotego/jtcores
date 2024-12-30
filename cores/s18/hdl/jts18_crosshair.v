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
    input  [7:0] dx,
    input  [7:0] dy,
    input        strobe,
    input        LVBL,
    input        LHBL,
    output reg [8:0] x,
    output reg [8:0] y,
    output reg   crosshair
);

reg  [8:0] hcnt, vcnt;
reg  [8:0] hcnt_max, vcnt_max;
reg  LHBLl;
wire [9:0] x_next = {1'b0, x} + {{2{dx[7]}}, dx};
wire [9:0] y_next = {1'b0, y} - {{2{dy[7]}}, dy};

wire [8:0] x_diff = hcnt - x;
wire [8:0] y_diff = vcnt - y;

always @(posedge clk) begin
    if (strobe) begin
        if (x_next[9] && dx[7])
            x <= 0;
        else if (x_next[8:0] > hcnt_max)
            x <= hcnt_max;
        else
            x <= x_next[8:0];

        if (y_next[9] && !dy[7])
            y <= 0;
        else if (y_next[8:0] > vcnt_max)
            y <= vcnt_max;
        else
            y <= y_next[8:0];
    end
end

always @(posedge clk) if (pxl_cen) begin
    LHBLl <= LHBL;
    if (!LVBL) begin
        hcnt <= 0;
        vcnt <= 0;
        if (|vcnt) vcnt_max <= vcnt;
    end
    else if (LHBLl & !LHBL) begin
        if (|hcnt) hcnt_max <= hcnt;
        hcnt <= 0;
        vcnt <= vcnt + 1'd1;
    end else if (LHBL)
        hcnt <= hcnt + 1'd1;
end

always @(posedge clk)
    crosshair <= ((x_diff[8:3] == 0 || (&x_diff[8:3] && |x_diff[2:0])) && y_diff == 0) ||
                 ((y_diff[8:3] == 0 || (&y_diff[8:3] && |y_diff[2:0])) && x_diff == 0);

endmodule
