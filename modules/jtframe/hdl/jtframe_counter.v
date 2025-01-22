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
    Date: 22-1-2025 */

module jtframe_counter #(
    parameter W=10
)(
    input  rst, clk, cen,  // keep port order
    output reg [W-1:0] cnt=0
);

always @(posedge clk) begin
    if( rst ) begin
        cnt <= 0;
    end else if(cen) begin
        cnt <= cnt+1'd1;
    end
end

endmodule