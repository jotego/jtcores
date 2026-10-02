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

// VS8904/VS8905 sprite pair. The list walk, the indirect tile lookup and the
// vertical zoom live in jtpspike_objscan; the drawing is the generic
// jtframe_objdraw, which does the horizontal zoom by itself.

// PASSES reaches jtpspike_objscan: 2 for the vsystem_spr2 pritype 0/1 cores,
// 1 for pritype 2 (f1gp), where the chip makes a single pass
module jtpspike_obj #(parameter PASSES=2)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               en,
    input               flip,
    input      [ 8:0]   hdump, vrender,
    input      [ 8:0]   hsize, vsize,   // visible width/height from the GGA
    input      [ 8:0]   xorg,           // this chip's horizontal origin
    input      [ 8:0]   xflip, yflip,   // extra shift applied only when flipped
    input      [ 8:0]   xoffs, yoffs,

    input      [ 1:0]   objbank,

    // sprite RAM
    output     [ 9:1]   objr_addr,
    input      [15:0]   objr_dout,
    // tile lookup RAM
    input               wide_lut,
    input      [14:0]   cmask,
    output     [15:1]   objl_addr,
    input      [15:0]   objl_dout,

    output     [21:2]   rom_addr,
    output              rom_cs,
    input      [31:0]   rom_data,
    input               rom_ok,

    output     [10:0]   pxl
);

wire [21:2] draw_addr;
wire [14:0] code, lut_addr;
wire [ 8:0] xpos;
wire [ 7:0] hzoom;
wire [ 6:0] pal;
wire [ 3:0] ysub;
wire        draw, busy, hz_keep, hflip, vflip;

// jtframe_objdraw's own mirror uses a compile time FLIP_OFFSET, which cannot
// follow a runtime width, so the mirror is done here instead
wire [ 8:0] hdump_eff = flip ? ~hdump   + hsize + {xorg[7:0],1'b0} + xflip : hdump;
wire [ 8:0] vrend_eff = flip ? ~vrender + vsize + yflip : vrender;

assign objl_addr = lut_addr;
// jtframe_draw emits {code, H, Y}, i.e. the two halves of a 16x16 tile stored
// 16 rows apart. gfx_16x16x4_packed_lsb is row major - one row is 8 bytes, so
// the halves are adjacent and the row is the upper field: {code, Y, H}.
// Without this the tile comes out in scrambled quarters
assign rom_addr  = { draw_addr[21:7], draw_addr[5:2], draw_addr[6] };

jtpspike_objscan #(.PASSES(PASSES)) u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .hs         ( hs        ),
    .scan_en    ( en        ),
    .vrender    ( vrend_eff ),
    .xoffs      ( xoffs     ),
    .yoffs      ( yoffs     ),
    .flip       ( flip      ),
    .objbank    ( objbank   ),

    .objr_addr  ( objr_addr ),
    .objr_dout  ( objr_dout ),
    .wide_lut   ( wide_lut  ),
    .cmask      ( cmask     ),
    .objl_addr  ( lut_addr  ),
    .objl_dout  ( objl_dout ),

    .draw       ( draw      ),
    .busy       ( busy      ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       )
);

jtframe_objdraw #(
    .CW         ( 15        ),
    .PW         ( 11        ),
    .ZW         ( 8         ),
    .ZI         ( 6         ),
    .ZENLARGE   ( 1         ),
    .HJUMP      ( 0         ),
    // HFIX keeps the readout counter climbing until HS, assuming hdump wraps
    // inside the sync pulse. Ours wraps at H=451, well after HS ends at 424,
    // so hdfix never resyncs: it runs past 511 and only reaches 0 near H=51,
    // leaving the first ~53 pixels reading the far end of the line buffer
    .HFIX       ( 0         ),
    .LATCH      ( 1         ),
    .ALPHA      ( 15        ), // the VS8904 transparent pen is 15, not 0
    // gfx is packed_lsb: leftmost pixel in the low nibble, which is what
    // jtframe_draw consumes (LSB first). Note jtframe_tilemap wants the
    // opposite, so the tile layer builds its planes by hand
    .PACKED     ( 1         )
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( 1'b0      ),  // mirrored above
    .hdump      ( hdump_eff ),

    .draw       ( draw      ),
    .busy       ( busy      ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( draw_addr ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule
