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

module jtframe_font(
    input        clk,
    input  [6:0] ascii,
    input  [2:0] v,
    output [7:0] pxl
);

wire [9:0] addr = {ascii,v};

jtframe_ram #(.AW(10),.SYNFILE("font0.hex")) u_font(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 8'd0      ),
    .addr   ( addr      ),
    .we     ( 1'b0      ),
    .q      ( pxl       )
);

endmodule