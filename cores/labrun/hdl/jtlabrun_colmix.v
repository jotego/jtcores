/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 03-10-2020 */

// Equivalent to KONAMI 007593

module jtlabrun_colmix(
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
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [ 7:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   pal_dout,
    // GFX colour requests
    input      [ 6:0]   gfx_pxl,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue
);

wire        pal_we = cpu_cen & ~cpu_rnw & pal_cs;
wire [ 7:0] col_data, col_addr;
reg         pal_half;
reg  [14:0] pxl_aux;
wire [14:0] col_out;
reg  [14:0] col_in;

assign col_addr = { gfx_pxl, ~pal_half };

assign { blue, green, red } = col_out;

jtframe_dual_ram #(.AW(8)) u_ram(
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

jtframe_blank #(.DLY(2),.DW(15)) u_blank(
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