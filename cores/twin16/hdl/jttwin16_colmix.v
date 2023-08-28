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
    Date: 27-8-2023 */

module jttwin16_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 1:0] cpu_prio,

    // Base Video
    input             lhbl,
    input             lvbl,

    // CPU interface
    input             crtkill,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [12:1] cpu_addr,
    output     [ 7:0] cpu_din,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Final pixels
    input      [ 7:0] lyrf_pxl,
    input      [ 6:0] lyra_pxl,
    input      [ 6:0] lyrb_pxl,
    input      [ 7:0] lyro_pxl,
    input             shadow,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [11:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

wire [ 1:0] prio_sel, prom_prio;
wire [ 7:0] pal_dout;
wire [ 7:0] prio_addr;
reg         pal_half, shl;
reg  [ 9:0] pxl;
reg  [15:0] pxl_aux;
reg  [23:0] bgr;
wire [11:0] pal_addr;
wire        shad;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n;

assign      lyrf_blnk_n = gfx_en[0] & |lyrf_pxl[3:0];
assign      lyra_blnk_n = gfx_en[1] & |lyra_pxl[3:0];
assign      lyrb_blnk_n = gfx_en[2] & |lyrb_pxl[3:0];
assign      lyro_blnk_n = gfx_en[3] & |lyro_pxl[3:0];

assign prio_addr = { cpu_prio, lyrb_pxl[6], ~&lyro_pxl[3:0],
    lyrf_blnk_n, lyro_blnk_n, lyrb_blnk_n, lyra_blnk_n };

assign pal_addr  = { 1'b0, pxl, pal_half };
assign ioctl_din = pal_dout;
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;
assign prio_sel  = prom_prio & {2{crtkill}};

always @* begin
    case( prio_sel )
        0: pxl[7:0] = { 1'b1, lyrb_pxl };
        1: pxl[7:0] = { 1'b0, lyra_pxl };
        2: pxl[7:0] = lyro_pxl;
        3: pxl[7:0] = lyrf_pxl;
    endcase
    pxl[9:8] = { ~prio_sel[1], prio_sel[1]&~prio_sel[0] };
end

function [23:0] dim( input [14:0] cin, input shade );
    dim = !shade? {   1'b0, cin[14:10], cin[14:13],
                      1'b0, cin[ 9: 5], cin[ 9: 8],
                      1'b0, cin[ 4: 0], cin[ 4: 3] } :
                 { cin[14:10], cin[14:12],
                   cin[ 9: 5], cin[ 9: 7],
                   cin[ 4: 0], cin[ 4: 2] };
endfunction

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        bgr      <= 0;
        shl      <= 0;
    end else begin
`ifndef GRAY
        pxl_aux <= { pxl_aux[7:0], pal_dout };
`else
        pxl_aux <= {1'b0,{3{pxl[4:0]}}};
`endif
        if( pxl_cen ) begin
            shl <= shad;
            bgr <= dim(pxl_aux[14:0], shl);
            pal_half <= 0;
        end else
            pal_half <= ~pal_half;
    end
end

jtframe_prom #(.DW(3), .AW(8)) u_prio (
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( prio_addr     ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ({shad,prom_prio})
);

jtframe_dual_nvram #(.AW(12),.SIMFILE("pal.bin")) u_ram(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr      ),
    .we0    ( cpu_we        ),
    .q0     ( cpu_din       ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1a ( pal_addr      ),
    .addr1b ( ioctl_addr    ),
    .sel_b  ( ioctl_ram     ),
    .we_b   ( 1'b0          ),
    .q1     ( pal_dout      )
);

endmodule