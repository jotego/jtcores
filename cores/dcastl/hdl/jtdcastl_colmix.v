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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

// Tile/sprite priority mux and colour-PROM resistor DAC. Ported from the
// standalone MiSTer Universal_DoCastle core this core derives from.
//
// -----------------------------------------------------------------------
// Colour PROM decode (evidence tier 3/4: matches MAME's PROM decode; not
// independently re-verified against a schematic or decap):
//
//   Tile/sprite priority mux + PROM address:
//     tile_front  = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
//     use_sprite  = !tile_front && sprite_pixel[9] && sprite_pixel[8];
//     final_color = use_sprite ? sprite_pixel[7:3] : tile_attr[4:0];
//     final_pen   = use_sprite ? sprite_pixel[2:0] : tile_pen[2:0];
//     prom_addr   = {final_color,final_pen};
//
//   Resistor-weighted RGB decode, matching MAME's 0x23/0x4b/0x91 and
//   0x52/0xad weights:
//     r = (prom_q[5]?8'h23:0) + (prom_q[6]?8'h4b:0) + (prom_q[7]?8'h91:0);
//     g = (prom_q[2]?8'h23:0) + (prom_q[3]?8'h4b:0) + (prom_q[4]?8'h91:0);
//     b = (prom_q[0]?8'h52:0) + (prom_q[1]?8'had:0);
//
//   This is a classic 3/3/2-bit (RRRGGGBB) weighted-resistor colour-PROM
//   DAC: 3 independently-switched resistors for red, 3 for green, 2 for
//   blue -- an ASYMMETRIC per-channel bit split, not a uniform N-bit
//   palette RAM. The weighted sums are preserved bit-for-bit below; only
//   the naming and structure changed for the jtframe colmix shape.
//
// -----------------------------------------------------------------------
// JTFRAME_COLORW = 4
//
//   jtframe's top-level game port is uniform-width per channel:
//   `output [`JTFRAME_COLORW-1:0] red, green, blue` (jtframe_common_ports.inc),
//   and jtframe's cfgstr requires JTFRAME_COLORW to be between 4 and 8.
//   docastle's real hardware resolution is not uniform: red and green each
//   have 3 independently-switched resistor bits (8 distinct DAC levels), blue
//   has only 2 (4 distinct DAC levels). The 8-bit weighted sums are therefore
//   truncated at [7:4], which is exact and monotonic for every real level:
//
//     red/green (3 real resistor bits -> 8 DAC levels each):
//       sum   : 0x00 0x23 0x4b 0x6e 0x91 0xb4 0xdc 0xff
//       sum>>4:   0    2    4    6    9   11   13   15
//       -> 8 distinct, monotonically increasing codes, no collisions.
//
//     blue (2 real resistor bits -> 4 DAC levels):
//       sum   : 0x00 0x52 0xad 0xff
//       sum>>4:   0    5   10   15
//       -> 4 distinct, monotonically increasing codes, no collisions.
//
//   Truncating the true weighted sum is preferred over padding a 3/3/2 field
//   with constant LSBs: the resistor ladder is not exactly binary
//   (0x23/0x4b/0x91 and 0x52/0xad are close to but not exactly 1:2:4 / 1:2),
//   so a naive "pad blue with a 0 LSB" scheme would give 0,4,8,12 rather than
//   the true weighted 0,5,10,15. MSB-truncating the real sum is the more
//   PCB-accurate reduction.
//
//   Net effect: each channel occupies only as many distinct codes as the PCB
//   really produces, with no padding or rounding of the weighted math. The
//   only bit path not present on the source pipeline is the lvbl/lhbl
//   blanking-to-black below, which follows jtframe's colmix convention (see
//   jtflstory_colmix.v); the source core blanks elsewhere in its own pipeline.
// -----------------------------------------------------------------------

module jtdcastl_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             lvbl,
    input             lhbl,

    // Tile/sprite priority select. low_pen_priority and soccer_sprites vary
    // per game profile; only the
    // priority-affecting bit (low_pen_priority) is needed at this stage,
    // the soccer_sprites remap of entry_color/entry_code happens upstream
    // of tile_pen/tile_color/sprite_pixel and is out of scope for colmix.
    input             low_pen_priority,

    // tile_pen = char ROM nibble.
    // tile_color = color_scan_q[4:0], the tile attribute byte's low 5 bits
    // (only [4:0] of the attribute byte are used as colour).
    input       [3:0] tile_pen,
    input       [4:0] tile_color,

    // sprite_pixel uses the line_sprite_pixel / pcb_sprite_pixel encoding:
    // {occupied, visible, color[4:0], pen[2:0]}.
    // bit 9 = occupied (a sprite pixel was written here), bit 8 = visible
    // (MAME's pen-15 invisible-mask pass), [7:3] = colour, [2:0] = pen.
    input       [9:0] sprite_pixel,

    output      [7:0] pal_addr,
    input       [7:0] pal_dout,

    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue,

    // Structural pass-through to match jtframe's game-module port
    // convention (see jtflstory_colmix.v). The board has no equivalent
    // per-layer debug-disable at this stage, so these are not wired into any
    // logic here. KNOWN LIMITATION: gfx_en/debug_bus are accepted but unused.
    input       [7:0] debug_bus,
    input       [3:0] gfx_en
);

wire blank_n = lvbl & lhbl;

// Tile/sprite priority mux and PROM address (tile_attr renamed tile_color).
wire       tile_front   = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
wire       use_sprite   = !tile_front && sprite_pixel[9] && sprite_pixel[8];
wire [4:0] final_color  = use_sprite ? sprite_pixel[7:3] : tile_color;
wire [2:0] final_pen    = use_sprite ? sprite_pixel[2:0] : tile_pen[2:0];

assign pal_addr = {final_color, final_pen};

// PROM resistor network, matching MAME's 0x23/0x4b/0x91 and 0x52/0xad.
// DO NOT alter these weights.
wire [7:0] r_full = (pal_dout[5] ? 8'h23 : 8'h00) + (pal_dout[6] ? 8'h4b : 8'h00) + (pal_dout[7] ? 8'h91 : 8'h00);
wire [7:0] g_full = (pal_dout[2] ? 8'h23 : 8'h00) + (pal_dout[3] ? 8'h4b : 8'h00) + (pal_dout[4] ? 8'h91 : 8'h00);
wire [7:0] b_full = (pal_dout[0] ? 8'h52 : 8'h00) + (pal_dout[1] ? 8'had : 8'h00);

// Truncation of the 8-bit weighted sums to the 4-bit JTFRAME_COLORW port
// width. Every real DAC level stays distinct and monotonic -- see the
// level-by-level table in the header.
always @(posedge clk) begin
    if (pxl_cen) begin
        red   <= blank_n ? r_full[7:4] : 4'd0;
        green <= blank_n ? g_full[7:4] : 4'd0;
        blue  <= blank_n ? b_full[7:4] : 4'd0;
    end
end

endmodule
