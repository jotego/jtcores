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
    Date: 18-9-2022 */

module jtkiwi_colmix(
    input        clk,
    input        clk_cpu,
    input        pxl_cen,
    input        LHBL,
    input        LVBL,

    input  [8:0] scr_pxl,
    input  [8:0] obj_pxl,

    input  [9:0] cpu_addr,
    input  [7:0] cpu_dout,
    input        cpu_rnw,
    output [7:0] cpu_din,
    input        pal_cs,

    input        pal2_cs,
    input  [7:0] cpu2_dout,
    input        cpu2_rnw,
    input  [9:0] cpu2_addr,

    input  [9:0] prog_addr,
    input  [7:0] prog_data,
    input        prom_we,
    input        colprom_en,

    input  [7:0] debug_bus,
    input  [3:0] gfx_en,
    output [4:0] red,
    output [4:0] green,
    output [4:0] blue
);

wire [ 7:0] pal_dout;
wire [ 9:0] pal_addr;
reg  [ 7:0] pall;
reg  [ 8:0] coll, col_addr;
reg  [14:0] rgb;
wire        pal_we;
wire        blank;
reg         half, obj_sel;
// PROM variation
wire [15:0] prom_dout;
wire        promhi_we, promlo_we;
wire [ 3:0] sort;

assign pal_addr = { coll, half };
assign pal_we   = (pal_cs & ~cpu_rnw) | (pal2_cs & ~cpu2_rnw);
assign blank    = ~(LVBL & LHBL);
assign {red,green,blue} = {15{~blank}} & rgb;
// PROM
assign promhi_we = prom_we & ~prog_addr[9];
assign promlo_we = prom_we &  prog_addr[9];

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
        rgb <= colprom_en ? prom_dout[14:0] : { pal_dout[6:0], pall };
`endif
        half <= 1;
        coll <= col_addr;
    end
    pall <= pal_dout;
end

jtframe_sort u_sort(
    .debug_bus  ( debug_bus ),
    .busin      ( col_addr[3:0]    ),
    .busout     ( sort  )
);

// Palette RAM X1-007 chip
jtframe_dual_ram #(.AW(10),.SIMFILE("pal.bin")) u_comm(
    .clk0   ( clk_cpu      ),
    .clk1   ( clk          ),
    // Main/Sub CPU
    .addr0  ( pal2_cs ? cpu2_addr : cpu_addr ),
    .data0  ( pal2_cs ? cpu2_dout : cpu_dout ),
    .we0    ( pal_we       ),
    .q0     ( cpu_din      ),
    // Color mixer
    .addr1  ( pal_addr     ),
    .data1  (              ),
    .we1    ( 1'b0         ),
    .q1     ( pal_dout     )
);

// PROM for Extermination
jtframe_prom #( .AW(9), .SIMFILE("../../../../rom/extrmatn/b06-09.15f")) u_promhi(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( {col_addr[8:4], sort}  ),
    .wr_addr( prog_addr[8:0]  ),
    .we     ( promhi_we ),
    .q      ( prom_dout[15:8] )
);

jtframe_prom #( .AW(9), .SIMFILE("../../../../rom/extrmatn/b06-08.17f")) u_promlo(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( {col_addr[8:4], sort}  ),
    .wr_addr( prog_addr[8:0] ),
    .we     ( promlo_we ),
    .q      ( prom_dout[7:0] )
);

endmodule