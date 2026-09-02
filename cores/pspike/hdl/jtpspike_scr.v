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
// karatblz 64x64 map, a THIRD format: code[12:0] with a single bank bit per
//          layer (gfxbank[Layer]<<13), palette code[15:13], no charbank, and
//          both layers scrolling from registers - it has no raster RAM.

module jtpspike_scr(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input      [ 8:0]   hdump, vdump,
    input               blankn,

    input               two,        // turbofrc/aerofgt tile format and map
    input               kb,         // karatblz tile format
    input               noraster,   // karatblz: both layers scroll from registers
    input      [ 8:0]   xbias,      // per game, per layer constant
    input               layer,      // 0 or 1, selects the gfx bank group
    input      [31:0]   gfxbank,    // eight 4-bit banks
    input      [ 2:0]   charbank,
    input      [ 8:0]   scrx, scry,
    input      [ 8:0]   hsize, vsize,   // visible width/height from the GGA
    input      [ 8:0]   visx,           // visible window origin, MAME set_visarea

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

wire [17:0] tile_addr;
wire [11:0] va;
wire [14:0] code;
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
assign scr_addr = two|kb ? va : { 1'b0, va[10:0] };

assign bsel     = two ? { layer, scr_vram[12:11] } :
                  kb  ? { 2'b00, layer }           : { 2'b00, scr_vram[12] };
assign bank     = gfxbank[{bsel,2'd0}+:4];
// MAME: tile = (code & 0x7ff) | (gfxbank[bank] << 11), and gfxbank is FOUR
// bits - turbofrc's gfx1 is 0xa0000 = 20480 tiles and really does use banks
// 8 and 9, so a 3-bit bank aliases them onto 0 and 1
// MAME karatblz: (code & 0x1fff) | (gfxbank[Layer] << 13), and its gfxbank is
// a single bit - karatblz_gfxbank_w does setbank(0,0,d&1) / setbank(1,1,d>>3)
assign code     = two ? { bank[3:0], scr_vram[10:0] }   :
                  kb  ? { 1'b0, bank[0], scr_vram[12:0] }
                      : { 1'b0, bank[1:0], scr_vram[11:0] };
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
wire [8:0] vras = flip ? vsize - 9'd1 - vdump : vdump;
assign ras_addr = { 3'd0, two ? 8'd7 : vras[7:0] };
wire [8:0] scrx_base, scry_base;
assign scrx_base= noraster ? scrx - xbias          :  // karatblz, registers only
                  !two     ? ras_dout[8:0]         :  // pspikes, one word per line
                  layer    ? scrx - xbias             // turbofrc layer 1
                           : ras_dout[8:0] - xbias;   // turbofrc layer 0, word 7
// MAME: m_tilemap[1]->set_scrolly(0, m_scrolly[1] + 2). Sweepable with
// -d PSPIKE_SCRY_BIAS=3
`ifndef PSPIKE_SCRY_BIAS
 `define PSPIKE_SCRY_BIAS 2
`endif
assign scry_base= (two & ~noraster) ? scry + `PSPIKE_SCRY_BIAS : scry;
// jtframe_scroll_offset mirrors within the 512-wide map (FLIP_HW/VW=9), so the
// picture lands W-1-x instead of x. -512 is a no-op on 9 bits, hence + hsize.
// The correction is twice the layer's horizontal origin: mirroring turns a
// +origin into a -origin. The pipeline lead is NOT part of it - it is a fixed
// delay applied after the mirror, so it cancels either way
assign scrx_eff = flip ? scrx_base + hsize + {visx[7:0],1'b0} : scrx_base;
assign scry_eff = flip ? scry_base + vsize : scry_base;
assign rom_addr = { 1'd0, tile_addr };

jtframe_scroll #(
    .SIZE       ( 8         ),
    .VA         ( 12        ),
    .CW         ( 15        ),
    .PW         ( 10        ),
    .MAP_HW     ( 9         ),  // 64 tiles across
    .MAP_VW     ( 9         ),  // 64 down, masked to 32 for pspikes
    .XOR_HFLIP  ( 1         ),  // screen flip mirrors each tile too
    .XOR_VFLIP  ( 0         ),  // veff already picks the mirrored row; the sub-row is a direct index
    .FLIP_HW    ( 9         ),  // mirror in the map's own 512-wide space
    .FLIP_VW    ( 9         ),
    .HLOOP      ( 0         ),  // folds blanking into
                                 // hdfix[8:7]=11 so the end-of-blanking fetch fires
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
    .pal        ( two|kb ? { 3'd0, scr_vram[15:13] }
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
