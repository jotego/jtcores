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
    Date: 15-10-2019 */

// Generates a 3.57 MHz clock enable signal for a 48MHz clock
// Result: 105/1408 = 3,579,545.5 MHz, off by 0.5Hz (0.14ppm) :-)

module jtgng_cenp384(
    input      clk,       // 48 MHz
    output reg cen_p384
);

reg  [6:0] cencnt=7'd0;

always @(negedge clk) begin
    cen_p384 <= 1'b0;
    cencnt <= cencnt+7'd1;
    if( cencnt >= 7'd124 ) begin
        cencnt   <= 7'd0;
        cen_p384 <= 1'b1;
    end
end

endmodule // jtgng_cen