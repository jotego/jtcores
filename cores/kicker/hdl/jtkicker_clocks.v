/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

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
    output         ti2_cen,
    // 48 MHz domain
    input          clk,
    output         pxl_cen,
    output         pxl2_cen
);

// Define JTFRAME_PLL=jtframe_pll6144 in the .def file
// so the base clock is 49.152MHz instead of 48MHz
// That will make the pixel clock 6.144 instead of 6.0

wire       vsync60;
wire [3:0] cen_base;

assign pxl2_cen = cen_base[0]; // 12.288 MHz
assign pxl_cen  = cen_base[1]; //  6.144 MHz

jtframe_frac_cen #(.W(4)) u_pxl_cen (
    .clk    ( clk       ),
    .n      ( 10'd1     ),
    .m      ( 10'd4     ),
    .cen    ( cen_base  ),
    .cenb   (           ) // 180 shifted
);

// The CPU clock is derived from the pixel clock
// but translated to the 24MHz domain 
jtframe_crossclk_cen u_cpu_cen(
    .clk_in     ( clk       ),
    .cen_in     ( pxl2_cen  ),
    .clk_out    ( clk24     ),
    .cen_out    ( cpu4_cen  )   // ~ 6MHz
);

// Sound clocks

jtframe_crossclk_cen u_ti1_cen(
    .clk_in     ( clk       ),
    .cen_in     (cen_base[2]),
    .clk_out    ( clk24     ),
    .cen_out    ( ti1_cen   )   // 3MHz
);

jtframe_crossclk_cen u_ti2_cen(
    .clk_in     ( clk       ),
    .cen_in     (cen_base[3]),
    .clk_out    ( clk24     ),
    .cen_out    ( ti2_cen   )   // 1.5MHz
);

jtframe_cen3p57 #(.CLK24(1)) u_snd_cen(
    .clk      ( clk24   ),
    .cen_3p57 ( snd_cen ),
    .cen_1p78 ( psg_cen )
);

endmodule