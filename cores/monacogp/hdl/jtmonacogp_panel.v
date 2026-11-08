// SPDX-License-Identifier: GPL-3.0-or-later
// The score display panel drawn over the picture. NOT original circuitry:
// the cabinet has a separate LED panel (sheet J's LED board: 1ST..5TH,
// YOUR SCORE, 人中 = players to date, 位 = rank) and the timer's two-digit
// display behind connector H; this draws what they show, for a MiSTer
// without them.
//
// It is driven by sheet J's multiplexed outputs, like the real LEDs: while
// row k's transistor conducts, the segments of that row are those on the 28
// segment lines, and they stay as captured until the row's next scan (one
// scan of the eight rows takes 64 lines). A row blanked by its FLASH line
// during its scan is dark until the next one, so the flashing shows as on
// the panel. Group 1 (units column) of rows 7 and 8 is not on the LED board:
// it goes through connector H to the timer display (row 7 = tens T2, row 8
// = units T1).
//
// Upright layout (240 x 360 screen, see jtmonacogp_hud.v for the raster
// mapping), a black box with red seven-segment digits. The red is the
// game's own full red, 12'hf00 (that of GAME OVER and +200, sheet C), and
// unlit segments are the box's black, so the panel adds no colour the game
// does not show:
//   1ST  dddd
//   2ND  dddd
//   3RD  dddd
//   4TH  dddd
//   5TH  dddd
//   SCORE dddd
//   OF    ddd     (人中, players to date)
//   RANK  ddd     (位)
//   TIME   dd     (timer display)
// The row names are the panel's printed captions, not drawn by the board.
//
// Pro Monaco GP (pro = 1) adds two lamps and a fourth display of the
// cabinet (pro/docs/trace/SHEET_I_TRACE.md and SHEET_K_TRACE.md), drawn as
//   SCORE#dddd    # = YOUR SCORE 10000POINT LAMP (sheet I's 56, pad G25)
//   ...
//   SUPER#dddd    SUPER RACER SCORE (sheet K's 43/49/57, S4..S1), and
//                 # = TODAY'S HIGH SCORE 10000PT. lamp (FLAG, pad Ge)
// The box grows by one line. The SUPER RACER SCORE digits are taken from
// the latches, not from sheet K's multiplexed display drive (its digit
// selects come from sheet J, not traced on Pro), and are lit while FLAG is
// set, as FLAG enables that display. Its 9374's segment table was not
// available (trace K-U2): the 7448 shapes of jtmonacogp_leds.v stand in.
// The same colours as the rest of the panel: the digits' lit segments and
// a lit lamp are 12'hf00, unlit ones the box's black.
// With pro = 0 the panel is unchanged.
//
// Pro Monaco GP (pro = 1) also adds the bonus lamp panel (sheet I's lamp unit
// behind PR-01/PR-02, jtmonacogp_lamps.v) in a second black box just below
// the (taller) panel box:
//   OVERTAKEN        "NUMBER OF CARS SUCCESSIVELY OVERTAKEN"
//   oooooooooooooo   14 lamps, lamp 1 on the left; 1..9 green, 10..14 red
//   BONUS X200       "BONUS POINTS (x200 PT.)"
//   oooooooooooooo   14 lamps, red
// Lit lamps are the game's own green 12'h0f0 and red 12'hf00 (sheet C
// drives each channel at 0, 8 or 15), unlit lamps the box's black. The
// number of lamps and the colours are Aldo's description of the cabinet
// (pro/docs/OBSERVATIONS.md: 9 green + 5 red on top, 14 red below), not the
// schematic. The wiring has 15 element lines per common; the 15th (unit
// pin 17) has no lamp drawn here, and the reconstructed PROMs never light it.
// The captions are shortened to fit the box. With pro = 0 nothing changes.
module jtmonacogp_panel(
    input             clk, rst, pxl_cen,
    input       [2:0] scan,
    input       [7:0] row_on,
    input      [27:0] seg,
    input       [8:0] x, y,
    input             show,
    // Pro board; ignored while pro = 0
    input             pro,            // 1: Pro Monaco GP board
    input             tenk,           // YOUR SCORE 10000POINT LAMP
    input      [15:0] srs,            // SUPER RACER SCORE {S4 .. S1}
    input             srs_flag,       // TODAY'S HIGH SCORE 10000PT. lamp
    input      [14:0] cars_lamps,     // lamp box, top bar: bit 0 = lamp 1 (leftmost)
    input      [14:0] bonus_lamps,    // lamp box, bottom bar: bit 0 = lamp 1
    input      [11:0] rgb_in,
    output reg [11:0] rgb_out
);
    // ---------------------------------------------------- LED persistence
    reg [8*28-1:0] lit;                 // row k at [28*k +: 28]
    always @(posedge clk) begin
        if (rst) lit <= 0;
        else if (pxl_cen) lit[28*scan +: 28] <= row_on[scan] ? seg : 28'd0;
    end

    // ---------------------------------------------------- layout
    wire [8:0] u = 9'd239 - y;          // upright column, 0 = left
    wire [8:0] w = x;                   // upright line, 0 = top
    localparam [8:0] U0 = 9'd64, W0 = 9'd88;     // box origin
    localparam [8:0] BW = 9'd112, BH = 9'd178;   // box size
    localparam [8:0] LH = 9'd19;                 // line pitch
    localparam [8:0] DU = 9'd56;                 // first digit column, from U0
    localparam [8:0] DP = 9'd12;                 // digit pitch
    wire [8:0] bh = pro ? BH + LH : BH;          // Pro: one more line
    wire in_box = show && u >= U0 && u < U0 + BW && w >= W0 && w < W0 + bh;
    wire [8:0] bu = u - U0, bw = w - W0;
    // line 0..8 (Pro: 0..9) and the position within it (8 px margin at the top)
    reg [3:0] line;
    reg [8:0] lw;
    integer j;
    always @* begin
        line = 4'd15; lw = 9'd0;
        for (j = 0; j < 10; j = j + 1)
            if ((j < 9 || pro) && bw >= 9'd8 + LH*j[8:0] && bw < 9'd8 + LH*j[8:0] + LH) begin
                line = j[3:0]; lw = bw - 9'd8 - LH*j[8:0];
            end
    end

    // captions, 6 characters from 8 px inside the box
    reg [47:0] cap;
    always @* case (line)
        4'd0: cap = "1ST   "; 4'd1: cap = "2ND   "; 4'd2: cap = "3RD   ";
        4'd3: cap = "4TH   "; 4'd4: cap = "5TH   "; 4'd5: cap = "SCORE ";
        4'd6: cap = "OF    "; 4'd7: cap = "RANK  "; 4'd8: cap = "TIME  ";
        4'd9: cap = "SUPER ";
        default: cap = "      ";
    endcase
    // Pro: the lamps, in the caption's sixth place of SCORE and SUPER
    wire in_lamp = pro && (line == 4'd5 || line == 4'd9) &&
                   bu >= 9'd49 && bu < 9'd55 && lw >= 9'd6 && lw < 9'd13;
    wire lamp_on = line == 4'd5 ? tenk : srs_flag;
    // 7448 outputs a..g (bit 0 = a) for 0..9, standing in for the 9374
    function [6:0] seg7(input [3:0] v);
        case (v)
        4'd0: seg7 = 7'b0111111;  4'd1: seg7 = 7'b0000110;  4'd2: seg7 = 7'b1011011;
        4'd3: seg7 = 7'b1001111;  4'd4: seg7 = 7'b1100110;  4'd5: seg7 = 7'b1101101;
        4'd6: seg7 = 7'b1111100;  4'd7: seg7 = 7'b0000111;  4'd8: seg7 = 7'b1111111;
        4'd9: seg7 = 7'b1100111;  default: seg7 = 7'b0000000;
        endcase
    endfunction
    wire       in_cap = bu >= 9'd8 && bu < 9'd8 + 9'd48 && lw >= 9'd6 && lw < 9'd13 && line != 4'd15;
    wire [8:0] cu = bu - 9'd8;
    wire [2:0] ci = cu[8:3];
    wire [7:0] ch = cap[(3'd5 - ci)*8 +: 8];
    wire [8:0] frow = lw - 9'd6;        // 0..6 inside in_cap
    wire       cap_ink;
    jtmonacogp_font u_font(.ch(ch), .row(frow[2:0]), .col(cu[2:0]), .pix(cap_ink));

    // digits: 4 positions (group 4 .. group 1) from DU, each 8 x 15
    wire [8:0] du = bu - DU;
    reg  [1:0] pos;
    reg        in_dig;
    reg  [3:0] su;                      // within the digit, 0..7
    always @* begin
        in_dig = 0; pos = 0; su = 0;
        if (bu >= DU && bu < DU + 4*DP && line != 4'd15 && lw >= 9'd2 && lw < 9'd17) begin
            pos = du < DP ? 2'd0 : du < 2*DP ? 2'd1 : du < 3*DP ? 2'd2 : 2'd3;
            su  = du - DP*pos;
            in_dig = su < 4'd8;
        end
    end
    wire [8:0] lw2 = lw - 9'd2;
    wire [3:0] sw = lw2[3:0];           // 0..14 inside a digit
    // segment a..g under this pixel
    reg [6:0] at;
    always @* begin
        at = 0;
        at[0] = sw == 0  && su >= 1 && su <= 6;                     // a
        at[1] = su == 7  && sw >= 1 && sw <= 6;                     // b
        at[2] = su == 7  && sw >= 8 && sw <= 13;                    // c
        at[3] = sw == 14 && su >= 1 && su <= 6;                     // d
        at[4] = su == 0  && sw >= 8 && sw <= 13;                    // e
        at[5] = su == 0  && sw >= 1 && sw <= 6;                     // f
        at[6] = sw == 7  && su >= 1 && su <= 6;                     // g
    end
    // the digit shown at (line, pos): group = 4 - pos
    reg [6:0] segs;
    reg       present;
    always @* begin
        segs = 0; present = 0;
        case (line)
            4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5: begin
                present = 1; segs = lit[28*line[2:0] + 7*(3-pos) +: 7];
            end
            4'd6: begin present = pos != 2'd3; segs = lit[28*6 + 7*(3-pos) +: 7]; end
            4'd7: begin present = pos != 2'd3; segs = lit[28*7 + 7*(3-pos) +: 7]; end
            4'd8: begin                                  // timer: tens, units
                present = pos >= 2'd2;
                segs = pos == 2'd2 ? lit[28*6 +: 7] : lit[28*7 +: 7];
            end
            4'd9: begin                                  // Pro: S4 S3 S2 S1
                present = 1; segs = srs_flag ? seg7(srs[4*(3-pos) +: 4]) : 7'd0;
            end
            default: ;
        endcase
    end
    wire on_seg  = in_dig && present && |(at & segs);

    // ---------------------------------------------------- Pro: lamp box
    wire       [8:0] lw0 = W0 + bh;              // just below the box (one line lower with pro)
    localparam [8:0] LBH = 9'd50;                // its height
    localparam [8:0] LU  = 9'd11;                // lamp 1's first column, from U0
    localparam [8:0] LP  = 9'd6;                 // lamp pitch: 5 lit, 1 gap
    localparam [3:0] GREEN = 4'd9;               // green lamps on the top bar (Aldo: 9 green, 5 red)
    localparam [8:0] NL  = 9'd14;                // lamps per bar (Aldo); line 15 has none
    wire in_lbox = show && pro && u >= U0 && u < U0 + BW && w >= lw0 && w < lw0 + LBH;
    wire [8:0] lbw = w - lw0;
    // top bar: caption at lbw 6..12, lamps at 16..21; bottom bar 21 lower
    wire       lrow = lbw >= 9'd27;              // 0: top bar, 1: bottom bar
    wire [8:0] lrw  = lrow ? lbw - 9'd21 : lbw;
    wire [79:0] lcap = lrow ? "BONUS X200" : "OVERTAKEN ";
    wire       in_lcap = bu >= 9'd8 && bu < 9'd8 + 9'd80 && lrw >= 9'd6 && lrw < 9'd13;
    wire [3:0] lci = cu[6:3];
    wire [7:0] lch = lcap[(4'd9 - lci)*8 +: 8];
    wire [8:0] lfrow = lrw - 9'd6;
    wire       lcap_ink;
    jtmonacogp_font u_lfont(.ch(lch), .row(lfrow[2:0]), .col(cu[2:0]), .pix(lcap_ink));
    wire [8:0] lu = bu - LU;
    wire [8:0] lk9 = lu / LP;
    wire [3:0] lk = lk9[3:0];                    // lamp 0..13 under this pixel
    wire       in_llamp = lrw >= 9'd16 && lrw < 9'd22 && bu >= LU && bu < LU + NL*LP &&
                         lu - LP*lk9 < LP - 9'd1;
    wire       lamp_lit = lrow ? bonus_lamps[lk] : cars_lamps[lk];
    wire [11:0] lamp_rgb = !lamp_lit ? 12'h000 : (!lrow && lk < GREEN) ? 12'h0f0 : 12'hf00;

    always @* begin
        if (in_lbox) rgb_out = in_llamp ? lamp_rgb : (in_lcap && lcap_ink) ? 12'hccc : 12'h000;
        else if (!in_box) rgb_out = rgb_in;
        else if (on_seg) rgb_out = 12'hf00;
        else if (in_lamp && lamp_on) rgb_out = 12'hf00;  // unlit: the box's black
        else if (in_cap && cap_ink) rgb_out = 12'hccc;
        else rgb_out = 12'h000;
    end
endmodule
