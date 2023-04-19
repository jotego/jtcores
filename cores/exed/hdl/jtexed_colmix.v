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
    Date: 6-8-2021 */


module jtexed_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,
    // pixel input from generator modules
    input [3:0]     char_pxl,        // character color code
    input [3:0]     scr1_pxl,
    input [5:0]     scr2_pxl,
    input [7:0]     obj_pxl,
    // Palette and priority PROMs
    input   [7:0]   prog_addr,
    input   [2:0]   prom_rgb_we,
    input           prom_prio_we,
    input   [7:0]   prom_din,

    input           preLVBL,
    input           preLHBL,
    output          LHBL,
    output          LVBL,

    output    [3:0] red,
    output    [3:0] green,
    output    [3:0] blue,
    // Debug
    input     [3:0] gfx_en
);

localparam BLANK_DLY = 1;

wire [4:0] prio_addr;
reg  [7:0] pxl_mux;
wire [7:0] prio_sel;

wire char_blank_b = gfx_en[0] & |(~char_pxl);
wire scr1_blank_b = gfx_en[1] & |(~scr1_pxl[3:0]);
// wire scr2_blank_b = gfx_en[2] & |(~scr2_pxl[3:0]);
wire obj_blank_b  = gfx_en[3] & |(~obj_pxl);

assign prio_addr = { 1'b0, char_blank_b, obj_pxl[7],
                           obj_blank_b,
                           scr1_blank_b };

always @(*) begin
    pxl_mux[7:6] = prio_sel[1:0];
    case( prio_sel[1:0] )
        3: pxl_mux[3:0] = char_pxl;
        2: pxl_mux[3:0] = obj_pxl[3:0];
        1: pxl_mux[3:0] = scr1_pxl;
        0: pxl_mux[3:0] = scr2_pxl[3:0];
    endcase
    pxl_mux[5:4] = ({2{prio_sel[3]}} & obj_pxl[5:4]) |
                   ({2{prio_sel[2]}} &scr2_pxl[5:4]);
end

wire [ 3:0] pre_r, pre_g, pre_b;
wire [11:0] pal_rgb;

assign pal_rgb = { pre_r, pre_g, pre_b };

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .preLBL     (                     ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .rgb_in     ( pal_rgb             ),
    .rgb_out    ( {red, green, blue } )
);

// priority PROM
wire prio_we = prom_prio_we && prog_addr[7:5]==0;

jtframe_prom #(.AW(5),.DW(8)) u_prio(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( prom_din       ),
    .rd_addr( prio_addr      ),
    .wr_addr( prog_addr[4:0] ),
    .we     ( prio_we        ),
    .q      ( prio_sel       )
);

// palette ROM
jtframe_prom #(.AW(8),.DW(4)) u_red(
    .clk    ( clk            ),
    .cen    ( pxl_cen        ),
    .data   ( prom_din[3:0]  ),
    .rd_addr( pxl_mux        ),
    .wr_addr( prog_addr      ),
    .we     ( prom_rgb_we[0] ),
    .q      ( pre_r          )
);

jtframe_prom #(.AW(8),.DW(4)) u_green(
    .clk    ( clk            ),
    .cen    ( pxl_cen        ),
    .data   ( prom_din[3:0]  ),
    .rd_addr( pxl_mux        ),
    .wr_addr( prog_addr      ),
    .we     ( prom_rgb_we[1] ),
    .q      ( pre_g          )
);

jtframe_prom #(.AW(8),.DW(4)) u_blue(
    .clk    ( clk            ),
    .cen    ( pxl_cen        ),
    .data   ( prom_din[3:0]  ),
    .rd_addr( pxl_mux        ),
    .wr_addr( prog_addr      ),
    .we     ( prom_rgb_we[2] ),
    .q      ( pre_b          )
);

endmodule