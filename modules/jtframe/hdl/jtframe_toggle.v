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
    Date: 25-1-2025 */

module jtframe_toggle #(parameter
    W            = 4,
    VALUE_AT_RST = 1'b0
)(
    input            rst,
    input            clk,

    input      [W-1:0] toggle,
    output reg [W-1:0] q
);

reg  [W-1:0] toggle_l;

integer cnt;

always @(posedge clk) begin
    if( rst ) begin
        q <= {W{VALUE_AT_RST[0]}};
        toggle_l  <= 0;
    end else begin
        toggle_l <= toggle;
        for(cnt=0; cnt<W; cnt=cnt+1)
            if( toggle[cnt] && !toggle_l[cnt] ) q[cnt] <= ~q[cnt];
    end
end

endmodule