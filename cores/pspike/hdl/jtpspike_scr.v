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

// Tile layer, 8x8 4bpp.
//
// pspikes  64x32 map, opaque, code[11:0] with one of two gfx banks picked by
//          code[12], palette {charbank, code[15:13]}, and a scroll X value per
//          screen line taken from the raster RAM.
// turbofrc 64x64 map, layer 1 transparent on pen 15, code[10:0] with one of
//          eight banks picked by {layer, code[12:11]}, palette code[15:13],
//          and a single scroll X for the whole frame.

module jtpspike_scr(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input      [ 8:0]   hdump, vdump,
    input               blankn,

    input               two,        // two layer hardware: turbofrc, aerofgt
    input               noraster,   // karatblz: both layers scroll from registers
    input      [ 8:0]   xbias,      // per game, per layer constant
    input               layer,      // 0 or 1, selects the gfx bank group
    input      [31:0]   gfxbank,    // eight 4-bit banks
    input      [ 2:0]   charbank,
    input      [ 8:0]   scrx, scry,

    // tilemap VRAM
    output     [12:1]   scr_addr,
    input      [15:0]   scr_vram,
    // raster RAM, one scroll X per line on pspikes
    output     [11:1]   ras_addr,
    input      [15:0]   ras_dout,

    output     [20:2]   rom_addr,
    output              rom_cs,
    input      [31:0]   rom_data,
    input               rom_ok,

    output     [ 9:0]   pxl
);

wire [16:0] tile_addr;
wire [11:0] va;
wire [13:0] code;
wire [ 3:0] bank;
wire [ 2:0] bsel;
wire [ 8:0] scrx_eff, scry_eff;
wire [31:0] sorted;

// gfx is gfx_8x8x4_packed_lsb: each 32-bit word is one 8-pixel row with the
// leftmost pixel in the lowest nibble. jtframe_tilemap wants one byte per
// plane, MSB leftmost. Note jtframe_draw (sprites) wants the opposite
assign sorted = {
    rom_data[ 3],rom_data[ 7],rom_data[11],rom_data[15],
    rom_data[19],rom_data[23],rom_data[27],rom_data[31],
    rom_data[ 2],rom_data[ 6],rom_data[10],rom_data[14],
    rom_data[18],rom_data[22],rom_data[26],rom_data[30],
    rom_data[ 1],rom_data[ 5],rom_data[ 9],rom_data[13],
    rom_data[17],rom_data[21],rom_data[25],rom_data[29],
    rom_data[ 0],rom_data[ 4],rom_data[ 8],rom_data[12],
    rom_data[16],rom_data[20],rom_data[24],rom_data[28] };

// The map is built 64x64. pspikes only has 32 rows, so its row field is one
// bit narrower and the top address bit is dropped, which also gives it the
// 256 pixel vertical wrap the real map has
assign scr_addr = two ? va : { 1'b0, va[10:0] };

assign bsel     = two ? { layer, scr_vram[12:11] } : { 2'b00, scr_vram[12] };
assign bank     = gfxbank[{bsel,2'd0}+:4];
assign code     = two ? { bank[2:0], scr_vram[10:0] }
                           : { bank[1:0], scr_vram[11:0] };
// pspikes reads one raster word per line. turbofrc layer 0 takes a single
// value from raster word 7 - every entry holds the same number - and layer 1
// uses its own register.
//
// The two layers carry different constant biases, so leaving them out does
// not just shift the picture, it misaligns the layers against each other:
//   layer 0  rasterram[7] - 11      layer 1  scrollx1 - 7
//   both     scrolly + 2
// MAME's set_scrollx((i+scrolly)&0xff, rasterram[i]) indexes TILEMAP rows, and
// the +scrolly there cancels set_scrolly - so screen row r reads rasterram[r].
// Do NOT subtract scrolly here. turbofrc/aerofgt use rasterram[7] for every
// row; karatblz has no raster RAM.
assign ras_addr = { 3'd0, two ? 8'd7 : vdump[7:0] };
assign scrx_eff = !two ? ras_dout[8:0] :
                  (layer | noraster) ? scrx - xbias : ras_dout[8:0] - xbias;
assign scry_eff = (two & ~noraster) ? scry + 9'd2 : scry;
assign rom_addr = { 2'd0, tile_addr };

jtframe_scroll #(
    .SIZE       ( 8         ),
    .VA         ( 12        ),
    .CW         ( 14        ),
    .PW         ( 10        ),
    .MAP_HW     ( 9         ),  // 64 tiles across
    .MAP_VW     ( 9         ),  // 64 down, masked to 32 for pspikes
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
    .scrx       ( scrx_eff  ),
    .scry       ( scry_eff  ),

    .vram_addr  ( va        ),

    .code       ( code      ),
    .pal        ( two ? { 3'd0, scr_vram[15:13] }
                           : { charbank, scr_vram[15:13] } ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( tile_addr ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule
