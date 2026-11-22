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
    Date: 9-8-2026 */

module jttrcdoc_colmix(
    input             clk,
    input             pxl_cen,

    input      [ 7:0] obj_pxl,
    input      [ 7:0] scr_pxl,
    input             preLHBL,
    input             preLVBL,

    // Colour PROMs
    output reg [ 7:0] pen,
    input      [ 3:0] r_data, g_data, b_data,

    output     [ 3:0] red, green, blue,
    output            LHBL, LVBL,
    input      [ 3:0] gfx_en
);

// one stage to align scr_pxl with the line buffer, one for the PROM read
parameter BLANK_DLY = 2;

wire [11:0] rgb;
reg  [ 7:0] scr_l;
wire        obj_blank;

assign obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];
assign { red, green, blue } = rgb;

always @(posedge clk) if(pxl_cen) begin
    scr_l <= gfx_en[0] ? scr_pxl : 8'd0;
    pen   <= obj_blank ? scr_l : obj_pxl;
end

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( { r_data, g_data, b_data } ),
    .rgb_out    ( rgb       )
);

endmodule
