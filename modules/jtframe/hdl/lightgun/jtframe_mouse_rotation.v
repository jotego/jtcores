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
    Date: 14-03-2025 */

module jtframe_mouse_rotation(
    input            clk,
    input            strobe,
    output reg       strobe_dly,
    input      [1:0] rotate,
    input      [7:0] dx_in, dy_in,
    output reg [7:0] dx,    dy
);

always @(posedge clk) begin
    dx <= dx_in;
    dy <= dy_in;
    strobe_dly <= strobe;
    if(rotate[0]) begin
        dx <= rotate[1] ?  dy_in : -dy_in;
        dy <= rotate[1] ? -dx_in :  dx_in;
    end
end

endmodule