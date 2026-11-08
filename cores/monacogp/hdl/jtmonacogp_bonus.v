// SPDX-License-Identifier: GPL-3.0-or-later
// Pro Monaco GP, 96822-P sheet N (manual 420-0525, PDF page 12): the bonus
// circuit. IC132 counts cars, IC140 stores the bonuses (up during play, held
// at 15), and after the game IC94 opens V5 into the /BONUS POINT pulses while
// IC81 and IC80 divide them by 200 and step IC140 down to zero.
// Pin-level transcription: pro/docs/trace/SHEET_N_TRACE.md (second pass).
// Behaviour and tests: pro/docs/SHEET_N_LOGIC.md.
// The module only has to match the drawing. jtmonacogp_game.v connects it
// with PRO = 1 (sheets A, D, E, F, G and H; inputs as in
// pro/docs/trace/BONUS_INPUTS_TRACE.md). BONUS CP goes to sheet M and
// /GAME END to sheet I; BONUS A-D are not taken yet (sheet I's lamp PROMs
// have no dump).
//
// Readings taken as parameters or fixed here:
// - IC132 pin 9 (/LOAD) is not drawn. A floating TTL input reads high: it is
//   taken high, so IC132 never loads (its data inputs are at ground anyway).
// - IR (9 -> 8), IP (11 -> 10) and GPR (10, 9 -> 8) keep the trace's aliases;
//   their package labels (IC88? IC113?) do not change the logic.
// - Game over with exactly 0 or 15 stored bonuses is a race the drawing does
//   not settle (SHEET_F_BONUS_TRACE.md, U5): /GAME rising clocks IC94 while
//   the same edge, through R34, turns IC140 to count down, which changes
//   MAX/MIN and so IC94's clear (IC102). DU_LAG sets that order; see below.
// - Not settled either, and not a parameter (flagged here and in the logic
//   notes): when an IC100 first-half pulse ends while PR-38-7 and PR-38-9 are
//   both high, its /Q clocks IC132 in the same change that releases IC132's
//   clear (143.8 -> 143.6 -> 53.8, with C57 1000 pF on 53.9 slowing the
//   release on the board). In this model the asynchronous clear is
//   combinational and the clock acts on the settled nets, so the clear is
//   already released and IC132 counts 1. If C57 holds the clear past the
//   clock, the count stays 0 (pro/docs/trace/BONUS_INPUTS_TRACE.md).
// - The 74123 family is not printed. The widths use the 74123 data sheet
//   formula, as all the Monaco sheets do: 44, 13, 294 and 44 ms. The
//   74LS123's 0.45*R*C would give 70, 21, 465 and 70 ms; only the
//   *_PIXELS parameters would change.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). Like the
// Monaco sheet A and F control logic, the sheet is evaluated one pixel late:
// at edge 3 the inputs of the pixel are captured and the settled outputs of
// the pixel before are registered; every later host clock up to edge 2 of the
// next pixel (five or six clocks) is one settling step.
// Timing rule for one step ("settled layers", as for sheets A, B, D, F, G):
//   gates and the asynchronous clears and loads (IC80 CLR, IC81 /CLR, IC94
//   /CLR, IC132 /CLR, IC140 /LOAD, the 74123 /CLR) are combinational on the
//   state; each flip-flop, counter and one-shot compares its clock and
//   trigger nets with their values at the previous step and changes state
//   for the next step. Parts clocked by the same settled change act together
//   and see each other's new outputs one step later.
//   One simplification: each IC80 section's drawn QA -> CKB wire (80.3 ->
//   80.4, 80.13 -> 80.12) is taken inside the step, so a section counts as a
//   BCD decade at the falling edge of its CKA. The link between the sections
//   (80.7 -> 80.15) is a step like any other. With the links as steps, the
//   ripple from V5 to IC140 would need seven steps, more than a pixel has.
//   The reference keeps both wires as wires; only the moment inside the
//   pixel when 80.9 changes differs.
//   No loop of gates needs a cut.
// The 74123 one-shots are counted in pixels and decremented at each edge 3.
// Not reproduced: R34/C55 on /GAME (except as DU_LAG), C34, C37, C38, C54,
// C57 and the 680 pF capacitor on 132.2 (edge filters on the trigger and
// clock nets), and the open-collector outputs' pull-up waveforms.
// pxl_cen must be at least six host clocks apart.
module jtmonacogp_bonus #(
    // 74123 data sheet: tw = 0.28*R*C*(1+0.7/R), R in kohm, in periods of
    // 7.1525 MHz. Values as read from the scan.
    parameter integer IC100A_PIXELS = 315245,  // IC100 pins 1-4, 13-15: R20 47k, C39 3.3 uF
    parameter integer IC100B_PIXELS = 95529,   // IC100 pins 5-7, 9-12: R22 47k, C33 1 uF
    parameter integer IC107A_PIXELS = 2101633, // IC107 pins 1-4, 13-15: R24 47k, C41 22 uF
    parameter integer IC107B_PIXELS = 315245,  // IC107 pins 5-7, 9-12: R23 47k, C40 3.3 uF
    // Game over with 0 or 15 stored bonuses (U5, not settled by the drawing):
    // the number of steps by which /GAME reaches IC140 pin 5 (D/U, through
    // R34) after it reaches IC94's clock.
    //   0 (the model's natural order): the new direction and MAX/MIN reach
    //     IC94's clear before its clock acts. 0 stored: no payout, no pulse.
    //     15 stored: the full payout, 15 x 200 pulses.
    //   1: IC94 clocks on the up-count MAX/MIN. 15 stored: IC94 stays clear,
    //     no payout. 0 stored: IC94 sets and is cleared in the next step,
    //     before its Q is seen: no pulse.
    //   2: as 1 for 15. 0 stored: IC94's Q is high for one step; if V5 is
    //     high, 101.11 makes one short pulse that IC81 counts (the divider
    //     starts the next payout one count ahead). It is not a settled
    //     /BONUS POINT pulse.
    parameter integer DU_LAG = 0
)(
    input            clk, rst,
    input            pxl_cen,
    // Other sheets, named as drawn on N
    input            v2,                // V2 (A): 133.1, 21.13
    input            v4,                // V4 (F): 113.2
    input            v5,                // V5 (E), pad CC: 101.12
    input            coin_test_n,       // /COIN & TEST (A): 95.5
    input            ini_reset_n,       // /INI. RESET (A): 95.4
    input            bridge_ap_n,       // /BRIDGE AP (D), pad CD: 100.9
    input            player_st,         // PLAYER ST (G): 100.10, 100.2, 101.5
    input            other_car_n,       // /OTHER CAR (H): 100.1, 107.9
    input            game,              // GAME (A): 53.10
    input            game_n,            // /GAME (A): 94.11, 95.9, R34 -> 140.5
    input            score_st_n,        // /SCORE ST (G): 100.3, 107.11
    input            pr38_7,            // PR-38-7 (H): 143.9, GPR.10
    input            pr38_9,            // PR-38-9 (H): 143.10, GPR.9
    input            acc1_n,            // /ACC1 (F): 143.1, 143.2
    // Settled values for the previous pixel, registered at edge 3
    output reg       bonus_sound,       // 113.11 -> BONUS SOUND (A)
    output reg       bonus_point_n,     // IP.10 -> /BONUS POINT (F)
    output reg       game_end_n,        // 126.2 -> M5 /GAME END (I), R27 pull-up
    output reg [3:0] bonus,             // {D, C, B, A}: 126.4, 126.6, 126.10, 126.8 -> M4..M1 (I)
    output reg       bonus_cp,          // 107.13 -> CE BONUS CP (M)
    output reg       bonus_cp_n,        // 107.4 -> /BONUS CP (A)
    // Tests only
    output reg [23:0] dbg,              // internal state, previous pixel
    output           busy               // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge3 = cen_sr[2];

    // Captured inputs
    reg i_v2, i_v4, i_v5, i_ct_n, i_ini_n, i_bridge_n, i_player, i_other_n, i_game, i_game_n;
    reg i_score_n, i_pr7, i_pr9, i_acc1_n;

    // State
    reg        f81, f94;
    reg  [3:0] c80a, c80b, c132, c140;
    reg [21:0] m100a, m100b, m107a, m107b;
    reg        gn_l1, gn_l2;               // /GAME at the previous steps (DU_LAG)
    // Clock and trigger nets at the previous step
    reg ck81_l, ck80a_l, ck80b_l, ck132_l, ck140_l, ck94_l;
    reg oc_l, pl_l, ss_l, br_l, gpr_l, b107b_l;

    // ---------------------------------------------------------------- reset
    wire w01 = ~(i_ct_n & i_ini_n);              // 95.5, 4 -> 6: 80.2, 80.14, IR.9, 102.9
    wire w02 = ~w01;                             // IR 9 -> 8: 81.13, 53.11, 140.11

    // ---------------------------------------------------------------- bonus store
    // R34 -> 140.5 D/U: low counts up (during play), high counts down.
    wire du = DU_LAG == 0 ? i_game_n : DU_LAG == 1 ? gn_l1 : gn_l2;
    // IC140 (74191): /LOAD 11 = W02 (data 15, 1, 10, 9 at ground), /CTEN 4 at
    // ground, CLK 14 = 108.3. MAX/MIN 12: 15 counting up, 0 counting down.
    wire [3:0] q140 = w02 ? c140 : 4'd0;
    wire mm = du ? (q140 == 4'd0) : (q140 == 4'd15);
    // IC102 (9, 8 -> 10) = NOR(W01, MAX/MIN): IC94 /CLR.
    wire x102 = ~(w01 | mm);
    // IC94 (7474): D 12 and /PRE 10 at Vcc, CK 11 = /GAME, /CLR 13 = 102.10.
    wire q94 = x102 & f94;                       // Q 9 -> 101.13; /Q 8 -> 95.10
    // IC101 (12, 13 -> 11) = AND(V5, 94.9): 81.12 and IP.11.
    wire a101_11 = i_v5 & q94;
    // IC95 (10, 9 -> 8) = NAND(94.8, /GAME) -> 126.1 -> /GAME END.
    wire x95_8 = ~(~q94 & i_game_n);

    // ---------------------------------------------------------------- divider
    // IC81 (74107 half): J 1, K 4 at Vcc, CK 12 = 101.11 (falling), /CLR 13 = W02.
    wire q81 = w02 & f81;                        // Q 3 -> 80.1
    // IC80 (74390): CLR 2, 14 = W01. CKA1 1 = 81.3; QA 3 -> CKB 4; QD 7 ->
    // CKA2 15; QA 13 -> CKB 12; QD 9 -> 72.2.
    wire [3:0] q80a = w01 ? 4'd0 : c80a;         // {QD 7, QC 6, QB 5, QA 3}
    wire [3:0] q80b = w01 ? 4'd0 : c80b;         // {QD 9, QC 10, QB 11, QA 13}

    // ---------------------------------------------------------------- car counter
    // GPR (10, 9 -> 8) = NAND(PR-38-7, PR-38-9): 100.11 /CLR (and C54).
    wire gpr = ~(i_pr7 & i_pr9);
    // IC100 (74123). First half: A 1 = /OTHER CAR, B 2 = PLAYER ST, /CLR 3 =
    // /SCORE ST; Q 13, /Q 4. Second half: A 9 = /BRIDGE AP, B 10 = PLAYER ST,
    // /CLR 11 = GPR.8; Q 5, /Q 12.
    wire q100a = i_score_n & (m100a != 0);
    wire q100b = gpr & (m100b != 0);
    // IC143 (7410): 9, 10, 11 -> 8 = NAND(PR-38-7, PR-38-9, 100.13);
    // 13, 2, 1 -> 12 = NAND(143.8, /ACC1, /ACC1); 3, 4, 5 -> 6 = NOT 143.12.
    wire x143_8  = ~(i_pr7 & i_pr9 & q100a);
    wire x143_12 = ~(x143_8 & i_acc1_n);
    wire x143_6  = ~x143_12;
    // IC53 (9, 10, 11 -> 8) = AND(143.6, GAME, W02): IC132 /CLR 1.
    wire x53 = x143_6 & i_game & w02;
    // IC132 (74161): CLK 2 = 100.4 (/Q), ENP 7 and ENT 10 = 100.12 (/Q),
    // data 3-6 at ground, /LOAD 9 not drawn (taken high: never loads).
    wire [3:0] q132 = x53 ? c132 : 4'd0;         // {QD 11, QC 12, QB 13, QA 14}
    wire en132 = ~q100b;
    wire ck132 = ~q100a;
    wire rco = en132 & (q132 == 4'd15);          // RCO 15 -> 101.10

    // ---------------------------------------------------------------- bonus pulse
    wire a101_8 = rco & q100a;                   // 101 (10, 9 -> 8)
    wire a101_6 = q100b & i_player;              // 101 (4, 5 -> 6)
    wire x108_6 = a101_8 | a101_6;               // 108 (5, 4 -> 6): 107.10 (and C37)
    // IC107 (74123). Second half: A 9 = /OTHER CAR, B 10 = 108.6, /CLR 11 =
    // /SCORE ST; Q 5 -> 72.3 (and C38); /Q 12 not drawn. First half: A 1 at
    // ground, B 2 = 108.3, /CLR 3 at Vcc; Q 13 BONUS CP, /Q 4 /BONUS CP.
    wire q107b = i_score_n & (m107b != 0);
    wire q107a = m107a != 0;
    wire x72  = ~(q80b[3] | q107b);              // 72 (2, 3 -> 1)
    wire x108_3 = mm | x72;                      // 108 (1, 2 -> 3): 140.14, 107.2

    // ---------------------------------------------------------------- outputs
    // IC133 (74157): select 1 = V2, /G 15 at ground; A = IC132, B = IC140.
    wire [3:0] y133 = i_v2 ? q140 : q132;
    // IC21 (9, 10, 12, 13 -> 8) = NAND(100.13, 132.11, 132.12, V2)
    wire x21 = ~(q100a & q132[3] & q132[2] & i_v2);
    wire x113_3 = ~(i_v4 & q107a);               // 113 (2, 1 -> 3)
    wire x113_11 = ~(x113_3 & x21);              // 113 (12, 13 -> 11)

    // ---------------------------------------------------------------- triggers
    // 74123: A falling while B is high, B rising while A is low, /CLR rising
    // while A is low and B high; retriggerable; a low /CLR ends the pulse.
    wire trig100a = (oc_l & ~i_other_n & i_player) | (~pl_l & i_player & ~i_other_n) |
                    (~ss_l & i_score_n & ~i_other_n & i_player);
    wire trig100b = (br_l & ~i_bridge_n & i_player) | (~pl_l & i_player & ~i_bridge_n) |
                    (~gpr_l & gpr & ~i_bridge_n & i_player);
    wire trig107b = (oc_l & ~i_other_n & x108_6) | (~b107b_l & x108_6 & ~i_other_n) |
                    (~ss_l & i_score_n & ~i_other_n & x108_6);
    wire trig107a = ~ck140_l & x108_3;           // B rising, A at ground

    wire fall81  = ck81_l & ~a101_11;
    wire fall80a = ck80a_l & ~q81;
    wire fall80b = ck80b_l & ~q80a[3];
    wire rise132 = ~ck132_l & ck132;
    wire rise140 = ~ck140_l & x108_3;
    wire rise94  = ~ck94_l & i_game_n;

    function [3:0] bcd_inc(input [3:0] n);
        bcd_inc = n == 4'd9 ? 4'd0 : n + 4'd1;
    endfunction
    wire        n81  = !w02 ? 1'b0 : fall81 ? ~f81 : f81;
    wire        n94  = !x102 ? 1'b0 : rise94 ? 1'b1 : f94;
    wire [3:0]  n80a = w01 ? 4'd0 : fall80a ? bcd_inc(c80a) : c80a;
    wire [3:0]  n80b = w01 ? 4'd0 : fall80b ? bcd_inc(c80b) : c80b;
    wire [3:0]  n132 = !x53 ? 4'd0 : (rise132 && en132) ? c132 + 4'd1 : c132;
    wire [3:0]  n140 = !w02 ? 4'd0 : rise140 ? (du ? q140 - 4'd1 : q140 + 4'd1) : q140;

    wire [11:0] nets   = {a101_11, q81, q80a[3], ck132, x108_3, i_game_n,
                          i_other_n, i_player, i_score_n, i_bridge_n, gpr, x108_6};
    wire [11:0] nets_l = {ck81_l, ck80a_l, ck80b_l, ck132_l, ck140_l, ck94_l,
                          oc_l, pl_l, ss_l, br_l, gpr_l, b107b_l};
    wire [23:0] state  = {q81, q80a, q80b, q132, q140, q94, q100a, q100b, q107a, q107b, mm, w01};
    wire clr100a = !i_score_n && m100a != 0, clr100b = !gpr && m100b != 0;
    wire clr107b = !i_score_n && m107b != 0;
    assign busy = nets != nets_l || {gn_l1, gn_l2} != {i_game_n, gn_l1} ||
                  trig100a || trig100b || trig107a || trig107b || clr100a || clr100b || clr107b ||
                  {n81, n94, n80a, n80b, n132, n140} != {f81, f94, c80a, c80b, c132, c140};

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            // The board has no reset: this is the state after /INI. RESET.
            {i_v2, i_v4, i_v5} <= 0;
            {i_ct_n, i_ini_n, i_bridge_n, i_player, i_other_n, i_game, i_game_n} <= 7'b1110101;
            {i_score_n, i_pr7, i_pr9, i_acc1_n} <= 4'b1001;
            {f81, f94} <= 0;
            {c80a, c80b, c132, c140} <= 0;
            {m100a, m100b, m107a, m107b} <= 0;
            {gn_l1, gn_l2} <= 2'b11;
            {ck81_l, ck80a_l, ck80b_l, ck132_l, ck140_l, ck94_l} <= 6'b000111;
            {oc_l, pl_l, ss_l, br_l, gpr_l, b107b_l} <= 6'b101110;
            bonus_sound <= 0; bonus_point_n <= 1; game_end_n <= 0; bonus <= 0;
            bonus_cp <= 0; bonus_cp_n <= 1; dbg <= 0;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            if (edge3) begin
                // Settled outputs of the pixel just evaluated
                bonus_sound   <= x113_11;
                bonus_point_n <= ~a101_11;           // IP 11 -> 10
                game_end_n    <= x95_8;              // 126 (1 -> 2), open collector
                bonus         <= y133;               // 126 buffers, open collector
                bonus_cp      <= q107a;
                bonus_cp_n    <= ~q107a;
                dbg <= state;
                // One pixel of the one-shots
                if (m100a != 0) m100a <= m100a - 22'd1;
                if (m100b != 0) m100b <= m100b - 22'd1;
                if (m107a != 0) m107a <= m107a - 22'd1;
                if (m107b != 0) m107b <= m107b - 22'd1;
                // Capture the next pixel
                {i_v2, i_v4, i_v5} <= {v2, v4, v5};
                {i_ct_n, i_ini_n, i_bridge_n, i_player, i_other_n, i_game, i_game_n} <=
                    {coin_test_n, ini_reset_n, bridge_ap_n, player_st, other_car_n, game, game_n};
                {i_score_n, i_pr7, i_pr9, i_acc1_n} <= {score_st_n, pr38_7, pr38_9, acc1_n};
            end else begin
                // One settling step
                {ck81_l, ck80a_l, ck80b_l, ck132_l, ck140_l, ck94_l,
                 oc_l, pl_l, ss_l, br_l, gpr_l, b107b_l} <= nets;
                gn_l1 <= i_game_n;
                gn_l2 <= gn_l1;
                f81 <= n81; f94 <= n94;
                c80a <= n80a; c80b <= n80b; c132 <= n132; c140 <= n140;
                if (!i_score_n) m100a <= 0; else if (trig100a) m100a <= IC100A_PIXELS[21:0];
                if (!gpr)       m100b <= 0; else if (trig100b) m100b <= IC100B_PIXELS[21:0];
                if (!i_score_n) m107b <= 0; else if (trig107b) m107b <= IC107B_PIXELS[21:0];
                if (trig107a) m107a <= IC107A_PIXELS[21:0];
            end
        end
    end
endmodule
