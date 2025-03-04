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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 28-02-2025 */

module jtframe_countup #(
    parameter W=10
)(
    input  rst, clk, cen,  // keep port order
    output reg v=0
);

reg [W-1:0] cnt=0;

always @(posedge clk) begin
    if( rst ) begin
        cnt <= 0;
        v   <= 0;
    end else if(cen) begin
        if(!v) {v,cnt} <= {v,cnt}+1'd1;
    end
end

endmodule