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
    Date: 19-10-2019 */

module jtgng_objcnt #(parameter
    OBJMAX_LINE = 6'd24
) (
    input               clk,
    input               cen /*direct_enable*/,
    input               HINIT,
    output reg [4:0]    objcnt,
    output reg [3:0]    pxlcnt
);

reg over;

always @(posedge clk) if(cen) begin
    if( HINIT )
        { over, objcnt, pxlcnt } <= { 6'd32-OBJMAX_LINE,4'd0};
    else
        if( !over )  { over, objcnt, pxlcnt } <=  { over, objcnt, pxlcnt } + 1'd1;
end

endmodule