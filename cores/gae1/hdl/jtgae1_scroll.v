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
    Date: 2-7-2026 */

module jtgae1_scroll (
    input        clk,
    input        rst,
    input        pxl_cen,
    input        gfx_4m,
    input        hsync,
    input [8:0]  hpos,
    input [8:0]  vpos,

    input [15:0] scr0_y,
    input [15:0] scr0_x,
    input [15:0] scr1_y,
    input [15:0] scr1_x,

    output [10:0] tile_a0,
    input [31:0] tile_q0,
    output [21:2] rom_a0,
    input [31:0] gfx0_data,
    input        gfx0_ok,

    output [10:0] tile_a1,
    input [31:0] tile_q1,
    output [21:2] rom_a1,
    input [31:0] gfx1_data,
    input        gfx1_ok,

    output [11:0] scr0_pxl,
    output [11:0] scr1_pxl
);

localparam [8:0] SCR0_XOFF = 9'd3;
localparam [8:0] SCR1_XOFF = 9'd1;
localparam [8:0] SCR_YOFF  = 9'd16;
localparam [8:0] HDUMP_OFF = 9'd4;

wire [8:0] hdump = hpos - HDUMP_OFF;
wire [8:0] scrx0 = scr0_x[8:0] + SCR0_XOFF;
wire [8:0] scry0 = scr0_y[8:0] + SCR_YOFF;
wire [8:0] scrx1 = scr1_x[8:0] - SCR1_XOFF;
wire [8:0] scry1 = scr1_y[8:0] + SCR_YOFF;

jtgae1_tilemap u_tilemap0 (
    .clk      ( clk       ),
    .rst      ( rst       ),
    .pxl_cen  ( pxl_cen   ),
    .gfx_4m   ( gfx_4m    ),
    .hsync    ( hsync     ),
    .hdump    ( hdump     ),
    .vdump    ( vpos      ),
    .scrx     ( scrx0     ),
    .scry     ( scry0     ),
    .layer    ( 1'b0      ),
    .tile_a   ( tile_a0   ),
    .tile_q   ( tile_q0   ),
    .rom_a    ( rom_a0    ),
    .rom_data ( gfx0_data ),
    .gfx_ok   ( gfx0_ok   ),
    .pxl      ( scr0_pxl )
);

jtgae1_tilemap u_tilemap1 (
    .clk      ( clk       ),
    .rst      ( rst       ),
    .pxl_cen  ( pxl_cen   ),
    .gfx_4m   ( gfx_4m    ),
    .hsync    ( hsync     ),
    .hdump    ( hdump     ),
    .vdump    ( vpos      ),
    .scrx     ( scrx1     ),
    .scry     ( scry1     ),
    .layer    ( 1'b1      ),
    .tile_a   ( tile_a1   ),
    .tile_q   ( tile_q1   ),
    .rom_a    ( rom_a1    ),
    .rom_data ( gfx1_data ),
    .gfx_ok   ( gfx1_ok   ),
    .pxl      ( scr1_pxl )
);

endmodule
