/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-2-2025 */

module jtframe_coremod(
    input  [17:0] core_mod,

    output       vertical,
                 lightgun_en,
                 dipflip_xor,
                 dial_raw_en,
                 dial_reverse,
    output [ 1:0] hblack_frame,
                  vblack_frame
);

assign vertical     = core_mod[0];
assign lightgun_en  = `ifdef JTFRAME_LIGHTGUN_ON 1'b1; `else core_mod[1]; `endif
assign dipflip_xor  = core_mod[2];
assign vblack_frame = core_mod[4:3];
assign hblack_frame = core_mod[6:5];
assign dial_raw_en  = core_mod[16];
assign dial_reverse = core_mod[17];

endmodule
