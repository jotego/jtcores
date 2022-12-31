/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-9-2020 */

module jthige_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,
    // pixel input from generator modules
    input [3:0]     char_pxl,
    input [3:0]     obj_pxl,
    // Palette PROMs
    input   [7:0]   prog_addr,
    input           prom_pal_we,
    input   [7:0]   prom_din,

    input           preLVBL,
    input           preLHBL,
    output          LHBL,
    output          LVBL,

    output     [2:0] red,
    output     [2:0] green,
    output     [2:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter BLANK_DLY = 2;

reg  [4:0] pixel_mux;
wire       obj_blank_b  = |(~obj_pxl);

always @(*) begin
    // Object or char
    if( !obj_blank_b || !gfx_en[3])
        pixel_mux = { 1'b0, gfx_en[0]?char_pxl : 4'h0 };
    else
        pixel_mux = { 1'b1, obj_pxl };

end

wire [ 7:0] pre_rgb;
wire [ 8:0] pal_rgb;

jtframe_blank #(.DLY(BLANK_DLY),.DW(9)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .preLBL     (                     ),
    .rgb_in     ( pal_rgb             ),
    .rgb_out    ( {red, green, blue } )
);

// palette ROM
jtframe_prom #(.aw(8),.dw(8),.simfile("../../../rom/hige/hgb3.l6")) u_palette(
    .clk    ( clk                 ),
    .cen    ( pxl_cen             ),
    .data   ( prom_din            ),
    .rd_addr( { 3'd0, pixel_mux } ),
    .wr_addr( prog_addr           ),
    .we     ( prom_pal_we         ),
    .q      ( pre_rgb             )
);

assign pal_rgb = { pre_rgb[2:0], pre_rgb[5:3],  { pre_rgb[7:6], pre_rgb[7] } };

endmodule