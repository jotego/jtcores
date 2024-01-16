/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-8-2022 */

module jtframe_logo #(parameter
    COLORW  = 4
) (
    input         rst,
    input         clk,
    input         pxl_cen,

    input   [8:0] vdump, hdump,

    output reg [COLORW*3-1:0] rgb
);

wire [10:1] tile_addr;
wire [ 8:0] vaddr;
wire [15:0] tile_data;
wire [ 7:0] tile_id;
wire [ 2:0] logopxl;


jtframe_prom #(.SYNHEX("logodata.hex"),.AW(10),.DW(16)) u_tiles(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .rd_addr( tile_addr ),
    .data   ( 16'd0     ),
    .wr_addr( 10'd0     ),
    .we     ( 1'b0      ),
    .q      ( tile_data )
);

jtframe_prom #(.SYNHEX("logomap.hex"),.AW(9)) u_map(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .rd_addr( vaddr     ),
    .data   ( 8'd0      ),
    .wr_addr( 9'd0      ),
    .we     ( 1'b0      ),
    .q      ( tile_id   )
);

always @* begin
    case( logopxl[1:0] )
        0: rgb = {3*COLORW{1'b0}}; // Black
        1: rgb = {3*COLORW{1'b1}}; // White
        default: rgb = { {COLORW{1'b1}}, {2*COLORW{1'b0}} }; // Red
    endcase
end

jtframe_tilemap #(
    .VA    (9),
    .CW    (7),
    .PW    (3),
    .BPP   (2),
    .MAP_HW(8),
    .MAP_VW(7)
)u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump[8:0]),
    .hdump      ( hdump[8:0]),
    .blankn     ( 1'b1      ),
    .flip       ( 1'b0      ),

    .vram_addr  ( vaddr     ),

    .code       (tile_id[6:0]),
    .pal        (tile_id[7] ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( tile_addr ),
    .rom_data   ( tile_data ),
    .rom_cs     (           ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( logopxl   )
);

endmodule