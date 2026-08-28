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
    Date: 28-8-2026 */

// 8x8 character layer, 64x32 map, TILEMAP_SCAN_ROWS.
//
//   code = fgvram[row*64+col]; tile = code & 0x7fff; flipY on code[15]
//   transparent pen 0xff, palette base 0
//
// gfx_8x8x8_raw is CHUNKY - one byte is one pixel, no planes - so a 32-bit
// read is four finished pixels and there is nothing to de-interleave. That
// is why this does not use jtframe_tilemap: that module extracts pixel bit i
// from byte i, which is the planar layout, and it would want a 64-bit bus
// for BPP=8 anyway. Here a tile row is 8 bytes = two reads.

module jtf1grpr_fg(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 8:0] hdump, vdump,
    input      [ 8:0] scrx, scry,

    output     [11:1] fgv_addr,
    input      [15:0] fgv_dout,

    output     [20:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl          // 0xff is transparent
);

// Calibration against MAME's screen.png: the layer sits 1 pixel right and
// 8 lines low without these. The 8 lines are common to every layer and are
// probably the visarea origin (MAME shows lines 8..247), so they may fold
// into the video timing later
localparam [8:0] HOFFSET = 9'd1, VOFFSET = 9'd8;

wire [ 8:0] heff = hdump + scrx + HOFFSET;
wire [ 8:0] veff = vdump + scry + VOFFSET;
// address the tile that owns the NEXT group of four pixels, so the VRAM and
// the ROM both have a full group of pxl_cen to answer
wire [ 8:0] hnx  = heff + 9'd4;
wire [14:0] code = fgv_dout[14:0];
wire        vflip= fgv_dout[15];
wire [ 2:0] row  = vflip ? ~veff[2:0] : veff[2:0];

assign fgv_addr = { veff[7:3], hnx[8:3] };
// 64 bytes a tile, 8 a row, 4 a read: word = code*16 + row*2 + half
assign rom_addr = { code, row, hnx[2] };
assign rom_cs   = 1'b1;

reg [31:0] cur, nxt;

always @(posedge clk) begin
    if( rst ) begin
        cur <= 0;
        nxt <= 0;
    end else if( pxl_cen ) begin
        if( rom_ok ) nxt <= rom_data;
        // swap in the group that was fetched over the previous four pixels
        if( heff[1:0]==2'd3 ) cur <= nxt;
    end
end

// chunky bytes, leftmost pixel in the lowest byte address. jtframe returns a
// 32-bit read with the lowest address in [7:0]
reg [7:0] pxl_r;
always @* begin
    case( heff[1:0] )
        2'd0: pxl_r = cur[ 7: 0];
        2'd1: pxl_r = cur[15: 8];
        2'd2: pxl_r = cur[23:16];
        2'd3: pxl_r = cur[31:24];
    endcase
end
assign pxl = pxl_r;

endmodule
