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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 10-8-2026 */

// Palette is 2048 entries of xRGB-555. Tiles take 0-1023, sprites 1024-2047

module jtpspike_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               LHBL,
    input               LVBL,

    input      [10:0]   pxl,

    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,
    input               transp,   // sim only: paint transparent pens cyan

    output reg [ 4:0]   red, green, blue
);

assign mix_addr = pxl;

always @(posedge clk) begin
    if( rst ) begin
        { red, green, blue } <= 0;
    end else if( pxl_cen ) begin
        { red, green, blue } <= !(LHBL & LVBL) ? 15'd0 :
                                transp ? 15'b00000_11111_11111 : mix_pal[14:0];
    end
end

endmodule
