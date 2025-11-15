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
    Date: 15-11-2025 */

module jtcal50_colmix(
    input        clk,
    input        clk_cpu,
    input        pxl_cen,
    input        LHBL,
    input        LVBL,

    input  [8:0] scr_pxl,
    input  [8:0] obj_pxl,

    output [9:1] pal_addr,
    input [15:0] pal_data,

    input  [7:0] debug_bus,
    input  [3:0] gfx_en,
    output [4:0] red,
    output [4:0] green,
    output [4:0] blue
);

reg  [ 7:0] pall;
reg  [ 8:0] coll, col_addr;
reg  [14:0] rgb;
wire        pal_we;
wire        blank;
reg         half, obj_sel;

assign pal_addr = { coll, half };
assign pal_we   =  pal_cs & ~cpu_rnw;
assign blank    = ~(LVBL & LHBL);
assign {red,green,blue} = {15{~blank}} & rgb;

always @* begin
    obj_sel = obj_pxl[3:0] != 4'h0;
    case( {gfx_en[3],gfx_en[0]})
        2'b00: col_addr = 0;
        2'b01: col_addr = scr_pxl;
        2'b10: col_addr = obj_pxl;
        2'b11: col_addr = obj_sel ? obj_pxl : scr_pxl; // simple priority for now.
    endcase
end

always @(posedge clk) begin
    half <= ~half;
    if( pxl_cen ) begin
`ifdef GRAY
        rgb <= ~{3{ {coll[3:0]}, 1'b0 } };
`else
        rgb <= { pal_data[6:0], pall };
`endif
        half <= 1;
        coll <= col_addr;
    end
    pall <= pal_data;
end

endmodule