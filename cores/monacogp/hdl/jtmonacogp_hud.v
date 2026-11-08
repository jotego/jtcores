// SPDX-License-Identifier: GPL-3.0-or-later
// Score, time and gear overlay. NOT original circuitry: the cabinet shows
// the score and time on LED displays (sheets I, J, K); this draws them over
// the picture, white on black boxes as big as
// the letters, for a MiSTer without those displays. OSD settings switch the
// two groups off.
//
// The picture is turned clockwise for the cabinet's monitor, so the text is
// drawn turned the other way: on the upright screen (240 wide, 360 tall) a
// point (u, w) is the raster's x = w, y = 239 - u. Layout on the upright
// screen (Aldo's sketch), numbers only, about 32 pixels in from the edges
// to stay clear of a CRT's overscan:
//   top left     the time, 2 digits
//   top right    the score, 4 digits
//   bottom left  HI or LOW (whichever gear is in)
module jtmonacogp_hud(
    input      [8:0] x, y,              // raster position, x 0..359, y 0..239
    input            show_score,        // TIME and SCORE
    input            show_gear,         // the gear
    input      [3:0] t_tens, t_units,   // sheet A timer
    input     [15:0] score,             // sheet I, thousands..units
    input            high_gear,
    input     [11:0] rgb_in,
    output reg [11:0] rgb_out
);
    localparam integer CH = 8;          // cell size on the upright screen
    function [7:0] digit(input [3:0] d);
        digit = d > 4'd9 ? "?" : "0" + {4'd0, d};
    endfunction
    // upright coordinates
    wire [8:0] u = 9'd239 - y;
    wire [8:0] w = x;

    // Fields: upright origin (u0, w0), up to 10 characters, text MSB first
    localparam [8:0] TIME_U = 32,  TIME_W = 40;
    localparam [8:0] SCORE_U = 176, SCORE_W = 40;     // 4 cells, right edge at 208
    localparam [8:0] GEAR_U = 32,  GEAR_W = 312;
    wire [79:0] t_time  = {digit(t_tens), digit(t_units), "        "};
    wire [79:0] t_score = {digit(score[15:12]), digit(score[11:8]), digit(score[7:4]), digit(score[3:0]), "      "};
    wire [79:0] t_gear  = {high_gear ? "HI " : "LOW", "       "};

    // one field: inside, the cell's character and the pixel within it
    reg        in_box;
    reg [79:0] text;
    reg [3:0]  len;
    reg [8:0]  du, dw;
    always @* begin
        in_box = 0; text = 0; len = 0; du = 0; dw = 0;
        if (show_score && w >= TIME_W && w < TIME_W + CH && u >= TIME_U && u < TIME_U + 2*CH) begin
            in_box = 1; text = t_time; len = 2; du = u - TIME_U; dw = w - TIME_W;
        end
        if (show_score && w >= SCORE_W && w < SCORE_W + CH && u >= SCORE_U && u < SCORE_U + 4*CH) begin
            in_box = 1; text = t_score; len = 4; du = u - SCORE_U; dw = w - SCORE_W;
        end
        if (show_gear && w >= GEAR_W && w < GEAR_W + CH && u >= GEAR_U && u < GEAR_U + (high_gear ? 2 : 3)*CH) begin
            in_box = 1; text = t_gear; len = high_gear ? 4'd2 : 4'd3; du = u - GEAR_U; dw = w - GEAR_W;
        end
    end
    wire [3:0] cidx = du[6:3];
    wire [7:0] ch = text[(4'd9 - cidx)*8 +: 8];
    wire       ink;
    // 5 x 7 glyph in the 8 x 8 cell, one pixel in from the box's edge
    wire [2:0] col = du[2:0] - 3'd1, row = dw[2:0] - 3'd1;
    wire       in_glyph = du[2:0] >= 3'd1 && du[2:0] <= 3'd5 && dw[2:0] >= 3'd1;
    jtmonacogp_font u_font(.ch(ch), .row(row), .col(col), .pix(ink));
    always @* rgb_out = in_box ? ((in_glyph && ink) ? 12'hfff : 12'h000) : rgb_in;
endmodule
