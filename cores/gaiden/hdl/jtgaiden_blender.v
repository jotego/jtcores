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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-3-2025 */

// blends two colors by simply averaging the RGB signals
module jtgaiden_blender(
    input          clk,
    input          latch,

    input   [11:0] main, other,
    input          enable,

    output reg [11:0] blended
);

reg [11:0] mix;

function [3:0] avg(input [3:0]a,b); begin
    reg [4:0] sum;
    sum = {1'b0,a}+{1'b0,b};
    avg = sum[4:1];
end endfunction

always @* begin
    mix = {avg(main[8+:4],other[8+:4]),
           avg(main[4+:4],other[4+:4]),
           avg(main[0+:4],other[0+:4])};
end

always @(posedge clk) if(latch) blended <= enable ? mix : main;

endmodule