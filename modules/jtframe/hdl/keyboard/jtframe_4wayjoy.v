/*  This file is part of JT_FRAME.
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
    Date: 10-5-2020 */

module jtframe_4wayjoy(
    input            clk,
    input            rst,
    input            enable,
    input      [3:0] joy8way,
    output reg [3:0] joy4way
);

`ifndef JTFRAME_SUPPORT_4WAY
    always @(*) joy4way = joy8way;
`else
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        joy4way <= 4'd0;
    end else begin
        if( !enable ) begin
            joy4way <= joy8way;
        end else begin
            if( joy8way==4'b0001 || joy8way==4'b0010 ||
                joy8way==4'b0100 || joy8way==4'b1000 || joy8way==4'b0000 )
                joy4way <= joy8way;
        end
    end
end
`endif

endmodule