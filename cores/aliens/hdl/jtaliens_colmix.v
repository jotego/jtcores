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
    Date: 15-4-2023 */

module jtaliens_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,

    input      [ 2:0] prio_cfg,
    // CPU interface
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [ 9:0] cpu_addr,
    output     [ 7:0] cpu_din,

    // PROMs
    input      [ 6:0] prog_addr,
    input      [ 1:0] prog_data,
    input             prom_we,

    // Final pixels
    input             lyrf_blnk_n,
    input             lyra_blnk_n,
    input             lyrb_blnk_n,
    input             lyro_blnk_n,
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [ 7:0] lyro_pxl,
    output reg [ 4:0] red,
    output reg [ 4:0] green,
    output reg [ 4:0] blue
);

wire [ 1:0] prio_sel;
wire [ 7:0] pal_dout;
wire [ 6:0] prio_addr;
reg         pal_half;
reg  [ 7:0] pxl;
reg  [14:0] pxl_aux;
wire [ 9:0] pal_addr;

assign prio_addr = { prio_cfg[0], prio_cfg[1], prio_cfg[2],
    lyrf_blnk_n, lyro_blnk_n, lyrb_blnk_n, lyra_blnk_n };
assign pal_addr  = { pal_half, prio_sel[1] & ~prio_sel[0], pxl };

always @* begin
    case( prio_sel )
        0: pxl = { 2'b01, lyra_pxl[7:6], lyra_pxl[3:0] };
        1: pxl = { 2'b10, lyrb_pxl[7:6], lyrb_pxl[3:0] };
        2: pxl = lyro_pxl;
        3: pxl = { 2'b00, lyrf_pxl[7:6], lyrf_pxl[3:0] };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        red      <= 0;
        green    <= 0;
        blue     <= 0;
    end else begin
`ifndef GRAY
        pxl_aux <= { pxl_aux[6:0], pal_dout };
`else
        pxl_aux <= {3{pxl[4:0]}};
`endif
        if( pxl_cen ) begin
            {blue,green,red} <= (lvbl & lhbl ) ? pxl_aux : 15'd0;
            pal_half <= 1;
        end else
            pal_half <= ~pal_half;
    end
end

jtframe_prom #(.DW(2), .AW(7)) u_prio (
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( prio_addr     ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ( prio_sel      )
);


jtframe_dual_ram u_ram(
    // Port 0: CPU
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr      ),
    .we0    ( cpu_we        ),
    .q0     ( cpu_din       ),
    // Port 1
    .clk1   ( clk           ),
    .data1  ( 8'd0          ),
    .addr1  ( pal_addr      ),
    .we1    ( 1'b0          ),
    .q1     ( pal_dout      )
);

endmodule