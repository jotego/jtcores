/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-12-2018 */

module jtgng_cen(
    input   clk,    // 24 MHz
    output  reg cen12,
    output  reg cen6,
    output  reg cen3,
    output  reg cen1p5
);

parameter CLK_SPEED = 12;
reg [3:0] cencnt=4'd0;

always @(posedge clk)
    cencnt <= cencnt+4'd1;

always @(negedge clk) begin
    // cen12  <= cencnt[  0] == 1'd0;
    if( CLK_SPEED==24 ) begin
        cen12  <= cencnt[0]   == 1'd0;
        cen6   <= cencnt[1:0] == 2'd0;
        cen3   <= cencnt[2:0] == 3'd0;
        cen1p5 <= cencnt[3:0] == 4'd0;
    end
    else if( CLK_SPEED==12 ) begin
        cen12  <= 1'b1;
        cen6   <= cencnt[0]   == 1'd0;
        cen3   <= cencnt[1:0] == 2'd0;
        cen1p5 <= cencnt[2:0] == 3'd0;
    end
end

endmodule // jtgng_cen