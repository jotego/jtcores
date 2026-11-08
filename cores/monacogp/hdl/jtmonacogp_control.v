// SPDX-License-Identifier: GPL-3.0-or-later
// 96577-P sheet F (manual 420-0358, PDF page 26): accelerator, handle, gear
// shift, player start position and collision control.
// Pin-level transcription: docs/trace/SHEET_F_TRACE.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). Two parts:
//
// Position counters. IC19 counts 7 MHz pixels and IC40 counts the starts of
//   HS, like the sheet G counters: they step at edge 1 on the values of the
//   previous pixel, and a clear released on the counting edge wins.
//   PL-H-ST and PL-V-ST are therefore valid for the pixel in which they are
//   computed. Their targets (IC24/IC25 and IC35/IC36) come from the control
//   logic below, one pixel late.
// Control logic, evaluated one pixel late. At edge 3 the inputs of the pixel
//   are captured. Every later host clock up to edge 2 of the next pixel (five
//   or six clocks) is one settling step. At the next edge 3 the settled
//   outputs are registered, so other sheets see them during the following
//   pixel. The original gates take about as long: IC80 -> IC34 -> IC27 ->
//   IC33 -> IC23 -> IC16 is six TTL delays, roughly one 140 ns pixel.
// Timing rule for one step ("settled layers"): gates, latches and the
//   asynchronous load, clear and reset inputs are combinational on the state;
//   each edge-triggered part (74193, 74393, 7474, 74123) compares its clock
//   and trigger nets with their values at the previous step and changes its
//   state for the next step. So every part clocked by one settled change acts
//   in the same step, and sees the others' new outputs only in the next one.
//   Hazards (pulses of the gate delays) do not exist here. Two loops of gates
//   and latches are cut by reading a net of the previous step: IC27 pin 1 and
//   IC39's MR; IC1's halves clear each other one step late.
//   tests/sheet_f_reference.v implements the same rule with delays on a
//   pin-wired netlist. Where the real board's TTL delays race (when the crash
//   latch IC27 pin 7 sets, IC33 clocks while IC15 is loaded, and both reach
//   IC12 and IC9), the outcome follows this rule, not measured delays.
// 74123 pulses are counted in pixels and decremented at each edge 3.
// pxl_cen must be at least six host clocks apart. RC shaping (C3, C16, C17,
// the shift-lever filters) is not reproduced.
//
// Pro Monaco GP (manual 420-0525, sheet F, PDF page 9), selected by pro = 1:
// pro/docs/trace/SHEET_F_BONUS_TRACE.md. The normal score NAND's output is
// ANDed with /BONUS POINT from sheet N (the Pro board's IC8: lower input 9,
// upper input read 11 or 10, output 8) before the output buffer to pad A14:
// /SCORE CP = /BONUS POINT AND NOT(/SCORE ST AND Y). With pro = 0,
// /BONUS POINT is ignored. The score divider's clear is /GAME on both boards.
module jtmonacogp_control #(
    // 74123 data sheet: tw = 0.28*R*C*(1+0.7/R), R in kohm, in periods of
    // 7.1525 MHz. Values as read from the scan.
    parameter integer IC1A_PIXELS  = 448985,  // IC1 pins 1-4, 13-15: R3 47k, C2 4.7 uF
    parameter integer IC1B_PIXELS  = 448985,  // IC1 pins 5-7, 9-12: R2 47k, C1 4.7 uF
    parameter integer IC43A_PIXELS = 955288,  // IC43 /SLIP half: R11 47k, C20 10 uF
    parameter integer IC43B_PIXELS = 1432932, // IC43 /POOL(2) half: R10 47k, C18 15 uF
    parameter integer IC49_PIXELS  = 2101633  // IC49: 47k, C21 22 uF
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E. The /V lines (pads BU, B17, B18) are inverted here.
    input            h4, h5, h6, h8,     // pads C8, C7, CH, CF
    input            hs,                 // HS, active high; pad CJ carries /HS
    input      [7:4] v,                  // V4 pad BT; V6, V7 pads B12, BN
    // Sheet A
    input            coin_test_n,        // /COIN & TEST
    input            game_n,             // /GAME
    input            extend,             // EXTEND
    input            pts8000,            // 8000
    // Sheet H
    input            vs2, vs8, vs16, vs32, vs64,
    input            other_body_n,       // /OTHER BODY
    // Sheet D. /TUNNEL also leaves for (J) and /EXT. 500 for (H) unchanged.
    input            slip_n,             // /SLIP, pad CA
    input            pool2_n,            // /POOL(2), pad CM
    input            road,               // ROAD, pad B7
    input            tunnel_n,           // /TUNNEL, pad BF
    input            ext500_n,           // /EXT. 500, pad BJ
    // Sheet M
    input            rescue_n,           // /RESCUE (Y), pad B8
    input            bridge_n,           // /BRIDGE (W), pad BH
    input            ext_car_cont,       // EXT. CAR CONT., pad BZ
    // Sheet G
    input            sp_down_n,          // /SP DOWN: IC2 pins 2, 12
    input            sp_down,            // SP. DOWN: IC72 pin 12
    input            score_st_n,         // /SCORE ST.
    input            acc1_st_n,          // /ACC1. ST
    input            acc1_pulse_n,       // /ACC1. PULSE
    input            player,             // PLAYER
    // Cabinet
    input            acce_cont_a,        // ACCE. CONT. A, pad A11
    input            acce_cont_b,        // ACCE. CONT. B, pad AM
    input            han_l_cp,           // HAN.-L-CP, pad A8
    input            han_r_cp,           // HAN.-R-CP, pad AJ
    input            shift_no,           // shift lever NO line, pad A25 (low: closed to COM)
    input            shift_nc,           // shift lever NC line, pad AC
    // IC27 pin 3 (/S2 of the first latch) is not drawn
    input            ic27_3,
    // Pro board (sheet N); ignored while pro = 0
    input            pro,                // 1: Pro Monaco GP board
    input            bonus_point_n,      // /BONUS POINT (N)
    // Valid for the current pixel
    output           pl_h_st,            // IC17 pin 6 -> (G)
    output           pl_v_st,            // IC41 pin 6 -> (G)
    // Settled values for the previous pixel, registered at edge 3.
    // IC13 and IC29 (7417) are open-collector buffers; the pull-ups are elsewhere.
    output reg       shift,              // IC29 pin 8 -> pad AW (S)
    output reg       slipzone_n,         // IC29 pin 4 -> pad AX (S)
    output reg       nonroad_slip_n,     // IC29 pin 2 -> pad A20 (S) /NON ROAD & POOL SLIP
    output reg       acce_st,            // IC34 pin 6 -> (A)
    output reg [3:0] acce,               // ACCE. A..D = IC15 QA..QD -> (H); D also pad B14 (M);
                                         // the same bits leave as S-ACCE A..D (pads AP, A13, AN, A12)
    output reg       score_cp_n,         // IC13 pin 10 -> pad A14 (I)
    output reg       s_acc1_n,           // IC13 pin 12 -> pad AR (S)
    output reg       acc1_n,             // IC16 pin 3 -> (G)
    output reg       splay_a_n,          // IC48 pin 8 -> (G)
    output reg       splay_b_n,          // IC49 pin 5 (Q) -> (G), named /SPLAY B on the scan
    output reg       sp_irreg_n,         // IC80 pin 12 -> (H)
    output reg       home_pos_n,         // IC23 pin 8 -> (G)
    output reg [3:0] explo_sel,          // IC39 Q0..Q3 -> (G); D also pad BM (M)
    output reg       explo_st,           // IC33 pin 5 -> (G)
    output reg       explo_st_n,         // IC33 pin 6 -> (G)
    // Tests only
    output     [7:0] ic19_q, ic40_q,     // position counters, current pixel
    output reg [6:0] hpos_t,             // {IC24 QC..QA, IC25 QD..QA}, previous pixel
    output reg [7:0] vpos_t,             // {IC35, IC36}, previous pixel
    output reg [36:0] dbg,               // internal state, previous pixel
    output     [36:0] dbg_live,          // the same, at the current step
    output           busy                // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge1 = cen_sr[0];
    wire edge3 = cen_sr[2];

    // ---------------------------------------------------------------- position
    reg  [7:0] ic19_cnt, ic40_cnt;
    reg        mr19_l, mr40_l, hs_l;
    // IC19 MR = IC74 (1, 2, 13 -> 12) NOR(H5, IC68 pin 11, H8), IC68 (12, 13
    // -> 11) = NAND(H4, H6). IC40 MR = IC47 (9, 10, 12, 13 -> 8)
    // NOR(/V5, /V6, V4, /V7).
    wire mr19 = ~(h5 | ~(h4 & h6) | h8);
    wire mr40 = ~(v[4] | ~v[5] | ~v[6] | ~v[7]);
    assign ic19_q = mr19 ? 8'd0 : ic19_cnt;
    assign ic40_q = mr40 ? 8'd0 : ic40_cnt;
    // IC17/IC18: A = IC19 Q0..Q6 and Vcc, B = IC25, IC24 QA..QC and Vcc.
    // IC18 pin 3 (A=B cascade) is IC63 pin 13, the gated 7 MHz clock: the
    // output is high only in the half period after the count, and never once
    // IC19 pin 8 has stopped the clock.
    assign pl_h_st = !ic19_q[7] && ic19_q[6:0] == hpos_t;
    // IC41/IC42: A = IC35, IC36; B = IC40. Cascade inputs at Vcc.
    assign pl_v_st = ic40_q == vpos_t;

    // ---------------------------------------------------------------- control
    // Captured inputs
    reg [7:5] i_v;                      // V4 only clears IC40, in the position part
    reg i_coin_test_n, i_game_n, i_extend, i_8000;
    reg i_vs2, i_vs8, i_vs16, i_vs32, i_vs64, i_other_body_n;
    reg i_slip_n, i_pool2_n, i_road, i_tunnel_n, i_ext500_n;
    reg i_rescue_n, i_bridge_n, i_ext_car_cont;
    reg i_sp_down_n, i_sp_down, i_score_st_n, i_acc1_st_n, i_acc1_pulse_n, i_player;
    reg i_acce_a, i_acce_b, i_han_l, i_han_r, i_shift_no, i_shift_nc, i_27_3;
    reg i_pro, i_bonus_point_n;
    wire v5 = i_v[5], v6 = i_v[6], v7 = i_v[7];

    // State
    reg  [3:0] c15, c24, c25, c35, c36, c5, c39;
    reg        explo_r, l27a_r, l27b_r, l27d_r, l32_r, x_r;
    reg [21:0] m1a, m1b, m43a, m43b, m49;
    // Clock and trigger nets at the previous step
    reg up15_l, dn15_l, up25_l, dn25_l, co25_l, bo25_l;
    reg up36_l, dn36_l, co36_l, bo36_l, cp5_l, cp39_l, ck33_l;
    reg a1_l, b1a_l, b1b_l, clr1a_l, clr1b_l;
    reg slip_l, pool_l, player_l, qd15_l;

    // IC32 (74279 latch, pins 13-15): /S pin 15 = NC line, /R pin 14 = NO
    // line, each through RA2 100R with 0.1 uF to ground.
    wire l32 = !i_shift_nc | (i_shift_no & l32_r);

    // Collision: IC14 (9, 10, 12, 13 -> 8), IC80 (3, 4, 5 -> 6), IC34 (1, 2 -> 3).
    wire ic14_8 = ~(i_rescue_n & i_bridge_n & i_road & i_other_body_n);
    wire ic80_6 = ~(i_acc1_st_n & ic14_8 & i_player);
    wire ic34_3 = ic80_6 & i_acc1_pulse_n;

    // IC24/IC25 (74193 pair), /LOAD = /COIN & TEST: 0xF0. CLR grounded.
    // IC24 pin 7 (QD) is drawn tied to Vcc (see U2 in the trace).
    wire [3:0] q25 = i_coin_test_n ? c25 : 4'h0;
    wire [2:0] q24 = i_coin_test_n ? c24[2:0] : 3'b111;
    // IC35/IC36 (74193 pair), /LOAD = /COIN & TEST: 0x0F. CLR grounded.
    wire [3:0] q35 = i_coin_test_n ? c35 : 4'h0;
    wire [3:0] q36 = i_coin_test_n ? c36 : 4'hf;
    wire ic47_6 = ~|q35;                        // IC47 (1, 2, 4, 5 -> 6)
    // IC27 latch 1 (/R 1 = IC23 pin 3, /S1 2 = IC28 (3, 4, 5 -> 6), /S2 3, Q 4).
    // /R reads IC23 pin 3 of the previous step: this cuts the loop IC27.7 ->
    // IC23.3 -> IC27.1 -> IC27.4 -> IC44.2 -> IC23.8 -> IC27.5.
    wire ic28_6 = ~(&q24);
    wire l27a = !(ic28_6 & i_27_3) | (x_r & l27a_r);
    // IC23 (9, 10 -> 8) = OR(IC46 pin 2, IC44 pin 2) = NAND(IC47 pin 6, IC27 pin 4).
    wire home_n = ~ic47_6 | ~l27a;
    // IC27 latch 2 (/R 5, /S 6, Q 7), 74279: a low /S wins.
    wire l27b = !ic34_3 | (home_n & l27b_r);
    // IC33 (7474): CK = IC27 pin 7, D = EXTEND, /PR at Vcc, /CLR = IC23 (12,
    // 13 -> 11). explo_r is the stored state: a clock edge loads it at the
    // next step, a low /CLR forces Q low at once. IC39's MR reads the stored
    // state, which cuts the loop IC33.6 -> IC39.2 -> IC68.6 -> IC23.11 ->
    // IC33.1. It lags /Q only in the step in which /CLR empties IC33: there
    // IC39 cannot count (it counts falling clocks, and IC34 pin 8 can only
    // rise as IC68 pin 6 does) and IC69 selects the same inputs for S0 = 0
    // and 1.
    wire [3:0] q39 = explo_r ? c39 : 4'd0;      // IC39 MR = /EXPLO. ST.
    wire ic68_6 = ~(q39[2] & q39[3]);           // IC68 (4, 5 -> 6)
    wire clr33_n = ic68_6 | l27b;
    wire explo = clr33_n & explo_r;
    // IC23 (1, 2 -> 3); IC16 (12, 13 -> 11) and (1, 2 -> 3) invert it.
    wire x = explo | l27b;
    wire x_n = ~x;

    // IC15 (74193): CLR = /GAME, /LOAD = IC16 pin 11, data inputs grounded.
    wire [3:0] q15 = (i_game_n || x) ? 4'd0 : c15;
    // Accelerator unit through IC6 (Schmitt inverters 9 -> 8, 11 -> 10).
    wire ic6_8 = ~i_acce_a, ic6_10 = ~i_acce_b;
    wire ic16_6 = ic6_10 ^ ic6_8;               // IC16 (4, 5 -> 6)
    wire ic23_6 = ic6_10 | ic16_6;              // IC23 (4, 5 -> 6)
    wire ic22_3 = ic23_6 & l32;                 // IC22 (1, 2 -> 3)
    wire ic2_11 = i_sp_down_n & ic6_10;         // IC2 (12, 13 -> 11)
    // IC7: A = (QD, QC, QB, Vcc), B = (IC22.3, IC2.11, IC16.6, Vcc), cascade
    // inputs at Vcc.
    wire [3:0] a7 = {q15[3:1], 1'b1}, b7 = {ic22_3, ic2_11, ic16_6, 1'b1};
    wire gt7 = a7 > b7, lt7 = a7 < b7;
    // IC27 latch 4 (/R 14, /S 15, Q 13): /S = IC14 (1, 2, 4, 5 -> 6) =
    // NAND(QC, QA, QB, /QD), /R = IC44 (13 -> 12) of IC28 (9, 10, 11 -> 8).
    wire ic14_6 = ~(q15[2] & q15[0] & q15[1] & ~q15[3]);
    wire ic44_12 = l32 & x_n & i_coin_test_n;
    wire l27d = !ic14_6 | (ic44_12 & l27d_r);
    // IC60 (74157), S = IC16 (9, 10 -> 8), /E grounded.
    wire ic16_8 = l32 ^ l27d;
    wire za60 = ic16_8 ? i_vs64 : i_vs16;
    wire zb60 = ic16_8 ? i_vs8  : i_vs2;
    wire up15 = ~(za60 & lt7);                  // IC8 (4, 5 -> 6)
    wire dn15 = ~(i_vs8 & gt7);                 // IC8 (1, 2 -> 3)

    // IC10/IC11: {Vcc, IC24 QC..QA, IC25} against {Vcc, /QD, /QC, /QB, 0000}.
    wire [7:0] a10 = {1'b1, q24, q25}, b10 = {1'b1, ~q15[3:1], 4'd0};
    wire gt10 = a10 > b10, lt10 = a10 < b10;
    // IC39 (74393 half) clock: IC34 (9, 10 -> 8).
    wire cp39 = ic68_6 & i_vs8;
    // IC69 (74153): S1 = EXPLO. ST., S0 = EXPLO. SEL. D; strobes grounded.
    // IC67 section 1 (7450) = NOR(V6 & IC73.8, V7 & IC72.13).
    wire ic72_13 = ~(x | i_sp_down);
    wire ic67_8 = ~((v6 & ~ic72_13) | (v7 & ic72_13));
    wire [1:0] s69 = {explo, q39[3]};
    wire za69 = s69 == 2'd3 ? ~v5 : s69 == 2'd2 ? 1'b0 : ic67_8;
    wire zb69 = s69 == 2'd3 ? ~v5 : s69 == 2'd2 ? 1'b0 : ~v6;
    wire up25 = ~(za69 & lt10);                 // IC12 (1, 2 -> 3)
    wire dn25 = ~(zb60 & gt10);                 // IC12 (4, 5 -> 6)
    wire co25 = ~(~up25 & q25 == 4'hf);
    wire bo25 = ~(~dn25 & q25 == 4'h0);

    // One-shots. IC43 and IC49 /CLR = IC15 QD (IC6 pin 1 net).
    wire qd15 = q15[3];
    wire q43a = qd15 && m43a != 0;              // /SLIP half, Q pin 13, /Q pin 4
    wire q43b = qd15 && m43b != 0;              // /POOL(2) half, Q pin 5, /Q pin 12
    wire q49  = qd15 && m49  != 0;              // Q pin 5
    // IC1: each half's /CLR is the other half's /Q; A = IC43 pin 4.
    wire q1a = m1a != 0, q1b = m1b != 0;        // Q pins 13 (HAN.-L) and 5 (HAN.-R)
    wire a1 = ~q43a;
    wire clr1a = ~q1b, clr1b = ~q1a;
    wire trig1a = (a1_l & ~a1 & i_han_l) | (~b1a_l & i_han_l & ~a1) |
                  (~clr1a_l & clr1a & ~a1 & i_han_l);
    wire trig1b = (a1_l & ~a1 & i_han_r) | (~b1b_l & i_han_r & ~a1) |
                  (~clr1b_l & clr1b & ~a1 & i_han_r);
    wire trig43a = (slip_l & ~i_slip_n & i_player) | (~player_l & i_player & ~i_slip_n) |
                   (~qd15_l & qd15 & ~i_slip_n & i_player);
    wire trig43b = (pool_l & ~i_pool2_n & i_player) | (~player_l & i_player & ~i_pool2_n) |
                   (~qd15_l & qd15 & ~i_pool2_n & i_player);

    // IC3 (74153): S1 = IC43 pin 4, S0 = IC43 pin 12; strobes grounded.
    wire ic2_8 = q1a & ~v6, ic2_6 = ~v6 & q1b;  // IC2 (9, 10 -> 8), (4, 5 -> 6)
    wire ic72_4 = ~(zb69 | i_vs32);             // IC72 (5, 6 -> 4)
    wire ic66_8 = zb69 & i_vs32;                // IC66 (9, 10 -> 8)
    wire [1:0] s3 = {~q43a, ~q43b};
    wire za3 = s3 == 2'd3 ? i_han_l : s3 == 2'd2 ? ic72_4 : s3 == 2'd1 ? ic2_8 : 1'b0;
    wire zb3 = s3 == 2'd3 ? i_han_r : s3 == 2'd2 ? ic66_8 : s3 == 2'd1 ? ic2_6 : 1'b0;
    // IC9 (74153): S1 = IC44 (1 -> 2) of IC27 pin 4, S0 = IC16 pin 11.
    wire [1:0] s9 = {~l27a, x_n};
    wire za9 = s9[0] ? za3 : s9[1] ? ic72_4 : 1'b0;
    wire zb9 = s9[0] ? zb3 : s9[1] ? ic66_8 : zb69;
    // IC30 (9, 10 -> 8) and (12, 13 -> 11): up unless IC35 >= 0xC;
    // IC30 (1, 2 -> 3): down unless IC35 = 0 (IC46 pin 2).
    wire up36 = ~(za9 & ~(q35[3] & q35[2]));
    wire dn36 = ~(zb9 & ~ic47_6);
    wire co36 = ~(~up36 & q36 == 4'hf);
    wire bo36 = ~(~dn36 & q36 == 4'h0);

    // Score clock. IC61 (2, 3 -> 1), IC8 (12, 13 -> 11); IC67 section 2 (7450)
    // = NOR(V6 & IC8.11, V7 & IC73.6) clocks IC5 (MR = /GAME).
    wire ic61_1 = ~(q43b | q43a);
    wire ic8_11 = ~(ic61_1 & i_tunnel_n);
    wire cp5 = ~((v6 & ic8_11) | (v7 & ~ic8_11));
    wire [3:0] q5 = i_game_n ? 4'd0 : c5;
    // IC4 (74151): /E = IC23 pin 3; S2..S0 = /QD, /QC, /QB; I0..I7 = Q0, Q0,
    // Q1, Q1, Q2, Q2, Q3, Q3 of IC5.
    // S0 picks between equal inputs, so S2, S1 alone select Q0..Q3.
    wire z4 = x_n & q5[~q15[3:2]];

    // Outputs
    // IC8 (9, 10 -> 8), IC13 (11 -> 10); Pro: the AND with /BONUS POINT between them
    wire score_cp_c = ~(i_score_st_n & z4) & (~i_pro | i_bonus_point_n);
    wire ic62_3 = i_8000 | i_ext500_n;          // IC62 (1, 2 -> 3)
    wire sp_irreg_c = ~(~q15[3] & ic62_3 & i_ext_car_cont);  // IC80 (1, 2, 13 -> 12)
    wire acce_st_c = ic23_6 & zb60;             // IC34 (4, 5 -> 6)
    wire nonroad_c = ~q43b & i_sp_down_n;       // IC2 (1, 2 -> 3), IC29 (1 -> 2)

    wire [36:0] state = {q15, q24, q25, q35, q36, q5, q39, explo, l27a, l27b, l27d,
                         l32, q1a, q1b, q43a, q43b, q49};
    assign dbg_live = state;
    // Edge-triggered inputs that would act at the next step
    wire [16:0] nets   = {up15, dn15, up25, dn25, co25, bo25, up36, dn36, co36, bo36,
                          cp5, cp39, l27b, clr1a, clr1b, a1, qd15};
    wire [16:0] nets_l = {up15_l, dn15_l, up25_l, dn25_l, co25_l, bo25_l, up36_l, dn36_l,
                          co36_l, bo36_l, cp5_l, cp39_l, ck33_l, clr1a_l, clr1b_l, a1_l, qd15_l};
    assign busy = nets != nets_l || {l27a, l27b, l27d, l32} != {l27a_r, l27b_r, l27d_r, l32_r} ||
                  explo != explo_r || x != x_r || (!qd15 && (m43a != 0 || m43b != 0 || m49 != 0)) ||
                  (!clr1a && q1a) || (!clr1b && q1b) || trig1a || trig1b || trig43a ||
                  trig43b || {i_slip_n, i_pool2_n, i_player, i_han_l, i_han_r} !=
                  {slip_l, pool_l, player_l, b1a_l, b1b_l} ||
                  (i_game_n && (c15 != 0 || c5 != 0)) || (x && c15 != 0) ||
                  (!i_coin_test_n && {c24[2:0], c25, c35, c36} != 15'h700f) ||
                  (!explo_r && c39 != 0);

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            ic19_cnt <= 0; ic40_cnt <= 0;
            mr19_l <= 0; mr40_l <= 0; hs_l <= 0;
            i_v <= 0;
            {i_coin_test_n, i_game_n, i_extend, i_8000} <= 4'b0100;
            {i_vs2, i_vs8, i_vs16, i_vs32, i_vs64, i_other_body_n} <= 6'b000001;
            {i_slip_n, i_pool2_n, i_road, i_tunnel_n, i_ext500_n} <= 5'b11111;
            {i_rescue_n, i_bridge_n, i_ext_car_cont} <= 3'b110;
            {i_sp_down_n, i_sp_down, i_score_st_n, i_acc1_st_n, i_acc1_pulse_n, i_player} <= 6'b101110;
            {i_acce_a, i_acce_b, i_han_l, i_han_r, i_shift_no, i_shift_nc, i_27_3} <= 7'b0000111;
            {i_pro, i_bonus_point_n} <= 2'b01;
            {c15, c24, c25, c35, c36, c5, c39} <= 0;
            {explo_r, l27a_r, l27b_r, l27d_r, l32_r, x_r} <= 0;
            {m1a, m1b, m43a, m43b, m49} <= 0;
            {up15_l, dn15_l, up25_l, dn25_l, co25_l, bo25_l} <= 6'h3f;
            {up36_l, dn36_l, co36_l, bo36_l, cp5_l, cp39_l, ck33_l} <= 7'b1111000;
            {a1_l, b1a_l, b1b_l, clr1a_l, clr1b_l} <= 5'b10011;
            {slip_l, pool_l, player_l, qd15_l} <= 4'b1100;
            hpos_t <= 7'h70; vpos_t <= 8'h0f; dbg <= 0;
            shift <= 0; slipzone_n <= 1; nonroad_slip_n <= 1; acce_st <= 0; acce <= 0;
            score_cp_n <= 1; s_acc1_n <= 1; acc1_n <= 1; splay_a_n <= 1; splay_b_n <= 0;
            sp_irreg_n <= 1; home_pos_n <= 1; explo_sel <= 0; explo_st <= 0; explo_st_n <= 1;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            // Position counters
            if (pxl_cen) begin
                mr19_l <= mr19;
                mr40_l <= mr40;
                hs_l   <= hs;
            end
            if (edge1) begin
                // IC63 (11, 12 -> 13) stops the 7 MHz clock once IC19 pin 8 is high.
                if (mr19 || mr19_l) ic19_cnt <= 0;
                else if (!ic19_cnt[7]) ic19_cnt <= ic19_cnt + 8'd1;
                // IC40 counts falling /HS, which is the start of HS.
                if (mr40 || mr40_l) ic40_cnt <= 0;
                else if (!hs_l && hs) ic40_cnt <= ic40_cnt + 8'd1;
            end
            if (edge3) begin
                // Settled outputs of the pixel just evaluated
                shift <= l32;
                slipzone_n <= ~q43a;
                nonroad_slip_n <= nonroad_c;
                acce_st <= acce_st_c;
                acce <= q15;
                score_cp_n <= score_cp_c;
                s_acc1_n <= x_n;
                acc1_n <= x_n;
                splay_a_n <= ~(q43b & q49);
                splay_b_n <= q49;
                sp_irreg_n <= sp_irreg_c;
                home_pos_n <= home_n;
                explo_sel <= q39;
                explo_st <= explo;
                explo_st_n <= ~explo;
                hpos_t <= {q24, q25};
                vpos_t <= {q35, q36};
                dbg <= state;
                // Capture the next pixel
                i_v <= v[7:5];
                {i_coin_test_n, i_game_n, i_extend, i_8000} <= {coin_test_n, game_n, extend, pts8000};
                {i_vs2, i_vs8, i_vs16, i_vs32, i_vs64, i_other_body_n} <=
                    {vs2, vs8, vs16, vs32, vs64, other_body_n};
                {i_slip_n, i_pool2_n, i_road, i_tunnel_n, i_ext500_n} <=
                    {slip_n, pool2_n, road, tunnel_n, ext500_n};
                {i_rescue_n, i_bridge_n, i_ext_car_cont} <= {rescue_n, bridge_n, ext_car_cont};
                {i_sp_down_n, i_sp_down, i_score_st_n, i_acc1_st_n, i_acc1_pulse_n, i_player} <=
                    {sp_down_n, sp_down, score_st_n, acc1_st_n, acc1_pulse_n, player};
                {i_acce_a, i_acce_b, i_han_l, i_han_r, i_shift_no, i_shift_nc, i_27_3} <=
                    {acce_cont_a, acce_cont_b, han_l_cp, han_r_cp, shift_no, shift_nc, ic27_3};
                {i_pro, i_bonus_point_n} <= {pro, bonus_point_n};
                // One pixel of every running pulse
                if (m1a  != 0) m1a  <= m1a  - 22'd1;
                if (m1b  != 0) m1b  <= m1b  - 22'd1;
                if (m43a != 0) m43a <= m43a - 22'd1;
                if (m43b != 0) m43b <= m43b - 22'd1;
                if (m49  != 0) m49  <= m49  - 22'd1;
            end else begin
                // One settling step
                {up15_l, dn15_l, up25_l, dn25_l, co25_l, bo25_l} <= {up15, dn15, up25, dn25, co25, bo25};
                {up36_l, dn36_l, co36_l, bo36_l, cp5_l, cp39_l, ck33_l} <=
                    {up36, dn36, co36, bo36, cp5, cp39, l27b};
                {a1_l, b1a_l, b1b_l, clr1a_l, clr1b_l} <= {a1, i_han_l, i_han_r, clr1a, clr1b};
                {slip_l, pool_l, player_l, qd15_l} <= {i_slip_n, i_pool2_n, i_player, qd15};
                {l27a_r, l27b_r, l27d_r, l32_r, x_r} <= {l27a, l27b, l27d, l32, x};
                // 74193: a rising UP counts up while DOWN is high, and the
                // other way round. Clear and load act at once.
                if (i_game_n || x) c15 <= 0;
                else if (up15 && !up15_l && dn15) c15 <= c15 + 4'd1;
                else if (dn15 && !dn15_l && up15) c15 <= c15 - 4'd1;
                if (!i_coin_test_n) begin
                    c25 <= 4'h0; c24 <= 4'hf;
                    c36 <= 4'hf; c35 <= 4'h0;
                end else begin
                    if (up25 && !up25_l && dn25) c25 <= c25 + 4'd1;
                    else if (dn25 && !dn25_l && up25) c25 <= c25 - 4'd1;
                    if (co25 && !co25_l && bo25) c24 <= c24 + 4'd1;
                    else if (bo25 && !bo25_l && co25) c24 <= c24 - 4'd1;
                    if (up36 && !up36_l && dn36) c36 <= c36 + 4'd1;
                    else if (dn36 && !dn36_l && up36) c36 <= c36 - 4'd1;
                    if (co36 && !co36_l && bo36) c35 <= c35 + 4'd1;
                    else if (bo36 && !bo36_l && co36) c35 <= c35 - 4'd1;
                end
                // 74393 halves count falling clocks; MR is active high.
                if (i_game_n) c5 <= 0;
                else if (cp5_l && !cp5) c5 <= c5 + 4'd1;
                if (!explo_r) c39 <= 0;
                else if (cp39_l && !cp39) c39 <= c39 + 4'd1;
                // 7474: /CLR wins over the clock.
                if (!clr33_n) explo_r <= 1'b0;
                else if (l27b && !ck33_l) explo_r <= i_extend;
                // 74123 halves, retriggerable: a trigger restarts the full period.
                if (!clr1a) m1a <= 0; else if (trig1a) m1a <= IC1A_PIXELS[21:0];
                if (!clr1b) m1b <= 0; else if (trig1b) m1b <= IC1B_PIXELS[21:0];
                if (!qd15) begin
                    m43a <= 0; m43b <= 0; m49 <= 0;
                end else begin
                    if (trig43a) m43a <= IC43A_PIXELS[21:0];
                    if (trig43b) m43b <= IC43B_PIXELS[21:0];
                    if (trig43b) m49  <= IC49_PIXELS[21:0];   // same A, B and /CLR nets
                end
            end
        end
    end
endmodule
