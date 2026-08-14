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

    Author: Jose Tejada Gomez. Twitter: @topapate */

module jtframe_okdly #(parameter W=1)(
    input           rst,
    input           clk,
    input  [W-1:0]  cs,
    input  [W-1:0]  ok,
    output reg      ok_dly
);

always @(posedge clk) begin
    if( rst ) begin
        ok_dly <= 0;
    end else begin
        ok_dly <= |(cs & ok);
    end
end

endmodule
