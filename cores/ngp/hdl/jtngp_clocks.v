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
    Date: 22-3-2022 */

module jtngp_clocks(
    input   [31:0] status,  
    // 24 MHz domain 
    input          clk24,
    output  [ 4:0] multi_cen, // from 6.144MHz to 384kHz
    // 48 MHz domain
    input          clk,
    output   [1:0] video_cen
);

wire       vsync60;
wire [3:0] cen_base;

jtframe_frac_cen #(.W(2)) u_pxl_cen (
    .clk    ( clk       ),
    .n      ( 10'd32    ),
    .m      ( 10'd125   ),
    .cen    ( video_cen ),
    .cenb   (           ) // 180 shifted
);

jtframe_frac_cen #(.W(5)) u_cpu_cen (
    .clk    ( clk24     ),
    .n      ( 10'd16    ),
    .m      ( 10'd125   ),
    .cen    ( multi_cen ),
    .cenb   (           ) // 180 shifted
);

endmodule