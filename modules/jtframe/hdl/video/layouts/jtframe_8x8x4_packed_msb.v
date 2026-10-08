/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

// converts pixel-packed data to plane-packed (MSB=left most pixel)
// packed gfxs; msb and lsb is start nibble of packed pixel byte
// const gfx_layout gfx_8x8x4_packed_msb =
// {
//     8,8,
//     RGN_FRAC(1,1),
//     4,
//     { STEP4(0,1) },
//     { STEP8(0,4) }, // x order : hi nibble first, low nibble second
//     { STEP8(0,4*8) },
//     8*8*4
// };

module jtframe_8x8x4_packed_msb(
    input   [31:0] raw,
    output  [31:0] sorted
);

assign sorted={
      raw[15], raw[11], raw[7], raw[3], raw[31], raw[27], raw[23], raw[19],
      raw[14], raw[10], raw[6], raw[2], raw[30], raw[26], raw[22], raw[18],
      raw[13], raw[ 9], raw[5], raw[1], raw[29], raw[25], raw[21], raw[17],
      raw[12], raw[ 8], raw[4], raw[0], raw[28], raw[24], raw[20], raw[16]
};

endmodule