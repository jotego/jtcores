/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

// This module introduces 1-pixel delay
// clock operates at 4*pxl_cen because colour data requires
// two memory reads per pixel
// It could be done at 2*pxl_cen, but this solutions is neat
// and 24MHz is not a tough requirement for modern FPGAs


module jtrumble_colmix(
    input            rst,
    input            clk,
    input            pxl_cen,
    input            pxl2_cen,

    // pixel input from generator modules
    input [5:0]      char_pxl,        // character color code
    input [7:0]      scr_pxl,
    input [6:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output  reg      LHBL_dly,
    output  reg      LVBL_dly,
    // Palette PROMs and object priority
    input [7:0]      prog_addr,
    input            prom_prio_we,
    input [3:0]      prom_din,
    // CPU inteface
    input [9:0]      cpu_addr,
    input [7:0]      cpu_dout,
    input            pal_cs,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter PXL_DLY = 8;

parameter [1:0] OBJ_PAL = 2'b10,
                SCR_PAL = 2'b01,
                CHAR_PAL= 2'b11;

reg [ 8:0] pal_addr;
reg [ 7:0] last_out;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire obj_blank   = ~&obj_pxl[3:0];
wire scr_blank   = ~&scr_pxl[3:0];
wire char_blank  = ~&char_pxl[1:0];
wire enable_obj  = gfx_en[3];
wire pal_we      = pal_cs;
wire [ 1:0] prio;
wire [ 7:0] dump;
reg  [11:0] pxl;
reg         lsb;

wire       scrwin  = scr_pxl[7];
wire [7:0] prio_addr = { scr_pxl[3:0], scr_pxl[6], obj_blank, scr_blank, char_blank };

assign pal_addr = prio==CHAR_PAL ? { CHAR_PAL, 1'b1, char_pxl} :
                 (prio==OBJ_PAL  ? { OBJ_PAL, obj_pxl } : { SCR_PAL, scr_pxl[6:0]} );

always @(posedge clk) begin
    last_out <= dump;
    if(pxl_cen) begin
        pxl <= { last_out, dump[7:4] };
        lsb<=1;
    end else if(pxl2_cen) lsb <= ~lsb;
end

jtframe_prom #(.dw(2),.aw(8),.simfile("63s141.8j")) u_prio(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( prio_addr     ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( prio          )
);

jtframe_dual_ram #(.aw(10)) u_pal(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    // Port 0: CPU writes
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr      ),
    .we0    ( pal_we        ),
    .q0     (               ),
    // Port 1: colour mixer reads
    .data1  ( 8'd0          ),
    .addr1  ( {pal_addr,lsb}),
    .we1    ( 1'b0          ),
    .q1     ( dump          )
);

jtframe_blank #(.DLY(PXL_DLY)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ( pxl       ),
    .rgb_out    ({red,green,blue})
);

endmodule
