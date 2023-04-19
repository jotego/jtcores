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
    Date: 03-05-2020 */

// Equivalent to KONAMI 007327

module jtcastle_colmix(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl2_cen,
    input               pxl_cen,
    input               preLHBL,
    input               preLVBL,
    output              LHBL,
    output              LVBL,
    // CPU      interface
    input               prio_cfg,
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [ 9:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   pal_dout,
    // GFX colour requests
    input      [ 6:0]   gfx1_pxl,
    input      [ 6:0]   gfx2_pxl,
    // PROMs
    input      [10:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue
);

wire        pal_we = cpu_cen & ~cpu_rnw & pal_cs;
wire [ 7:0] col_data;
wire [ 9:0] col_addr;
wire [ 7:0] prio_addr;
wire [ 3:0] prio_sel;
reg         gfx_sel;
reg         gfx_aux, gfx_other; // signals to help in priority equations
reg         pal_half;
reg  [14:0] pxl_aux;
reg  [ 6:0] gfx1_dly, gfx2_dly;
wire [14:0] col_out;
reg  [14:0] col_in;
reg         prio;

assign prio_addr        = { prio_cfg, gfx2_pxl[4], gfx1_pxl[4], |gfx2_pxl[3:0], gfx1_pxl[3:0] };
assign col_addr         = { 2'b0, prio ? gfx2_dly : gfx1_dly, pal_half };
assign {blue,green,red} = col_out;

jtframe_prom #(.DW(4), .AW(8)) u_prio (
    .clk    ( clk           ),
    .cen    ( pxl_cen       ),
    .data   ( prog_data     ),
    .rd_addr( prio_addr     ),
    .wr_addr(prog_addr[7:0] ),
    .we     ( prom_we       ),
    .q      ( prio_sel      )
);

jtframe_dual_ram #(.AW(10)) u_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( pal_we    ),
    .q0     ( pal_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  ( col_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( col_data  )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        gfx1_dly <= 0;
        gfx2_dly <= 0;
        prio     <= 0;
    end else begin
        if(pxl2_cen) begin
            prio     <= prio_sel[0];
        end
        if(pxl_cen) begin
            gfx1_dly <= gfx1_pxl;
            gfx2_dly <= gfx2_pxl;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
    end else begin
        pxl_aux  <= { pxl_aux[6:0], col_data };
        if( pxl_cen ) begin
            col_in <= pxl_aux;
            pal_half <= 1;
        end else
            pal_half <= ~pal_half;
    end
end

jtframe_blank #(.DLY(4),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( col_in    ),
    .rgb_out    ( col_out   )
);

endmodule