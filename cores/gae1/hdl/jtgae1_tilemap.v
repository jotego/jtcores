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

module jtgae1_tilemap (
    input        clk,
    input        rst,
    input        pxl_cen,
    input        gfx_4m,

    input        hsync,
    input [8:0]  hdump,
    input [8:0]  vdump,
    input [8:0]  scrx,
    input [8:0]  scry,
    input        layer,

    output [10:0] tile_a,
    input [31:0] tile_q,

    output [21:2] rom_a,
    input [31:0] rom_data,
    input        gfx_ok,

    output [11:0] pxl
);

wire        flip     = 1'b0;
wire [ 9:0] map_addr;
wire [19:0] raw_rom_a;

wire [15:0] tile_attr = tile_q[31:16];
wire [15:0] tile_pal  = tile_q[15:0];
wire [14:0] code      = 15'h4000 + {1'b0, tile_attr[15:2]};
wire [21:2] rom_addr  = { gfx_4m ? raw_rom_a[19] : 1'b0, raw_rom_a[18:0] };
wire [31:0] rom_lanes = { rom_data[ 7:0], rom_data[15:8], rom_data[23:16], rom_data[31:24] };
wire [ 7:0] pal       = { tile_pal[7:6], tile_pal[5:0] };
wire        hflip     = tile_attr[0];
wire        vflip     = tile_attr[1];

assign tile_a   = { layer, map_addr };
assign rom_a    = rom_addr;

jtframe_scroll #(
    .SIZE      ( 16 ),
    .VA        ( 10 ),
    .CW        ( 15 ),
    .PW        ( 12 )
) u_scroll (
    .rst       ( rst     ),
    .clk       ( clk     ),
    .pxl_cen   ( pxl_cen ),

    .hs        ( hsync   ),
    .vdump     ( vdump   ),
    .hdump     ( hdump   ),
    .blankn    ( 1'b1    ),
    .flip      ( flip    ),
    .scrx      ( scrx    ),
    .scry      ( scry    ),

    .vram_addr ( map_addr ),

    .code      ( code    ),
    .pal       ( pal      ),
    .hflip     ( hflip    ),
    .vflip     ( vflip    ),

    .rom_addr  ( raw_rom_a ),
    .rom_data  ( rom_lanes ),
    .rom_cs    (          ),
    .rom_ok    ( gfx_ok   ),

    .pxl       ( pxl      )
);
endmodule
