/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-05-2020 */

module jtbubl_colmix(
    input               clk,
    input               clk_cpu,
    input               pxl_cen,
    // Screen
    input               preLHBL,
    input               preLVBL,
    output              LHBL,
    output              LVBL,
    input      [ 7:0]   col_addr,
    // CPU interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               cpu_rnw,
    input      [ 8:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               black_n,    
    // Colours
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue
);

wire [15:0] col_out;
wire [15:0] co_bus;
reg  [15:0] col_in;
wire        pal0_we  = pal_cs & ~cpu_rnw & ~cpu_addr[0];
wire        pal1_we  = pal_cs & ~cpu_rnw &  cpu_addr[0];
wire [ 7:0] pal_addr = cpu_addr[8:1];
wire [ 7:0] pal_even, pal_odd;

assign red      = col_out[7:4];
assign green    = col_out[3:0];
assign blue     = col_out[15:12];
assign pal_dout = !cpu_addr[0] ? pal_even : pal_odd;

jtframe_dual_ram #(.AW(8),.SIMHEXFILE("pal_even.hex")) u_ram0(
    .clk0   ( clk_cpu      ),
    .clk1   ( clk          ),
    // Port 0
    .data0  ( cpu_dout     ),
    .addr0  ( pal_addr     ),
    .we0    ( pal0_we      ),
    .q0     ( pal_even     ),
    // Port 1
    .data1  (              ),
    .addr1  ( col_addr     ),
    .we1    ( 1'b0         ),
    .q1     ( co_bus[7:0]  )
);

jtframe_dual_ram #(.AW(8),.SIMHEXFILE("pal_odd.hex")) u_ram1(
    .clk0   ( clk_cpu      ),
    .clk1   ( clk          ),
    // Port 0
    .data0  ( cpu_dout     ),
    .addr0  ( pal_addr     ),
    .we0    ( pal1_we      ),
    .q0     ( pal_odd      ),
    // Port 1
    .data1  (              ),
    .addr1  ( col_addr     ),
    .we1    ( 1'b0         ),
    .q1     ( co_bus[15:8] )
);

`ifdef GRAY
always @(*) //if(pxl_cen) 
    col_in = {4{col_addr[3:0]}};
`else
always @(*) //if(pxl_cen) 
    col_in = co_bus & {16{black_n}};
`endif

jtframe_blank #(.DLY(1),.DW(16)) u_blank(
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