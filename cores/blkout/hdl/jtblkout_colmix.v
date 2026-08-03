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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 31-7-2026
*/

module jtblkout_colmix(
    input               clk,
    input               pxl_cen,
    input               LHBL,
    input               LVBL,
    input        [11:0] frontcol,
    input        [15:0] pal_data,

    // 1bpp overlay: byte from the line buffer plus the bit index within it
    input        [ 7:0] ovlb_q,
    input        [ 2:0] hovl,

    output reg   [ 3:0] red,
    output reg   [ 3:0] green,
    output reg   [ 3:0] blue
);

reg       overlay_1;
// Sample the overlay bit with the same hovl used for the byte address, then
// register once to line up with fb_pxl.
always @(posedge clk) if( pxl_cen ) overlay_1 <= ovlb_q[~hovl];   // MSB = leftmost pixel

wire [11:0] color = overlay_1 ? frontcol : pal_data[11:0];  // xBGR-444
wire blank = ~(LHBL & LVBL);
always @(posedge clk) if( pxl_cen ) begin
    if( blank ) begin red<=0; green<=0; blue<=0; end
    else begin
        red   <= color[ 3:0];
        green <= color[ 7:4];
        blue  <= color[11:8];
    end
end

endmodule