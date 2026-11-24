/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_colmix(
    input      [7:0] color,
    input            pixel,
    input            ball,
    input            lhbl,
    input            lvbl,
    output     [7:0] red,
    output     [7:0] green,
    output     [7:0] blue
);

// 6N pin 1 drives R28/R39/R51 alongside the 6D/6E ladder.
wire visible = lhbl && lvbl;
wire [7:0] ball_only = ball ? 8'd180 : 8'd0;
wire [7:0] ball_rg   = ball ? 8'd129 : 8'd0;
wire [7:0] ball_b    = ball ? 8'd135 : 8'd0;
wire [7:0] glyph_b   = (color[7] ? 8'd76 : 8'd0) + (color[6] ? 8'd36 : 8'd0);

assign red   = !visible ? 8'd0 : pixel ? weight3(color[2:0]) + ball_rg : ball_only;
assign green = !visible ? 8'd0 : pixel ? weight3(color[5:3]) + ball_rg : ball_only;
assign blue  = !visible ? 8'd0 : pixel ? glyph_b + ball_b : ball_only;

function [7:0] weight3(input [2:0] bits);
    weight3 = (bits[2] ? 8'd73 : 8'd0) +
              (bits[1] ? 8'd35 : 8'd0) +
              (bits[0] ? 8'd18 : 8'd0);
endfunction

endmodule
