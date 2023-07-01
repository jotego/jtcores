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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-12-2019 */

// Input clock must be 96 MHz
// Generates various clock enable signals

module jtframe_cen96(
    input   clk,    // 96 MHz
    output  reg cen16,
    output  reg cen8,
    output  reg cen12,
    output  reg cen6,
    output  reg cen6b
);

reg [3:0] cencnt12 = 4'd0;
reg [3:0] cencnt16 = 4'd0;

always @(posedge clk) begin
    cencnt12 <= cencnt12==4'd11 ? 4'd0 : cencnt12+4'd1;
    cencnt16 <= cencnt16 + 1'd1;
end

always @(posedge clk) begin
    cen16  <= cencnt12 == 4'd0 || cencnt12 == 4'd6;
    cen8   <= cencnt12 == 4'd0;
    cen12  <= cencnt16 == 4'd0 || cencnt16 == 4'd8;
    cen6   <= cencnt16 == 4'd0;
    cen6b  <= cencnt16 == 4'd8;
end
endmodule
