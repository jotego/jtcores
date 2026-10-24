/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_colmix — TC0260DAR replacement
// ============================================================================
//
// The TC0260DAR is a passive 12-bit RGBx_444 palette DAC (no internal
// logic in MAME — it's just a palette_device with RGBx_444 format,
// taito_b.cpp:1887). Palette RAM lives at 0x200000-0x201FFF and is
// owned by jttaitob_main.v's u_pal BRAM (2048 words = 4 KB).
//
// In Phase 2 this module *owns* the palette read:
//   1. Receives a 12-bit palette index from jttaitob_video.
//   2. Drives pal_addr_b into main.v's u_pal BRAM port-B.
//   3. Receives the 16-bit palette word.
//   4. Splits into 4-bit R/G/B channels (the "x" nibble at [15:12] is
//      unused — TC0260DAR has only 3 colour outputs).
//
// Palette word layout (TC0260DAR): MAME `palette_device::RGBx_444` —
// the "x" is the LOW nibble; R/G/B occupy the upper three nibbles:
//   bits [15:12] = R
//   bits [11: 8] = G
//   bits [ 7: 4] = B
//   bits [ 3: 0] = unused (x)
// The previous decode treated this as `xRGB_444` (x in HIGH nibble),
// which painted the BG plane olive-green where it should have been
// blue: the game's blue word `0x00B0` (R=0,G=0,B=B,x=0) ended up
// driving the GREEN channel.
//
// Note: the BRAM read latency is 1 clk cycle. pal_addr_b is registered
// in this module so the read result is stable on the next pxl_cen.
// ============================================================================

module jttaitob_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               LHBL,
    input               LVBL,

    // From jttaitob_video — 12-bit palette index (0..4095).
    // The MAME 4096-entry palette is laid out per the BG/FG/TX/sprite
    // color_base regions (0x00 sprite, 0x80 FG, 0xC0 BG, 0x00 text).
    // For Phase 2 only BG matters (high quarter of the palette).
    input        [11:0] pal_idx,

    // Palette RAM port-B — read interface to main.v's u_pal BRAM.
    // pal_addr_b indexes the full 4096-word (8 KB) palette RAM with the
    // 12-bit pal_idx. The BG color base 0xC0 lands at index 0xC00, which
    // is above the lower 2K, so the whole 12-bit index is needed.
    output reg   [11:0] pal_addr_b,
    input        [15:0] pal_dout_b,

    output reg   [ 3:0] red,
    output reg   [ 3:0] green,
    output reg   [ 3:0] blue
);

/* verilator lint_off UNUSED */
wire _unused = rst | pxl_cen | |pal_dout_b[3:0];
/* verilator lint_on UNUSED */

// Register the palette index so the BRAM read settles before pxl_cen
// fires the RGB latch. The visible-pipeline latency becomes 1 clk —
// invisible at 6.79 MHz pixel rate over 48 MHz system clk.
always @(posedge clk) begin
    pal_addr_b <= pal_idx[11:0];
end

always @(posedge clk) begin
    if (!LHBL || !LVBL) begin
        red   <= 4'd0;
        green <= 4'd0;
        blue  <= 4'd0;
    end else begin
        red   <= pal_dout_b[15:12];
        green <= pal_dout_b[11: 8];
        blue  <= pal_dout_b[ 7: 4];
    end
end

endmodule
