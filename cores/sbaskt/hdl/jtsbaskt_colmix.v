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
    Date: 14-11-2021 */

module jtsbaskt_colmix(
    input               clk,        // 48 MHz

    input               pxl_cen,
    input         [3:0] pal_sel,

    // video inputs
    input               scr_prio,
    input         [3:0] obj_pxl,
    input         [3:0] scr_pxl,
    input               preLHBL,
    input               preLVBL,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input         [2:0] prog_en,

    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    output              LHBL,
    output              LVBL,
    input         [3:0] gfx_en
);

wire [7:0] pal_addr;
reg  [4:0] mux, nx_mux;
wire       obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];
wire [3:0] scr_gated = gfx_en[0] ? scr_pxl : 4'd0;

assign pal_addr = { mux[4] ? 4'hf : pal_sel, mux[3:0] };

always @* begin
    // scr_prio is a guess, based on a signal going
    // into the unknown 602 chip
    nx_mux[4]   = obj_blank || !scr_prio;
    nx_mux[3:0] = nx_mux[4] ? scr_gated : obj_pxl;
end

always @(posedge clk) if(pxl_cen) begin
    mux <= nx_mux;
end

wire [11:0] raw, rgb;

assign {red,green,blue} = rgb;

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j10.a12",
) u_red(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en[0]),

    .rd_addr( pal_addr  ),
    .q      ( raw[11:8] )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j11.a13",
) u_green(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en[1]),

    .rd_addr( pal_addr  ),
    .q      ( raw[7:4]  )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j12.a14",
) u_blue(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en[2]),

    .rd_addr( pal_addr  ),
    .q      ( raw[ 3:0] )
);

jtframe_blank #(.DLY(9)) u_blank(
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