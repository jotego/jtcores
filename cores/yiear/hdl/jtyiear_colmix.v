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
    Date: 18-12-2021 */

module jtyiear_colmix(
    input               clk,        // 48 MHz

    input               pxl_cen,

    // video inputs
    input         [3:0] obj_pxl,
    input         [3:0] scr_pxl,
    input               preLHBL,
    input               preLVBL,

    // PROMs
    input         [7:0] prog_data,
    input         [4:0] prog_addr,
    input               prog_en,

    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    output              LHBL,
    output              LVBL,
    input         [3:0] gfx_en
);

parameter BLANK_DLY=8, LOWONLY=0;

reg  [4:0] mux;
wire       obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];
wire [3:0] scr_gated = gfx_en[0] ? scr_pxl : 4'd0;

always @(posedge clk) if(pxl_cen) begin
    mux[4]   <= obj_blank & ~LOWONLY[0]; // the upper half is used as blanking in Roc'n Rope
    mux[3:0] <= obj_blank ? scr_gated : obj_pxl;
end

wire [7:0] raw, rgb;

// convert to 4-bit per component for simplicity
assign {red,green,blue} = { rgb[2:0], rgb[2], // red
                            rgb[5:3], rgb[5], // green
                         {2{rgb[7:6]}} } ;    // blue

jtframe_prom #(
    .dw     ( 8         ),
    .aw     ( 5         ),
    .simfile("407c10.1g")
) u_pal(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .rd_addr( mux       ),
    .q      ( raw       )
);


jtframe_blank #(.DLY(BLANK_DLY),.DW(8)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( raw       ),
    .rgb_out    ( rgb       )
);

endmodule