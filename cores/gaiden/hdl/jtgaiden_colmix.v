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
    Date: 1-1-2025 */

module jtgaiden_colmix(
    input               clk,
    input               lvbl,
    input               pxl_cen,

    output       [12:1] pal_addr,
    input        [15:0] pal_dout,

    input        [ 7:0] txt_pxl, scr2_pxl,
    input        [ 8:0] scr1_pxl,
    input        [10:0] obj_pxl,
    // Colours
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,
    // Test
    input        [ 3:0] gfx_en,
    input        [ 7:0] debug_bus
);

`include "jtgaiden_colmix.vh"

wire [4:0] sel,sel2;
wire       blend_en = sel2!=SEL_NONE;
jtgaiden_priority u_priority(
    .txt_pxl    ( txt_pxl   ),
    .scr2_pxl   ( scr2_pxl  ),
    .scr1_pxl   ( scr1_pxl  ),
    .obj_pxl    ( obj_pxl   ),
    .sel        ( sel       ),
    .sel2       ( sel2      ),
    .gfx_en     ( gfx_en    )
);

wire [ 2:0] st;
wire        latch = st==REGISTER_FINAL_COLOR;
jtframe_counter #(.W(3)) u_counter(
    .rst ( pxl_cen  ),
    .clk ( clk      ),
    .cen ( 1'b1     ),
    .cnt ( st       )
);

wire [11:0] main, other;
jtgaiden_palmux u_palmux(
    .clk        ( clk       ),
    .st         ( st        ),

    .sel        ( sel       ),
    .sel2       ( sel2      ),
    .txt_pxl    ( txt_pxl   ),
    .scr2_pxl   ( scr2_pxl  ),
    .scr1_pxl   ( scr1_pxl  ),
    .obj_pxl    ( obj_pxl   ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),

    .main       ( main      ),
    .other      ( other     )
);

wire [11:0] bgr;
jtgaiden_blender u_blender(
    .clk        ( clk       ),
    .latch      ( latch     ),
    .enable     ( blend_en  ),

    .main       ( main      ),
    .other      ( other     ),

    .blended    ( bgr       )
);

assign {blue,green,red} = bgr;

endmodule
