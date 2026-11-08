// SPDX-License-Identifier: GPL-3.0-or-later
// 96597-P sheet K (manual 420-0358, PDF page 24): the five rank latches.
// docs/trace/SHEET_K_TRACE.md. Each rank 1ST..5TH is three 74174s (16 of
// their 18 flip-flops) that take sheet I's D bus {D-4 .. D-1} on the rising
// edge of that rank's line from sheet I (10A); LATCH CL. clears all fifteen
// through 11D's two inverters.
//
// Timing: the rank lines come from jtmonacogp_rank.v's register, and the
// D bus with them; a rising edge is taken at the next host clock, while the
// D bus still shows the value it had at the edge (it changes at the earliest
// two 14 MHz enables later).
//
// Pro Monaco GP (manual 420-0525, sheet K, PDF page 20), selected by
// pro = 1: pro/docs/trace/SHEET_K_TRACE.md.
// - The rank latches' /MR pins are tied to Vcc: LATCH CL. never clears
//   them (only the host reset rst does, standing for the power-up state).
// - SUPER RACER SCORE: three 74174s (43, 49, 57) take the live score P and a
//   constant 1 (57.13 = Vcc -> 57.12, FLAG) on CP = 66.8 = T.R.S AND 67.5,
//   67.5 being the A>B output of four cascaded 7485s (44, 50, 58, 67) with
//   A = P and B = the stored value S. Their /MR is /LATCH CL (latch_cl
//   high clears them). So at /GAME END after a game that passed 9999
//   (sheet I's 65 fires T.R.S), S takes the score's four digits if they are
//   at least the stored ones: the best score over 10,000 since the last
//   /LATCH CL, lost at power-off. FLAG enables the display and lights the
//   TODAY'S HIGH SCORE 10000PT. lamp (pad Ge).
// - K-U1: 44's cascade inputs are read A>B = Vcc, A=B = A<B = ground, which
//   makes 67.5 = P >= S (SRS_GE = 1, the default). With the usual tie
//   (A=B high) it would be P > S (SRS_GE = 0). Only equal scores differ.
// - The display drive (74153s 42/48, 9374 41, 7442 36, the digit drivers)
//   is not modelled: its digit selects *a, *b come from sheet J, which is
//   not traced on Pro. srs and srs_flag are the latch outputs.
// The same timing as the rank latches: an edge of CP is taken at the next
// host clock. With pro = 0, p and trs are ignored and srs, srs_flag stay 0.
module jtmonacogp_ranks #(
    parameter integer SRS_GE = 1      // K-U1: 1 = P >= S as read, 0 = P > S
)(
    input             clk, rst,
    input      [15:0] d,              // D bus {D-4 .. D-1}
    input       [4:0] ck,             // 1ST..5TH
    input             latch_cl,       // LATCH CL.; Pro: NOT /LATCH CL
    // Pro board; ignored while pro = 0
    input             pro,            // 1: Pro Monaco GP board
    input      [15:0] p,              // the score {P-4 .. P-1}
    input             trs,            // T.R.S (I, 65 Q)
    output reg [79:0] q,              // {5TH, 4TH, 3RD, 2ND, 1ST}, each {-4 .. -1}
    output reg [15:0] srs,            // SUPER RACER SCORE {S4 .. S1}
    output reg        srs_flag        // FLAG (57.12): TODAY'S HIGH SCORE 10000PT. lamp
);
    reg [4:0] ck_l;
    reg       srs_cp_l;
    integer k;
    // the 7485 chain, units (44) to thousands (67): 67.5 = A>B
    function cmp(input [15:0] a, b);
        cmp = SRS_GE != 0 ? a >= b : a > b;
    endfunction
    wire srs_cp = trs & cmp(p, srs);                    // 66.8
    always @(posedge clk) begin
        if (rst) begin
            q <= 0; ck_l <= 0; srs <= 0; srs_flag <= 0; srs_cp_l <= 0;
        end else begin
            ck_l <= ck;
            if (latch_cl && !pro) q <= 0;               // 11D 1 -> 2, 3 -> 4: /MR low
            else for (k = 0; k < 5; k = k + 1)
                if (ck[k] && !ck_l[k]) q[16*k +: 16] <= d;
            srs_cp_l <= srs_cp;
            if (!pro || latch_cl) begin                 // 43, 49, 57 /MR
                srs <= 0; srs_flag <= 0;
            end else if (srs_cp && !srs_cp_l) begin
                srs <= p; srs_flag <= 1'b1;
            end
        end
    end
endmodule
