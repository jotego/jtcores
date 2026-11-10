`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

`timescale 1ns/1ps

module jtpopeye_colmix_2020(
    input              rst_n,
    input              clk,
    input              pxl2_cen,    // object pixel clock
    input   [2:0]      gfx_en,
    // PROM programming
    input   [7:0]      prog_addr,
    input              prom_4a_we,
    input              prom_5b_we,
    input              prom_5a_we,
    input              prom_3a_we,
    input   [7:0]      prom_din,
    // mixing
    input              HBD_n,
    input              VB_n,
    output reg         LHBL_dly,
    output reg         LVBL_dly,
    // video data
    input   [4:0]      bakc,
    input   [5:0]      objc,
    input   [1:0]      objv,
    input   [3:0]      txtc,
    input              txtv,
    // output video
    output  reg [2:0]  red,
    output  reg [2:0]  green,
    output  reg [1:0]  blue
);

wire [7:0] bak_rgb, obj_rgb, txt_rgb;

reg txt_cs, obj_cs, bak_cs;

// latch priorities to process on the next clock edge
always @(posedge clk) if(pxl2_cen) begin
    txt_cs <= !txtv && gfx_en[0]; // txtv low -> text selected
    obj_cs <= (|objv) & gfx_en[1];
    bak_cs <= VB_n & HBD_n & gfx_en[2];
end

// merge the colours!
wire  preLVBL, preLHBL;
wire blankn = preLHBL | preLVBL;
always @(posedge clk) if(pxl2_cen) begin
    { LVBL_dly, LHBL_dly } <= { preLVBL, preLHBL };
    if( !blankn ) { red, green, blue } <= 8'd0;
    else
    casez( {txt_cs, obj_cs, bak_cs} )
        3'b1??: {blue, green, red } <= ~txt_rgb;
        3'b01?: {blue, green, red } <= ~obj_rgb;
        3'b001: {blue, green, red } <= ~bak_rgb;
        default:{blue, green, red } <= 8'd0;
    endcase
end
//23
jt2020_sh #(.width(2),.stages(17)) u_sh(
    .clk    (   clk                  ),
    .clk_en ( pxl2_cen               ),
    .din    ( { VB_n, HBD_n }        ),
    .drop   ( { preLVBL, preLHBL} )
);

// Background
jt2020_prom #(.aw(5),.dw(8),.simfile(`P4A)) u_prom_4a(
    .clk    ( clk               ),
    .cen    ( pxl2_cen          ),
    .data   ( prom_din          ),
    .rd_addr( bakc              ),
    .wr_addr( prog_addr[4:0]    ),
    .we     ( prom_4a_we        ),
    .q      ( bak_rgb           )
);

// OBJ

wire [7:0] obj_addr = { objc, objv };

jt2020_prom #(.aw(8),.dw(4),.simfile(`P5B)) u_prom_5b(
    .clk    ( clk               ),
    .cen    ( pxl2_cen          ),
    .data   ( prom_din[3:0]     ),
    .rd_addr( obj_addr          ),
    .wr_addr( prog_addr         ),
    .we     ( prom_5b_we        ),
    .q      ( obj_rgb[3:0]      )
);

jt2020_prom #(.aw(8),.dw(4),.simfile(`P5A)) u_prom_5a(
    .clk    ( clk               ),
    .cen    ( pxl2_cen          ),
    .data   ( prom_din[3:0]     ),  // data in the file is in the LSB's
    .rd_addr( obj_addr          ),
    .wr_addr( prog_addr         ),
    .we     ( prom_5a_we        ),
    .q      ( obj_rgb[7:4]      )  // But in the system, it is in the MSB's
);

// TXT

jt2020_prom #(.aw(5),.dw(8),.simfile(`P3A)) u_prom_3a(
    .clk    ( clk               ),
    .cen    ( pxl2_cen          ),
    .data   ( prom_din          ),
    .rd_addr( { txtc[3], txtc } ),
    .wr_addr( prog_addr[4:0]    ),
    .we     ( prom_3a_we        ),
    .q      ( txt_rgb           )
);


endmodule // jtpopeye_colmix
