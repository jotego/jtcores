/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 03-05-2020 */

// Equivalent to KONAMI 007593
// Plus priority decoding selected for each game
// with parameter GAME

module jtcontra_colmix(
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
    input               prio_latch, // Used by Combat School
    input      [ 6:0]   gfx1_pxl,
    input      [ 6:0]   gfx2_pxl,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue
);

parameter GAME=0; // 0 = Contra, 1 = Combat School

wire        pal_we = cpu_cen & ~cpu_rnw & pal_cs;
wire [ 7:0] col_data;
wire [ 7:0] col_addr;
reg         gfx_sel;
reg         gfx_aux, gfx_other; // signals to help in priority equations
reg         pal_half;
reg  [14:0] pxl_aux;
reg  [ 6:0] gfx_mux;
wire [14:0] col_out;
reg  [14:0] col_in;
wire        gfx1_blank = gfx1_pxl[3:0]==4'h0;
wire        gfx2_blank = gfx2_pxl[3:0]==4'h0;

always @(*) begin
    case( GAME )
        1: begin // Combat School
            gfx_aux  = ~gfx2_blank &  gfx1_pxl[4]; // NCHA1 in schematics
            gfx_other= ~((gfx1_blank | ~gfx2_pxl[4]) & ~prio_latch); // output of S21
            gfx_sel  = ~( gfx_other& ~(gfx_aux&prio_latch) );
            gfx_mux  = { gfx_sel, gfx_sel ? gfx2_pxl[5:0] : gfx1_pxl[5:0]};
        end
        default: begin // Contra
            gfx_sel  = gfx1_blank || !gfx2_pxl[4];
            gfx_mux  = gfx_sel ? gfx2_pxl : gfx1_pxl;
        end
    endcase // GAME
end

assign col_addr = { gfx_mux, pal_half };

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
        pxl_aux  <= 0;
    end else begin
        pxl_aux  <= { pxl_aux[6:0], col_data };
        if( pxl_cen ) begin
            col_in <= pxl_aux;
            pal_half <= 1;
        end else
            pal_half <= ~pal_half;
    end
end

jtframe_blank #(.DLY(3),.DW(15)) u_blank(
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