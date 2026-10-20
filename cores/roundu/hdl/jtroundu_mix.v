/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2026 */

module jtroundu_mix(
    input  signed [15:0] fm_left,
    input  signed [15:0] fm_right,
    input  signed [13:0] pcm,
    output signed [15:0] snd
);

wire signed [17:0] left_ext  = {{2{fm_left[15]}},fm_left};
wire signed [17:0] right_ext = {{2{fm_right[15]}},fm_right};
wire signed [17:0] pcm_ext   = {{4{pcm[13]}},pcm};
wire signed [17:0] mixed = (left_ext >>> 2) + (right_ext >>> 2) + (pcm_ext <<< 1);

assign snd = mixed > 32767 ? 16'h7fff : mixed < -32768 ? 16'h8000 : mixed[15:0];

endmodule
