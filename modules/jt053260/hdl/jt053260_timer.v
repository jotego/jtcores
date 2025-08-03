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
    Date: 1-8-2025 */

// generates a fixed frequency output used as a timer by the Z80
module jt053260_timer(
    input                    rst,
    input                    clk,
    input                    cen,
    output reg               tim2 // 2ms period for a cen&clk of 3.57 MHz
);

reg [12:0] cnt;
wire       over = cnt==7167;

always @(posedge clk) begin
    if(rst) begin
        cnt <= 0;
    end else if(cen) begin
        tim2 <= over;
        cnt  <= over ? 13'd0 : cnt+13'd1;
    end
end

endmodule