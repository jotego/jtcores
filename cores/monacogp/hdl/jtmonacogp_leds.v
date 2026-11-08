// SPDX-License-Identifier: GPL-3.0-or-later
// 96597-P sheet J (manual 420-0358, PDF page 22): the score display's scan,
// data selection and LED drive (docs/trace/SHEET_J_TRACE.md).
//
// - K9 (half 74393) counts V2 (from sheet I's pad c) on its falling edge;
//   QA..QC select one of eight rows: 2F (7445) pulls that row's line low,
//   and the sixteen 74151s pick the same input for the four digit columns.
// - Rows 0..4 (1ST..5TH) go through a NOR (2E-2, 12E) with that rank's
//   FLASH line from sheet I and an open-collector inverter (1E): the row is
//   on while selected and its FLASH line is low. Rows 5..7 (YOUR SCORE,
//   人中 = players to date, 位 = rank) are on while selected.
// - Column g (group 1 = units on the right .. group 4 = thousands) shows,
//   for rows 0..4, sheet K's rank digit g; row 5 the score P; rows 6 and 7
//   N and R in groups 2..4 (their digits 1..3) and, in group 1, the timer's
//   tens (T2) and units (T1) from sheet A, which reach the separate timer
//   display through connector H (H.A and H.1 are rows 6 and 7's commons).
// - 2A..2D (7448) decode each column to segments a..g, without blanking
//   (RBI, LT and BI/RBO are not wired); 1A..1D (75468) sink the segments
//   that are high.
//
// Outputs are the instantaneous drive: row_on[k] while row k's transistor
// conducts, seg[7*g + s] while column g's segment s (a = 0 .. g = 6) sinks
// current. A segment of a row is lit while both hold.
module jtmonacogp_leds(
    input             clk, rst,
    input             pxl_cen,
    input             v2,             // (I) V2
    input      [79:0] ranks,          // sheet K {5TH .. 1ST}, each {-4 .. -1}
    input      [15:0] p,              // {P-4 .. P-1}
    input      [11:0] n, r,           // {N-3 .. N-1}, {R-3 .. R-1}
    input       [3:0] t1, t2,         // sheet A timer units (T1) and tens (T2)
    input       [5:1] flash,          // 1ST..5TH FLASH
    output      [2:0] scan,           // K9 QC..QA
    output      [7:0] row_on,
    output     [27:0] seg             // {group 4 g..a, .., group 1 g..a}
);
    reg [3:0] k9;
    reg v2_l;
    always @(posedge clk) begin
        if (rst) begin k9 <= 0; v2_l <= 0; end
        else if (pxl_cen) begin
            v2_l <= v2;
            if (v2_l && !v2) k9 <= k9 + 4'd1;
        end
    end
    assign scan = k9[2:0];

    // 7448 outputs a..g (bit 0 = a) for 0..15, no blanking
    function [6:0] seg7(input [3:0] x);
        case (x)
        4'd0: seg7 = 7'b0111111;  4'd1: seg7 = 7'b0000110;  4'd2: seg7 = 7'b1011011;
        4'd3: seg7 = 7'b1001111;  4'd4: seg7 = 7'b1100110;  4'd5: seg7 = 7'b1101101;
        4'd6: seg7 = 7'b1111100;  4'd7: seg7 = 7'b0000111;  4'd8: seg7 = 7'b1111111;
        4'd9: seg7 = 7'b1100111;  4'd10: seg7 = 7'b1011000; 4'd11: seg7 = 7'b1001100;
        4'd12: seg7 = 7'b1100010; 4'd13: seg7 = 7'b1101001; 4'd14: seg7 = 7'b1111000;
        default: seg7 = 7'b0000000;
        endcase
    endfunction

    // the sixteen 74151s: input D<scan> of each column g (group g+1)
    reg [15:0] dig;
    wire [15:0] nt = {n, t2}, rt = {r, t1};   // group 1 shows the timer
    integer g;
    always @* begin
        for (g = 0; g < 4; g = g + 1)
            case (scan)
            3'd0, 3'd1, 3'd2, 3'd3, 3'd4: dig[4*g +: 4] = ranks[16*scan + 4*g +: 4];
            3'd5: dig[4*g +: 4] = p[4*g +: 4];
            3'd6: dig[4*g +: 4] = nt[4*g +: 4];
            default: dig[4*g +: 4] = rt[4*g +: 4];
            endcase
    end
    assign seg = {seg7(dig[15:12]), seg7(dig[11:8]), seg7(dig[7:4]), seg7(dig[3:0])};
    wire [7:0] sel = 8'd1 << scan;
    assign row_on = sel & {3'b111, ~flash};
endmodule
