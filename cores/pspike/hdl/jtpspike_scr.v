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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 10-8-2026 */

// 64x32 map of 8x8 4bpp tiles, opaque, no per-tile flip.
// Scroll X comes from the raster RAM, one word per screen line, so the value
// is latched at HS for the line about to be drawn. Scroll Y is a register.

module jtpspike_scr(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input      [ 8:0]   hdump, vdump,
    input               blankn,

    input      [ 3:0]   gfxbank0, gfxbank1,
    input      [ 2:0]   charbank,
    input      [ 8:0]   scry,

    // tilemap VRAM
    output     [11:1]   scr_addr,
    input      [15:0]   scr_vram,
    // raster RAM, one scroll X per line
    output     [11:1]   ras_addr,
    input      [15:0]   ras_dout,

    output     [19:2]   rom_addr,
    output              rom_cs,
    input      [31:0]   rom_data,
    input               rom_ok,

    output     [ 9:0]   pxl
);

wire [16:0] tile_addr;
wire [13:0] code;
wire [ 3:0] bank;
wire [31:0] sorted;

// gfx1 is gfx_8x8x4_packed_lsb: each 32-bit word is one 8-pixel row, the
// leftmost pixel in the lowest nibble. jtframe_tilemap wants one byte per
// plane with the leftmost pixel on the MSB
assign sorted = {
    rom_data[ 3],rom_data[ 7],rom_data[11],rom_data[15],
    rom_data[19],rom_data[23],rom_data[27],rom_data[31],
    rom_data[ 2],rom_data[ 6],rom_data[10],rom_data[14],
    rom_data[18],rom_data[22],rom_data[26],rom_data[30],
    rom_data[ 1],rom_data[ 5],rom_data[ 9],rom_data[13],
    rom_data[17],rom_data[21],rom_data[25],rom_data[29],
    rom_data[ 0],rom_data[ 4],rom_data[ 8],rom_data[12],
    rom_data[16],rom_data[20],rom_data[24],rom_data[28] };

// bit 12 of the VRAM word picks which of the two gfx banks applies.
// gfx1 holds 16384 tiles, so only the two low bits of the bank matter
assign bank      = scr_vram[12] ? gfxbank1 : gfxbank0;
assign code      = { bank[1:0], scr_vram[11:0] };
// vdump already advanced to the line about to be drawn by the time HS
// latches scrx (jtframe_vtimer moves it at H_VNEXT=HS_START), so this is the
// line's own scroll. Using vrender here picks the next line's value and puts
// the split scroll boundaries one line early
assign ras_addr  = { 3'd0, vdump[7:0] };
assign rom_addr  = { 1'b0, tile_addr };

jtframe_scroll #(
    .SIZE       ( 8         ),
    .VA         ( 11        ),
    .CW         ( 14        ),
    .PW         ( 10        ),
    .MAP_HW     ( 9         ),  // 64 tiles across
    .MAP_VW     ( 8         ),  // 32 tiles down
    .LATCH_SCRX ( 1         )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .scrx       ( ras_dout[8:0] ),
    .scry       ( scry[7:0] ),

    .vram_addr  ( scr_addr  ),

    .code       ( code      ),
    .pal        ( { charbank, scr_vram[15:13] } ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( tile_addr ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule
