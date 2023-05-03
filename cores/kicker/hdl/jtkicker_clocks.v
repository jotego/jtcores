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
    Date: 16-3-2022 */

module jtkicker_clocks(
    input   [31:0] status,
    // 24 MHz domain
    input          clk24,
    output         cpu4_cen,
    output         snd_cen,
    output         psg_cen,
    output         ti1_cen,
    output         ti2_cen
);

// Define JTFRAME_PLL=jtframe_pll6144 in the .def file
// so the base clock is 49.152MHz instead of 48MHz
// That will make the pixel clock 6.144 instead of 6.0

jtframe_frac_cen #(.W(4)) u_pxl_cen (
    .clk    ( clk24     ),
    .n      ( 10'd1     ),
    .m      ( 10'd4     ),
    .cen    ( {ti2_cen, ti1_cen, cpu4_cen }  ), // 1.5, 3, 6 MHz
    .cenb   (           ) // 180 shifted
);

jtframe_cen3p57 #(.CLK24(1)) u_snd_cen(
    .clk      ( clk24   ),
    .cen_3p57 ( snd_cen ),
    .cen_1p78 ( psg_cen )
);

endmodule