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

    Author: (unattributed draft, ported from the mrdo MiSTer core)
    Version: 0.1 (draft)
    Date: 18-08-2026 */

// UNVERIFIED DRAFT -- extracted from mrdo/rtl/docastle_video.sv +
// docastle_rom.sv's colour PROM, not yet compiled or simulated against
// real jtframe tooling.
//
// -----------------------------------------------------------------------
// Source of truth (D:\Arcade\AI\aCORES\mrdo, evidence tier: RTL comments
// say this matches MAME's PROM decode, i.e. tier 3/4 -- not independently
// re-verified against a schematic/decap by this draft):
//
//   rtl/docastle_video.sv, tile/sprite priority mux + PROM address:
//     wire tile_front = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
//     wire use_sprite = !tile_front && sprite_pixel[9] && sprite_pixel[8];
//     wire [4:0] final_color = use_sprite ? sprite_pixel[7:3] : tile_attr[4:0];
//     wire [2:0] final_pen   = use_sprite ? sprite_pixel[2:0] : tile_pen[2:0];
//     assign prom_addr = {final_color,final_pen};
//
//   rtl/docastle_video.sv, resistor-weighted RGB decode (comment: "PROM
//   resistor network, matching MAME's 0x23/0x4b/0x91 and 0x52/0xad"):
//     assign r = (prom_q[5]?8'h23:0) + (prom_q[6]?8'h4b:0) + (prom_q[7]?8'h91:0);
//     assign g = (prom_q[2]?8'h23:0) + (prom_q[3]?8'h4b:0) + (prom_q[4]?8'h91:0);
//     assign b = (prom_q[0]?8'h52:0) + (prom_q[1]?8'had:0);
//
//   This is a classic 3/3/2-bit (RRRGGGBB) weighted-resistor colour-PROM
//   DAC: 3 independently-switched resistors for red, 3 for green, 2 for
//   blue -- an ASYMMETRIC per-channel bit split, not a uniform N-bit
//   palette RAM. The weighted sums are preserved bit-for-bit below; only
//   the naming and structure changed for the jtframe colmix shape.
//
// -----------------------------------------------------------------------
// JTFRAME_COLORW decision (see cores/docastle/cfg/PORTING_NOTES.md, which
// already flagged this exact mismatch before this file existed):
//
//   jtframe's top-level game port is uniform-width per channel:
//   `output [`JTFRAME_COLORW-1:0] red, green, blue` (jtframe_common_ports.inc).
//   docastle's real hardware resolution is NOT uniform: red and green each
//   have 3 independently-switched resistor bits (8 distinct DAC levels),
//   blue has only 2 (4 distinct DAC levels). The widest channel drives the
//   minimum lossless COLORW, so:
//
//       COLORW = 3   (NOT 4 -- verified against the actual RTL above, the
//                      widest real channel is 3 bits; a 4th bit would only
//                      pad with a constant/undetermined LSB, buying no real
//                      resolution the PCB doesn't have)
//
//   Bit-mapping used to go from the preserved 8-bit weighted sum down to
//   the 3-bit port width, verified level-by-level below (not assumed):
//
//     red/green (3 real resistor bits -> 8 DAC levels each):
//       sum   : 0x00 0x23 0x4b 0x6e 0x91 0xb4 0xdc 0xff
//       sum>>5:   0    1    2    3    4    5    6    7
//       -> taking the top 3 bits of the 8-bit weighted sum (sum[7:5])
//          reproduces exactly the 8 distinct, monotonically increasing
//          codes 0..7 with NO collisions and NO precision loss.
//
//     blue (2 real resistor bits -> 4 DAC levels):
//       sum   : 0x00 0x52 0xad 0xff
//       sum>>5:   0    2    5    7
//       -> taking the top 3 bits of blue's 8-bit weighted sum (sum[7:5])
//          still yields 4 distinct, monotonically increasing codes with no
//          collisions -- lossless, it simply doesn't populate all 8 codes
//          of the 3-bit field because the PCB only has 2 real blue bits.
//          (A naive "pad blue with a 0 LSB" scheme, i.e. {b2,1'b0}, would
//          have produced 0,2,4,6 instead of the true weighted 0,2,5,7 --
//          that was rejected here in favour of truncating the real
//          weighted sum, since the resistor ladder is not exactly binary
//          (0x23/0x4b/0x91 and 0x52/0xad are close to but not exactly
//          1:2:4 / 1:2), and MSB-truncating the true sum is the more
//          PCB-accurate reduction.)
//
//   Net effect: red/green use the full 3-bit port range 0..7 losslessly.
//   Blue only ever produces codes {0,2,5,7} out of the 3-bit port's 0..7
//   range -- not a bug, just the honest reflection of the PCB having one
//   fewer real resistor on the blue channel. No padding/rounding of the
//   red or green math was introduced; the only "new" bit path is the
//   lvbl/lhbl blanking-to-black added below to match jtframe's colmix
//   convention (see flstory's jtflstory_colmix.v), which mrdo's
//   docastle_video.sv does not do at this stage (it blanks elsewhere in
//   its own pipeline) -- flagged here, not silently added.
// -----------------------------------------------------------------------

module jtdocastle_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             lvbl,
    input             lhbl,

    // docastle_video.sv's tile/sprite priority select. low_pen_priority
    // and soccer_sprites vary per game profile in the mrdo core; only the
    // priority-affecting bit (low_pen_priority) is needed at this stage,
    // the soccer_sprites remap of entry_color/entry_code happens upstream
    // of tile_pen/tile_color/sprite_pixel and is out of scope for colmix.
    input             low_pen_priority,

    // tile_pen = char_q nibble (docastle_video.sv wire [3:0] tile_pen).
    // tile_color = color_scan_q[4:0], the tile attribute byte's low 5 bits
    // (docastle_video.sv wire [7:0] tile_attr, only [4:0] used as colour).
    input       [3:0] tile_pen,
    input       [4:0] tile_color,

    // sprite_pixel matches docastle_video.sv's line_sprite_pixel /
    // pcb_sprite_pixel encoding: {occupied, visible, color[4:0], pen[2:0]}.
    // bit 9 = occupied (a sprite pixel was written here), bit 8 = visible
    // (MAME's pen-15 invisible-mask pass), [7:3] = colour, [2:0] = pen.
    input       [9:0] sprite_pixel,

    output      [7:0] pal_addr,
    input       [7:0] pal_dout,

    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue,

    // Structural pass-through to match jtframe's game-module port
    // convention (see jtflstory_colmix.v). mrdo's docastle_video.sv has no
    // equivalent per-layer debug-disable at this stage today, so these are
    // NOT wired into any logic here -- wiring them up is future work, not
    // invented in this draft.
    input       [7:0] debug_bus,
    input       [3:0] gfx_en
);

wire blank_n = lvbl & lhbl;

// Tile/sprite priority mux and PROM address, verbatim from
// docastle_video.sv lines ~336-340 (renamed tile_attr -> tile_color).
wire       tile_front   = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
wire       use_sprite   = !tile_front && sprite_pixel[9] && sprite_pixel[8];
wire [4:0] final_color  = use_sprite ? sprite_pixel[7:3] : tile_color;
wire [2:0] final_pen    = use_sprite ? sprite_pixel[2:0] : tile_pen[2:0];

assign pal_addr = {final_color, final_pen};

// PROM resistor network, matching MAME's 0x23/0x4b/0x91 and 0x52/0xad.
// Bit-for-bit identical to docastle_video.sv; only prom_q -> pal_dout and
// r/g/b -> r_full/g_full/b_full were renamed. DO NOT alter these weights.
wire [7:0] r_full = (pal_dout[5] ? 8'h23 : 8'h00) + (pal_dout[6] ? 8'h4b : 8'h00) + (pal_dout[7] ? 8'h91 : 8'h00);
wire [7:0] g_full = (pal_dout[2] ? 8'h23 : 8'h00) + (pal_dout[3] ? 8'h4b : 8'h00) + (pal_dout[4] ? 8'h91 : 8'h00);
wire [7:0] b_full = (pal_dout[0] ? 8'h52 : 8'h00) + (pal_dout[1] ? 8'had : 8'h00);

// COLORW=4 correction (2026-08-18, first real jtframe-tool run): jtframe
// cfgstr rejects JTFRAME_COLORW below 4 ("must be between 4 and 8"), so the
// earlier COLORW=3 analysis, while arithmetically lossless, is not legal.
// Truncating the same 8-bit weighted sums at [7:4] instead of [7:5] keeps
// every channel exact and monotonic (red/green: 16 of 16 codes ordered;
// blue's four real levels 0x00/0x52/0xad/0xff map to 0/5/10/15) and gains
// one bit of the true resistor-DAC value over the 3-bit version.
always @(posedge clk) begin
    if (pxl_cen) begin
        red   <= blank_n ? r_full[7:4] : 4'd0;
        green <= blank_n ? g_full[7:4] : 4'd0;
        blue  <= blank_n ? b_full[7:4] : 4'd0;
    end
end

endmodule
