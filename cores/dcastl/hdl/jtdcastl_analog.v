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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_analog
(
	input         clk,
	input         reset,
	input  [15:0] joyana,     // renamed from `analog` -- wire to whichever of
	                          // joyana_l1..l4 / joyana_r1..r4 this instance
	                          // decodes (see caller-wiring note above)
	output reg    right,
	output reg    left,
	output reg    down,
	output reg    up
);

wire signed [7:0] axis_x = joyana[7:0];
wire signed [7:0] axis_y = joyana[15:8];

always @(posedge clk) begin
	if (reset) begin
		right <= 0;
		left <= 0;
		down <= 0;
		up <= 0;
	end else begin
		if (axis_x >= 8'sd32) begin
			right <= 1;
			left <= 0;
		end else if (axis_x <= -8'sd32) begin
			right <= 0;
			left <= 1;
		end else begin
			if (right && (axis_x <= 8'sd20)) right <= 0;
			if (left && (axis_x >= -8'sd20)) left <= 0;
		end

		if (axis_y >= 8'sd32) begin
			down <= 1;
			up <= 0;
		end else if (axis_y <= -8'sd32) begin
			down <= 0;
			up <= 1;
		end else begin
			if (down && (axis_y <= 8'sd20)) down <= 0;
			if (up && (axis_y >= -8'sd20)) up <= 0;
		end
	end
end

endmodule
