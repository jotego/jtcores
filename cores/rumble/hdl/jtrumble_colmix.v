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
    input [6:0]      char_pxl,        // character color code
    input [7:0]      scr_pxl,
    input [7:0]      obj_pxl,
    input            preLVBL,
    input            preLHBL,
    output           LHBL,
    output           LVBL,
    // Palette PROMs and object priority
    input [7:0]      prog_addr,
    input            prom_prio_we,
    input [3:0]      prom_din,
    // CPU inteface
    input [9:0]      cpu_addr,
    input [7:0]      cpu_dout,
    input            pal_cs,

    output     [3:0] red,
    output     [3:0] green,
    output     [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter PXL_DLY = 7;

parameter [1:0] OBJ_PAL = 2'b10,
                SCR_PAL = 2'b01,
                CHAR_PAL= 2'b11;

wire [ 8:0] pal_addr;
reg  [ 7:0] last_out;
reg         gray;       // gray output until the palette is 1st written

// wire obj_blank   =  &obj_pxl[3:0]  | ~gfx_en[3];
wire char_blankn = ~&char_pxl[1:0] &  gfx_en[0];
wire pal_we      = pal_cs;
wire [ 1:0] prio;
wire [ 7:0] dump;
reg  [11:0] pxl;
reg         lsb;

// Addressing extracted directly from the PCB:
wire [7:0] prio_addr = { scr_pxl[7], scr_pxl[3:0], obj_pxl[7], char_pxl[6], char_blankn };

assign pal_addr[8:7] = prio;
assign pal_addr[6:0] = prio==CHAR_PAL ? { 1'b1, char_pxl[5:0]} :
                      (prio==OBJ_PAL  ? obj_pxl[6:0] : scr_pxl[6:0]);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        gray <= 1;
    end else begin
        if( pal_cs ) gray<=0;
    end
end

always @(posedge clk) begin
    if(pxl_cen) begin
        pxl <= gray ? {3{~pal_addr[3:0]}} :
                      { dump, last_out[7:4] };
        lsb<=1;
    end else if(pxl2_cen) begin
        last_out <= dump;
        lsb      <= ~lsb;
    end
end

jtframe_prom #(.DW(2),.AW(8),.SIMFILE("../../../../rom/rumble/63s141.8j")) u_prio(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( prio_addr     ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( prio          )
);

jtframe_dual_ram #(.AW(10)) u_pal(
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
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( pxl       ),
    .rgb_out    ({red,green,blue})
);

endmodule
