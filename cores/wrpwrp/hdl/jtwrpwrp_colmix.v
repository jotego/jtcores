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
wire [7:0] ball_only = {8{ball}};
wire [7:0] ball_rg   = ball ? 8'd183 : 8'd0;
wire [7:0] ball_b    = ball ? 8'd191 : 8'd0;
wire [7:0] glyph_b   = (color[7] ? 8'd108 : 8'd0) + (color[6] ? 8'd51 : 8'd0);

assign red   = !visible ? 8'd0 : pixel ? mix(weight3(color[2:0]), ball_rg) : ball_only;
assign green = !visible ? 8'd0 : pixel ? mix(weight3(color[5:3]), ball_rg) : ball_only;
assign blue  = !visible ? 8'd0 : pixel ? mix(glyph_b, ball_b) : ball_only;

function [7:0] weight3(input [2:0] bits);
    weight3 = (bits[2] ? 8'd103 : 8'd0) +
              (bits[1] ? 8'd49  : 8'd0) +
              (bits[0] ? 8'd25  : 8'd0);
endfunction

function [7:0] mix(input [7:0] glyph, ball_level);
    reg [8:0] level;
    begin
        level = {1'b0, glyph} + {1'b0, ball_level};
        mix   = level[8] ? 8'hff : level[7:0];
    end
endfunction

endmodule
