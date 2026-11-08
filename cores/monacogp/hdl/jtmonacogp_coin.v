// SPDX-License-Identifier: GPL-3.0-or-later
// 96577-P sheet A (manual 420-0358, PDF page 25): coin, test and credit
// switches, coin and game flip-flops, the game timer (555, IC21, IC20), the
// extended-play logic, tilt and the master clear.
// Pin-level transcription: docs/trace/SHEET_A_TRACE.md ("Consolidated
// netlist"). Behaviour: docs/SHEET_A_LOGIC.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). Like the sheet
// F control logic, the sheet is evaluated one pixel late: at edge 3 the
// inputs of the pixel are captured and the settled outputs of the pixel
// before are registered; every later host clock up to edge 2 of the next
// pixel (five or six clocks) is one settling step.
// Timing rule for one step ("settled layers", as for sheets B, D, F and G):
//   gates, the IC32 latches and the asynchronous clears, presets and loads
//   are combinational on the state; each flip-flop, counter and one-shot
//   compares its clock and trigger nets with their values at the previous
//   step and changes state for the next step. Three loops are cut by reading
//   a net of the previous step:
//   - IC22a reads IC20's /BO of the previous step (IC20 /BO -> IC22a ->
//     IC21 CPD -> IC21 /BO -> IC20 /BO, which latches /BO low at 00);
//   - IC61b reads IC50's stored Q (IC50 Q -> IC61b -> IC74 -> MCLR -> IC22b
//     -> IC50 /CLR);
//   - the 555 output is its stored state, its reset taking effect at the
//     next pixel (GAME -> 555 -> IC22a -> ... -> MCLR -> GAME).
//   IC38's second half reads EXTEND at the previous step for its A trigger
//   (MCLR clears EXTEND after it reaches IC38).
// The 555, the 74123 one-shots and the two RC pulse shapers (R14/C27,
// R15/C25) are counted in pixels at each edge 3. The CR switch filters, RA1/
// RA2/C12/C14/D1 on the tilt input and the 470 pF capacitors are not
// reproduced. pxl_cen must be at least six host clocks apart.
//
// Pro Monaco GP (manual 420-0525, sheet A, PDF page 8), selected by pro = 1:
// pro/docs/trace/SHEET_A_BONUS_TRACE.md. Two gates are added for the bonus
// circuit of sheet N; with pro = 0 the new inputs are ignored and the module
// is the original sheet A.
//   - IC59 (7432, 2, 1 -> 3) ORs BONUS SOUND into EX. CP before its buffer
//     (46, 1 -> 2) to pad A29: EX. CP = (V2 AND Vs/16 AND Q) OR BONUS SOUND.
//   - IC35 (9, 10 -> 8, NAND) of /COIN IN and /BONUS CP, then an inverting
//     buffer (13 -> 12) to pad A28, the sound board's copy of /COIN IN:
//     /COIN IN AND /BONUS CP. The game logic keeps the plain /COIN IN.
module jtmonacogp_coin #(
    // 74123 data sheet: tw = 0.28*R*C*(1+0.7/R), R in kohm, in periods of
    // 7.1525 MHz. Values as read from the scan.
    parameter integer TILT_PIXELS = 44898531, // IC38 pins 1-4, 13-15: R9 47k, C19 470 uF
    parameter integer IC49_PIXELS = 9552879,  // IC49: R13 47k, C24 100 uF
    parameter integer HI_PIXELS   = 9553,     // IC38 pins 5-7, 9-12: R8 47k, C15 0.1 uF
    // 555 astable, Ra = VR1 + R5 3.3k, Rb = R4, C5 47 uF: high ln 3 (Ra+Rb) C
    // after reset, then ln 2 (Ra+Rb) C, low ln 2 Rb C. VR1 (a trimmer) and R4
    // are not legible. A 59.94 fps video of a real game (Aldo, 30 October):
    // 89 shows for 87.94 frames (the first high phase and a low one) and a
    // game takes about 93 s, so a later count takes 1.039 s; then
    // (Ra+Rb) C = 1.0550 s and Rb C = 0.4446 s (with 47 uF: R4 9.5k, VR1 9.7k).
    parameter integer T555_FIRST  = 8289622,
    parameter integer T555_HIGH   = 5230169,
    parameter integer T555_LOW    = 2204053,
    // R14/C27 and R15/C25: 220 ohm x 1000 pF, about 235 ns to the input
    // threshold.
    parameter integer RC_PIXELS   = 2,
    // At power-up B (pin 2) of the tilt one-shot rises with the supply while
    // R7/C14 hold A low: the data sheet's B trigger. 1: the reset starts that
    // pulse (/INI RESET); 0: it does not.
    parameter integer POWERUP_TILT = 1
)(
    input            clk, rst,
    input            pxl_cen,
    // Cabinet. Each switch rests on its upper contact (to the latch /S
    // inputs); pressing it opens that contact and closes the lower one (/R).
    input            coin_sw,           // COIN SW pressed (pads Aa, A23, common AZ)
    input            test_sw,           // TEST SW pressed (pads Ab, A24)
    input            credit_sw,         // CREDIT SW pressed (pads AQ?, A32)
    input            two_play,          // changeover switch at 1 COIN 2 PLAY
    input            tilt_n,            // pad AJ: low while the TILT SW is closed
    // Other sheets
    input            acce_st,           // ACCE. ST. (F), sheet F IC34 pin 6
    input            game_over,         // GAME OVER (M), pad B16
    input            v2,                // V2 (E), pad C6
    input            vs16,              // Vs/16 (H)
    input            a30,               // pad A30 (S-100-D' from sheet I)
    // Pro board (sheet N); ignored while pro = 0
    input            pro,               // 1: Pro Monaco GP board
    input            bonus_sound,       // BONUS SOUND (N) -> IC59 pin 1
    input            bonus_cp_n,        // /BONUS CP (N) -> IC35 pin 10
    // Settled values for the previous pixel, registered at edge 3
    output reg       game,              // IC37 pin 9 -> pad A27 (I), sheet G 555
    output reg       game_n,            // IC37 pin 8 -> pad B6 (B), (F); pad AE (S)
    output reg       coin_in,           // IC37 pin 5 -> pad B1 (B)
    output reg       coin_in_n,         // IC37 pin 6 -> pad BD (B), (G); pad A28 (S)
    output reg       coin_test_n,       // IC125 pin 6 -> pad Ad (I); IC73 pin 4 -> (F)
    output reg       extend,            // IC50 pin 9 -> (F), pad BB (C)
    output reg       extend_n,          // IC50 pin 8 -> (G), pad B3 (C)
    output reg       ex_signal_n,       // IC49 pin 4 -> pad C1 (B)
    output reg       ex_signal_cp_n,    // IC55 pin 3 -> pad B2 (M)
    output reg       ex_cp,             // IC85 pin 12 -> pad A29 (S); Pro: IC59 pin 3, buffer 46
    output reg       snd_coin_in_n,     // pad A28 (S): /COIN IN through IC31; Pro: AND /BONUS CP
    output reg       car_cont_cl,       // IC55 pin 8 -> (H)
    output reg       pts8000,           // IC79 pin 6 -> (F)
    output reg       mute,              // IC31 pin 2 -> pad A26 (S)
    output reg       hiscore_n,         // IC38 pin 12 -> pad AF (S)
    output reg       ini_reset_n,       // IC38 pin 4 -> pads AR (I), BA (B)
    output reg [3:0] t1, t2,            // IC21, IC20 QD..QA -> display (J)
    output reg       coin_meter,        // IC44 pin 6: TR1 drives the coin meter (pad A9)
    output reg       credit_lamp,       // IC12 pin 8 low: the LED is lit
    // Tests only
    output reg [27:0] dbg,              // internal state, previous pixel
    output           busy               // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge3 = cen_sr[2];

    // Captured inputs
    reg i_coin, i_test, i_credit, i_2play, i_tilt_n, i_acce_st, i_game_over, i_v2, i_vs16, i_a30;
    reg i_pro, i_bonus_sound, i_bonus_cp_n;

    // State
    reg        f37a, f37b, f33, f50a, f50b, bo20_r, s555, a555;
    reg  [3:0] c21, c20, c79;
    reg [25:0] m_tilt;
    reg [23:0] m49, m38, c555;
    reg [RC_PIXELS-1:0] d27, d25;
    // Clock and trigger nets at the previous step
    reg ct_l, acce_l, sw1_l, cpd21_l, bo21_l, excp_l, a30_l, tilt_l, mclr_l, ext_l;

    // ---------------------------------------------------------------- switches
    // IC32 (74279): Q = 1 while a /S is low, 0 while only /R is low.
    wire l_coin = !i_coin;                         // /S (drawn 5) = COIN upper, /R = lower
    wire l_test = !i_test;                         // /S1, /S2 = TEST upper, /R = lower
    // IC72 (8, 9 -> 10) = NOR(IC37 pin 5, IC33 pin 8)
    wire q37a, q33_n;
    wire x72 = ~(q37a | q33_n);
    wire l_credit = !(x72 & i_credit);             // /S1 = IC72 pin 10, /S2 = CREDIT upper, /R = lower
    // Changeover switch: common to IC33 CK and IC125 pin 3; 1 PLAY = 1k to
    // Vcc, 2 PLAY = the credit latch.
    wire sw1 = i_2play ? l_credit : 1'b1;
    // IC125 (3, 4, 5 -> 6): /COIN & TEST, low while a switch is pressed.
    wire ct = sw1 & l_test & l_coin;

    // ---------------------------------------------------------------- tilt and clears
    wire tilt_q = m_tilt != 0;                     // IC38 pin 13 = timer CLEAR (TCLR)
    // IC61b (11, 12 -> 13) = NOR(IC20 /BO, IC50 pin 5), reading IC50's stored Q.
    wire bo20;
    wire ic61_13 = ~(bo20 | f50a);
    // IC74 (11, 9, 10 -> 8): MCLR = NOR(GAME OVER, TCLR, IC61 pin 13).
    wire mclr = ~(i_game_over | tilt_q | ic61_13);
    assign q37a = mclr & f37a;                     // COIN IN
    wire q37b = mclr & f37b;                       // GAME
    // IC33: /PR = coin latch, D = GND, CK = changeover common, /CLR = tilt /Q.
    wire q33 = !l_coin | (tilt_q ? 1'b0 : f33);
    assign q33_n = (!l_coin && tilt_q) ? 1'b1 : ~q33;

    // ---------------------------------------------------------------- game timer
    // IC21 (units) and IC20 (tens), 74192 counting down; CLR = TCLR,
    // /LOAD = /COIN & TEST (00 + 90), CPU at Vcc.
    wire [3:0] q21 = tilt_q ? 4'd0 : !ct ? 4'd0 : c21;
    wire [3:0] q20 = tilt_q ? 4'd0 : !ct ? 4'd9 : c20;
    wire cpd21 = s555 & bo20_r;                    // IC22a (4, 5 -> 6)
    wire bo21 = ~(q21 == 0 && !cpd21);             // IC21 pin 13 -> IC20 CPD
    assign bo20 = ~(q20 == 0 && !bo21);            // IC20 pin 13

    // ---------------------------------------------------------------- extended play
    // IC22b (12, 13 -> 11) = AND(/COIN & TEST, MCLR): the clear of IC50.
    wire cl22 = ct & mclr;
    wire q50a = cl22 & f50a;
    // IC55b (4, 5 -> 6) = OR(IC50 pin 6, IC20 /BO): IC50's other half /PR.
    wire ic55_6 = ~q50a | bo20;
    wire q50b = !ic55_6 | (cl22 & f50b);           // EXTEND
    wire q50b_n = (!ic55_6 && !cl22) ? 1'b1 : ~q50b;
    // IC44 (9 -> 8), R14/C27, IC61a (5, 6 -> 4): a pulse as IC55 pin 6 falls;
    // IC55a (10, 9 -> 8) adds IC73 pin 2 (inverted /COIN & TEST).
    wire ic61_4 = ~(ic55_6 | d27[RC_PIXELS-1]);
    wire cc_cl = ic61_4 | ~ct;
    // IC79 (74393 half): CP = A30 (falling), MR = IC73 pin 2.
    wire [3:0] q79 = !ct ? 4'd0 : c79;
    // IC55c (12, 13 -> 11) = OR(IC79 QA, /GAME); IC73 (13 -> 12), R15/C25,
    // IC55d (2, 1 -> 3): /EX. SIGNAL CP, a low pulse as QA falls in a game.
    wire ic55_11 = q79[0] | ~q37b;
    wire excp_n = ic55_11 | d25[RC_PIXELS-1];
    wire q49 = m49 != 0;
    wire q38b = m38 != 0;

    // ---------------------------------------------------------------- one-shot triggers
    // 74123: A falling while B is high, or B rising while A is low (/CLR at Vcc).
    wire trig_tilt = tilt_l & ~i_tilt_n;
    wire trig49 = excp_l & ~excp_n;
    // IC38's second half: A = MCLR, B = EXTEND. MCLR also clears EXTEND (through
    // IC22b and IC50), which falls only after A has: B is read at the previous
    // step for the A trigger, so a game cleared with EXTEND set gives /HISCORE.
    wire trig38 = (mclr_l & ~mclr & ext_l) | (~ext_l & q50b & ~mclr);

    wire [27:0] state = {f37a, f37b, f33, f50a, f50b, q37a, q37b, q33, q50a, q50b,
                         q21, q20, q79, bo20, s555, tilt_q, q49, q38b, ct};
    wire [9:0] nets   = {ct, i_acce_st, sw1, cpd21, bo21, excp_n, i_a30, i_tilt_n, mclr, q50b};
    wire [9:0] nets_l = {ct_l, acce_l, sw1_l, cpd21_l, bo21_l, excp_l, a30_l, tilt_l, mclr_l, ext_l};
    wire n37a = !mclr ? 1'b0 : (ct && !ct_l) ? 1'b1 : f37a;
    wire n37b = !mclr ? 1'b0 : (i_acce_st && !acce_l) ? q37a : f37b;
    wire n33  = !l_coin ? 1'b1 : tilt_q ? 1'b0 : (sw1 && !sw1_l) ? 1'b0 : f33;
    wire n50a = !cl22 ? 1'b0 : (excp_n && !excp_l) ? 1'b1 : f50a;
    wire n50b = q50b;
    wire [3:0] n21 = (cpd21 && !cpd21_l && ct && !tilt_q) ? (q21 == 0 ? 4'd9 : q21 - 4'd1) : q21;
    wire [3:0] n20 = (bo21 && !bo21_l && ct && !tilt_q) ? (q20 == 0 ? 4'd9 : q20 - 4'd1) : q20;
    wire [3:0] n79 = (!i_a30 && a30_l && ct) ? q79 + 4'd1 : q79;
    assign busy = nets != nets_l || bo20 != bo20_r || trig_tilt || trig49 || trig38 ||
                  {n37a, n37b, n33, n50a, n50b} != {f37a, f37b, f33, f50a, f50b} ||
                  {n21, n20, n79} != {c21, c20, c79};

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            {i_coin, i_test, i_credit, i_2play} <= 0;
            {i_tilt_n, i_acce_st, i_game_over, i_v2, i_vs16, i_a30} <= 6'b100001;
            {i_pro, i_bonus_sound, i_bonus_cp_n} <= 3'b001;
            {f37a, f37b, f33, f50a, f50b, s555} <= 0;
            a555 <= 1;
            bo20_r <= 0;
            c21 <= 0; c20 <= 0; c79 <= 0;
            // The board has no reset; this is the state just after power-up.
            m_tilt <= POWERUP_TILT ? TILT_PIXELS[25:0] : 26'd0;
            m49 <= 0; m38 <= 0; c555 <= T555_FIRST[23:0];
            d27 <= 0; d25 <= {RC_PIXELS{1'b1}};
            {ct_l, acce_l, sw1_l, cpd21_l, bo21_l, excp_l, a30_l, tilt_l, mclr_l, ext_l} <= 10'b1010011100;
            game <= 0; game_n <= 1; coin_in <= 0; coin_in_n <= 1; coin_test_n <= 1;
            extend <= 0; extend_n <= 1; ex_signal_n <= 1; ex_signal_cp_n <= 1; ex_cp <= 0;
            snd_coin_in_n <= 1;
            car_cont_cl <= 0; pts8000 <= 0; mute <= POWERUP_TILT != 0; hiscore_n <= 1;
            ini_reset_n <= POWERUP_TILT == 0; t1 <= 0; t2 <= 0; coin_meter <= 0; credit_lamp <= 0;
            dbg <= 0;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            if (edge3) begin
                // Settled outputs of the pixel just evaluated
                game <= q37b;
                game_n <= ~q37b;
                coin_in <= q37a;
                coin_in_n <= ~q37a;
                coin_test_n <= ct;
                extend <= q50b;
                extend_n <= q50b_n;
                ex_signal_n <= ~q49;
                ex_signal_cp_n <= excp_n;
                // IC85 (13, 1, 2 -> 12); Pro: the same AND (IC53), then IC59 (2, 1 -> 3)
                ex_cp <= (i_v2 & i_vs16 & q49) | (i_pro & i_bonus_sound);
                // IC31 (11 -> 10); Pro: IC35 (9, 10 -> 8) and the buffer (13 -> 12)
                snd_coin_in_n <= ~q37a & (~i_pro | i_bonus_cp_n);
                car_cont_cl <= cc_cl;
                pts8000 <= q79[3];
                mute <= tilt_q;
                hiscore_n <= ~q38b;
                ini_reset_n <= ~tilt_q;
                t1 <= q21;
                t2 <= q20;
                coin_meter <= ~l_coin;
                credit_lamp <= i_vs16 & x72;           // IC12 (10, 9 -> 8) low
                dbg <= state;
                // One pixel of the RC shapers, the one-shots and the 555
                d27 <= {d27[RC_PIXELS-2:0], ~ic55_6};
                d25 <= {d25[RC_PIXELS-2:0], ~q79[0]};
                if (m_tilt != 0) m_tilt <= m_tilt - 26'd1;
                if (m49 != 0) m49 <= m49 - 24'd1;
                if (m38 != 0) m38 <= m38 - 24'd1;
                // 555: its reset (pin 4) is GAME. Released, the output is high
                // for the first charge from 0 V, then alternates.
                // a555: the capacitor is discharged (reset held).
                if (!q37b) begin
                    s555 <= 0;
                    a555 <= 1;
                end else if (a555) begin
                    s555 <= 1;
                    a555 <= 0;
                    c555 <= T555_FIRST[23:0];
                end else if (c555 > 1) c555 <= c555 - 24'd1;
                else begin
                    s555 <= ~s555;
                    c555 <= s555 ? T555_LOW[23:0] : T555_HIGH[23:0];
                end
                // Capture the next pixel
                {i_coin, i_test, i_credit, i_2play} <= {coin_sw, test_sw, credit_sw, two_play};
                {i_tilt_n, i_acce_st, i_game_over, i_v2, i_vs16, i_a30} <=
                    {tilt_n, acce_st, game_over, v2, vs16, a30};
                {i_pro, i_bonus_sound, i_bonus_cp_n} <= {pro, bonus_sound, bonus_cp_n};
            end else begin
                // One settling step
                {ct_l, acce_l, sw1_l, cpd21_l, bo21_l, excp_l, a30_l, tilt_l, mclr_l, ext_l} <= nets;
                bo20_r <= bo20;
                {f37a, f37b, f33, f50a, f50b} <= {n37a, n37b, n33, n50a, n50b};
                c21 <= n21; c20 <= n20; c79 <= n79;
                if (trig_tilt) m_tilt <= TILT_PIXELS[25:0];
                if (trig49) m49 <= IC49_PIXELS[23:0];
                if (trig38) m38 <= HI_PIXELS[23:0];
            end
        end
    end
endmodule
