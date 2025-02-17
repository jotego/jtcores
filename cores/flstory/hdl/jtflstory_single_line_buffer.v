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
    Date: 7-2-2025 */

module jtflstory_single_line_buffer(
    input         clk, pxl_cen,
                  we,
    input  [10:0] din,
    input  [ 7:0] addr,
    input  [ 8:0] hvdump,
    output [10:0] pxl
);

reg clear, opaque, opaque_we;

always @* begin
    clear  = pxl_cen & hvdump[8];
end

always @* begin
    opaque    = din[3:0] != 4'hf;
    opaque_we = we & opaque;
end    

jtframe_dual_ram #(.AW(8), .DW(11)) u_linebuf (
    .clk0       ( clk         ),
    .addr0      ( addr        ),
    .data0      ( din         ),
    .we0        ( opaque_we   ),
    .q0         (             ),
    .clk1       ( clk         ),
    .addr1      ( hvdump[7:0] ),
    .data1      ( 11'hf       ),
    .we1        ( clear       ),
    .q1         ( pxl         )
);

endmodule