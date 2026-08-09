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

// Three 256x4 PROMs hold one RGB component each. The pen index is
// {colour[3:0], pixel[3:0]}: sprites and tiles share the palette.
// Download order is R (tdclr3), G (tdclr2), B (tdclr1)

module jtsauro_colmix(
    input             clk,
    input             pxl_cen,

    input      [ 7:0] obj_pxl,
    input      [ 7:0] scr_pxl,
    input             preLHBL,
    input             preLVBL,

    input      [ 7:0] prog_data,
    input      [ 9:0] prog_addr,
    input             prom_we,

    output     [ 3:0] red, green, blue,
    output            LHBL, LVBL,
    input      [ 3:0] gfx_en
);

// scr_pxl is combinational, obj_pxl comes out of the line buffer one
// pixel later. One extra stage for the mux and one for the PROMs
parameter BLANK_DLY = 3;

wire [11:0] raw, rgb;
wire [ 2:0] prom_sel;
reg  [ 7:0] scr_l, pen;
wire        obj_blank;

assign obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];
assign prom_sel  = { prog_addr[9:8]==2'd2, prog_addr[9:8]==2'd1, prog_addr[9:8]==2'd0 } & {3{prom_we}};
assign { red, green, blue } = rgb;

always @(posedge clk) if(pxl_cen) begin
    scr_l <= gfx_en[0] ? scr_pxl : 8'd0;
    pen   <= obj_blank ? scr_l : obj_pxl;
end

jtframe_prom #(.DW(4),.AW(8),.SIMFILE("tdclr3.prm")) u_red(
    .clk    ( clk               ),
    .cen    ( pxl_cen           ),
    .data   ( prog_data[3:0]    ),
    .wr_addr( prog_addr[7:0]    ),
    .we     ( prom_sel[0]       ),
    .rd_addr( pen               ),
    .q      ( raw[11:8]         )
);

jtframe_prom #(.DW(4),.AW(8),.SIMFILE("tdclr2.prm")) u_green(
    .clk    ( clk               ),
    .cen    ( pxl_cen           ),
    .data   ( prog_data[3:0]    ),
    .wr_addr( prog_addr[7:0]    ),
    .we     ( prom_sel[1]       ),
    .rd_addr( pen               ),
    .q      ( raw[7:4]          )
);

jtframe_prom #(.DW(4),.AW(8),.SIMFILE("tdclr1.prm")) u_blue(
    .clk    ( clk               ),
    .cen    ( pxl_cen           ),
    .data   ( prog_data[3:0]    ),
    .wr_addr( prog_addr[7:0]    ),
    .we     ( prom_sel[2]       ),
    .rd_addr( pen               ),
    .q      ( raw[3:0]          )
);

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_blank(
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
