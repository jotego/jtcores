// SPDX-License-Identifier: GPL-3.0-or-later
// 96577-P sheet H (manual 420-0358, PDF page 28): the frame counter, the
// 7 MHz divider with its speed PROM PR-38 and restart pause, the three
// other-car position channels with their direction latches and one-shots,
// the AREA decoder, PR-39, the image PROM PR-132 and /F-SOUND.
// Pin-level transcription: docs/trace/SHEET_H_TRACE.md. Behaviour:
// docs/SHEET_H_LOGIC.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). The sheet is
// evaluated one pixel late, like sheet D:
// - Edge 2 is the 7 MHz edge that ends a pixel. The outputs of that pixel are
//   registered; IC112's second half and IC81c take the two 14 MHz edges of
//   that pixel; IC101 and IC102 (clocked by 7 MHz) step on the pixel's
//   settled nets; the one-shots count the pixel; then the next pixel's inputs
//   are captured.
// - Every later host clock up to edge 1 of the next pixel is one settling
//   step. PR-132 and PR-39 are synchronous memories, read as one layer.
// Timing rule for one step ("settled layers"): gates are combinational on
//   the state; every flip-flop, latch, counter and one-shot, and every
//   asynchronous clear, takes one step: it compares its clock and trigger
//   nets with their values at the previous step and changes state for the
//   next one. This is stricter than on sheets A, B and D, where latches and
//   clears were combinational: here the direction latches IC81a, b, d feed
//   the load inputs of counters clocked in the same layer.
//   tests/sheet_h_reference.v implements the same rule with delays on a
//   pin-wired netlist.
// The 14 MHz edges fall in each half of the pixel (IC109 on sheet E divides
// 14 MHz by two on its rising edge). C28, C29, C36, C41, C42, C43, the 470 pF
// on IC66.6 and RA3 are not reproduced. pxl_cen must be at least six host
// clocks apart.
module jtmonacogp_cars #(
    // 74123 data sheet: tw = 0.28*R*C*(1+0.7/R), R in kohm, in periods of
    // 7.1525 MHz. Values as read from the scan.
    parameter integer OS1A_PIXELS = 9552879,  // IC121 pins 1-4, 13-15: R21 47k, C35 100 uF (U2, settled)
    parameter integer OS1B_PIXELS = 9552879,  // IC121 pins 5-7, 9-12: R18 47k, C32 100 uF
    parameter integer OS2A_PIXELS = 21016334, // IC120 pins 1-4, 13-15: R20 47k, C34 220 uF
    parameter integer OS2B_PIXELS = 21016334  // IC120 pins 5-7, 9-12: R17 47k, C31 220 uF
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E (through sheet F for /HS)
    input            h6_n, h8_n,        // /H6 pad C2, /H8 pad CB
    input            hs_n,              // /HS
    input            vs_n,              // /VS pad C12
    input            v8_n,              // /V8 pad CN
    input            vca_v8_n,          // /(V-CA x V8) pad CS
    // Sheets D and M
    input            l1_side_n, l2_side_n,              // pads CC, C4
    input            r1_side_n, r2_side_n, rl_side_n,   // pads CD, C5, CE
    input            bridge_ap,         // BRIDGE AP. pad C18: low clears IC120, IC121
    input            car_sp_cont_n,     // /CAR SP. CONT. pad C3
    // Sheets A and F
    input            car_cont_cl,       // CAR CONT. CL. (A): clears IC112's first half
    input            ext500_n,          // /EXT. 500
    input            sp_irreg_n,        // /SP. IRREG.
    input      [3:0] acce,              // ACCE. D..A
    // Sheet I
    input            sp_cont,           // SP. CONT. pad AL
    // PR-38 = IC115 and PR-39 = IC105 (32 x 8), PR-132 = IC111 (512 x 8)
    output     [4:0] pr38_addr, pr39_addr,
    input      [7:0] pr38_q, pr39_q,
    output     [8:0] pr132_addr,
    input      [7:0] pr132_q,
    // Settled values for the previous pixel, registered at edge 2
    output reg       vs2, vs4, vs8, vs16, vs32, vs64,   // IC79 Q0..Q3, IC78 Q0, Q1
    output reg [3:0] sp,                // PR-38 D3..D0, pads CU, C17, CT, C16
    output reg [5:1] area,              // AREA 5..1, pads C11, C10, C9, CK, CL -> (C)
    output reg       other_car_n,       // IC114 pin 10, pad B15 -> (C)
    output reg       other_body_n,      // IC114 pin 12, pad BR -> (C), (F)
    output reg       other_tiar_n,      // IC114 pin 2, pad BS -> (C)
    output reg       f_sound_n,         // IC29 pin 10, pad A19
    // Tests only
    output reg [68:0] dbg,              // internal state, previous pixel
    output           busy               // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge2 = cen_sr[1];

    // Captured inputs
    reg i_h6_n, i_h8_n, i_hs_n, i_vs_n, i_v8_n, i_cs, i_l1, i_l2, i_r1, i_r2, i_rl;
    reg i_bridge, i_car_n, i_carcl, i_ext500_n, i_irreg_n, i_spcont;
    reg [3:0] i_acce;

    // State
    reg  [3:0] c101, c102, c112b;       // divider and the 14 MHz counter
    reg        q87, l81c, run14, h8_l;
    reg [11:0] fc;                      // IC79 second half, IC78 both halves
    reg  [3:0] lo1, hi1, lo2, hi2, lo3, hi3;
    reg        l81a, l81d, l81b;        // direction latches of channels 1, 2, 3
    reg [24:0] m1a, m1b, m2a, m2b;      // IC121 halves (channel 1), IC120 halves (channel 2)
    reg        f99a, f99b, f92a, f92b, f75a, f75b;
    reg  [1:0] c112a;
    // Nets at the previous step
    reg [16:0] ck_l;

    // ---------------------------------------------------------------- divider
    // IC102 (low) and IC101 (high), 74161 on 7 MHz. IC80 (9, 10, 11 -> 8)
    // = NAND(IC102 TC, IC101 TC, IC87 Q) loads both: IC101 with 0011, IC102
    // with IC108 (74157, S = /(V-CA x V8)): PR-38 D7..D4, or 1000.
    wire tc102 = c102 == 4'hf;                      // CET at Vcc
    wire tc101 = tc102 && c101 == 4'hf;              // CET = IC102 TC
    wire n80_8 = ~(tc102 & tc101 & q87);
    wire [3:0] l108 = i_cs ? 4'b1000 : pr38_q[7:4];
    // IC86 (8, 9 -> 10) = NOR(IC80 pin 8, /(V-CA x V8)): IC112 MR, and through
    // IC114 (3 -> 4) the /R of IC81c (IC102's CEP).
    wire n86_10 = ~(n80_8 | i_cs);
    // IC113 (7485): A = {ACCE. D, IC106 (12, 13 -> 11) AND(ACCE. C, /SP.
    // IRREG.), ACCE. B, open input A0 = 1}, B = IC112 second half. A = B, through
    // IC114 (5 -> 6), sets IC81c.
    wire [3:0] a113 = {i_acce[3], i_acce[2] & i_irreg_n, i_acce[1], 1'b1};
    wire [3:0] c112b_1 = c112b + 4'd1, c112b_2 = c112b + 4'd2;
    // run14: no 14 MHz edges are counted for the time before the first 7 MHz
    // edge after reset.
    wire [3:0] n112b = !run14 ? c112b : n86_10 ? 4'd0 : c112b_2;
    wire n81c = n86_10 ? 1'b0 : l81c | (run14 && (c112b_1 == a113 || c112b_2 == a113));
    // IC87 (74107, J = K = /CLR = Vcc) toggles as IC101 TC falls; /Q = IC94 /E.
    // PR-38 (IC115): A0..A3 = ACCE. A..D, A4 = SP. CONT., /CE at GND.
    assign pr38_addr = {i_spcont, i_acce};

    // ---------------------------------------------------------------- frame counter
    // IC79 second half (CP = /VS), IC78 halves (CP = IC79 Q3, IC78 Q3): one
    // ripple counter counting the falls of /VS.
    wire f_vs2 = fc[0], f_vs4 = fc[1], f_vs8 = fc[2], f_vs16 = fc[3];
    wire f_vs32 = fc[4], f_vs64 = fc[5], f_vs256 = fc[7], f_vs512 = fc[8], f_vs1k = fc[9];

    // ---------------------------------------------------------------- position channels
    // 74161 pairs clocked by IC80 pin 8, CET of the low half = /V8; the high
    // half's TC, inverted by IC82, loads the pair (high half 0000).
    // IC122 and IC123: low while the high half is 1010 (the channel's window).
    wire cmp1_n = hi1 != 4'b1010, cmp2_n = hi2 != 4'b1010, cmp3_n = hi3 != 4'b1010;
    // IC85 (3, 4, 5 -> 6), pin 3 open: AND(/L1-SIDE, /L2-SIDE); (9, 10, 11 -> 8)
    // AND(/R1-SIDE, /R2-SIDE, /R-L-SIDE).
    wire lnd = i_l1 & i_l2, rnd = i_r1 & i_r2 & i_rl;
    // Direction latches (74279; a low /S wins). Channel 1 IC81a: /S1, /S2 =
    // IC95 (12, 13 -> 11), /R = IC95 (1, 2 -> 3); channel 2 IC81d: /S = IC88
    // (1, 2 -> 3), /R = IC88 (12, 13 -> 11); channel 3 IC81b: /S = IC88
    // (4, 5 -> 6), /R = IC88 (9, 10 -> 8).
    wire s81a = lnd | cmp1_n, r81a = cmp1_n | rnd;
    wire s81d = lnd | cmp2_n, r81d = cmp2_n | rnd;
    wire s81b = lnd | cmp3_n, r81b = cmp3_n | rnd;
    wire n81a = !s81a | (r81a & l81a);
    wire n81d = !s81d | (r81d & l81d);
    wire n81b = !s81b | (r81b & l81b);
    // One-shots: IC121 (channel 1) and IC120 (channel 2), /CLR = BRIDGE AP.
    wire o1a = m1a != 0, o1b = m1b != 0, o2a = m2a != 0, o2b = m2b != 0;
    // Load selects: IC107 (1, 2, 13 -> 12) = NOR(IC121 pin 13, IC30 (4, 5 -> 6)
    // NAND(Vs/4, Vs/2), IC121 pin 5); IC107 (9, 10, 11 -> 8) = NOR(IC120 pin 13,
    // IC120 pin 5, Vs/2).
    wire sel1 = ~(o1a | ~(f_vs4 & f_vs2) | o1b);
    wire sel2 = ~(o2a | o2b | f_vs2);
    // IC89, IC103 (74157) and IC117's inputs: {Q, /Q, /Q, Vcc} (9 or 7), or
    // 1000 (8) while the select is low.
    wire [3:0] d1 = sel1 ? {l81a, ~l81a, ~l81a, 1'b1} : 4'b1000;
    wire [3:0] d2 = sel2 ? {l81d, ~l81d, ~l81d, 1'b1} : 4'b1000;
    wire [3:0] d3 = {l81b, ~l81b, ~l81b, 1'b1};

    // ---------------------------------------------------------------- AREA and buffers
    // IC94 (74259, /CLR at GND, D at Vcc): A2..A0 = IC101 Q3..Q1, /E = IC87 /Q.
    wire en94 = q87;
    wire [2:0] a94 = c101[3:1];
    wire a1 = en94 && a94 == 3'd5, a2 = en94 && a94 == 3'd0;
    wire a3 = en94 && a94 == 3'd4, a5 = en94 && a94 == 3'd7;
    // AREA 4 = IC106 (1, 2 -> 3) AND(IC107 (3, 4, 5 -> 6) NOR(IC87 Q, IC101 Q1,
    // IC101 Q2), IC101 Q3).
    wire a4 = c101[3] & ~(q87 | c101[1] | c101[2]);
    // IC86 (11, 12 -> 13) = NOR(/HS, /VS); IC93 and IC66 gate it with the AREAs.
    wire hsvs = ~(i_hs_n | i_vs_n);
    wire ck99a = a3 & hsvs, ck92b = a2 & hsvs, ck92a = a5 & hsvs, ck99b = a4 & hsvs, ck75a = a1 & hsvs;
    // IC100 (7450) and IC68 (9, 10 -> 8): the 367 enables (low).
    wire en1_n = ~((f99a & a3) | (f99b & a4));
    wire en2_n = ~((f92a & a5) | (f92b & a2));
    wire en3_n = ~(f75a & a1);
    // IC97, IC110, IC124 (74367): Y1..Y4 = the low half, Y6 = the window
    // (strobe line). With none enabled RA3 pulls the lines high. The AREA
    // windows enable at most one at a time (the tests check it).
    wire [4:0] bus = !en1_n ? {cmp1_n, lo1} : !en2_n ? {cmp2_n, lo2} : !en3_n ? {cmp3_n, lo3} : 5'h1f;
    wire strobe = bus[4];
    // PR-132 (IC111): A0..A3 = the bus, A4..A6 = IC102 Q1..Q3, A7 = IC101 Q0,
    // A8 = Vs/4.
    assign pr132_addr = {f_vs4, c101[0], c102[3:1], bus[3:0]};
    // IC118 (74157), S = IC102 Q0, /E = the strobe line; IC114 inverts Zb, Zc, Zd.
    wire [2:0] z118 = strobe ? 3'd0 : c102[0] ? {pr132_q[7], pr132_q[5], pr132_q[3]}
                                               : {pr132_q[6], pr132_q[4], pr132_q[2]};
    // PR-39 (IC105): A0..A2 = Vs/256, Vs/512, Vs/1K, A3, A4 = IC112 Q0, Q1.
    assign pr39_addr = {c112a, f_vs1k, f_vs512, f_vs256};
    // IC86 (5, 6 -> 4) = NOR(/CAR SP. CONT., IC106 (9, 10 -> 8) AND(Q0, Q1)):
    // IC112's first half counts its falls, stopping at 3.
    wire n86_4 = ~(i_car_n | (c112a[0] & c112a[1]));

    // ---------------------------------------------------------------- step
    wire [16:0] ck = {n80_8, tc101, i_vs_n, strobe, ck99a, ck99b, ck92a, ck92b, ck75a, n86_4,
                      l81a, l81d, o1a, o1b, o2a, o2b, i_bridge};
    wire up80 = n80_8 && !ck_l[16];
    // 74123: A falling while B is high, B rising while A is low, /CLR rising
    // while A is low and B is high.
    function trig(input a, b, clr, a_l, b_l, clr_l);
        trig = clr && ((a_l && !a && b) || (!b_l && b && !a) || (!clr_l && !a && b));
    endfunction
    // IC121: first half A = second half Q, B = IC81a Q; second half A = IC81a Q,
    // B = first half /Q. IC120 the same with IC81d.
    wire t1a = trig(o1b, l81a, i_bridge, ck_l[3], ck_l[6], ck_l[0]);
    wire t1b = trig(l81a, ~o1a, i_bridge, ck_l[6], ~ck_l[4], ck_l[0]);
    wire t2a = trig(o2b, l81d, i_bridge, ck_l[1], ck_l[5], ck_l[0]);
    wire t2b = trig(l81d, ~o2a, i_bridge, ck_l[5], ~ck_l[2], ck_l[0]);
    // Next state of the counters clocked by IC80 pin 8: low half counts while
    // /V8 is high, the high half on the low half's TC; the high half's TC loads.
    wire tl1 = i_v8_n && lo1 == 4'hf, tl2 = i_v8_n && lo2 == 4'hf, tl3 = i_v8_n && lo3 == 4'hf;
    wire th1 = tl1 && hi1 == 4'hf, th2 = tl2 && hi2 == 4'hf, th3 = tl3 && hi3 == 4'hf;
    wire [7:0] n1 = th1 ? {4'd0, d1} : {hi1 + {3'd0, tl1}, lo1 + {3'd0, i_v8_n}};
    wire [7:0] n2 = th2 ? {4'd0, d2} : {hi2 + {3'd0, tl2}, lo2 + {3'd0, i_v8_n}};
    wire [7:0] n3 = th3 ? {4'd0, d3} : {hi3 + {3'd0, tl3}, lo3 + {3'd0, i_v8_n}};
    wire n87 = (!tc101 && ck_l[15]) ? ~q87 : q87;
    wire [11:0] nfc = (!i_vs_n && ck_l[14]) ? fc + 12'd1 : fc;
    // 7474s: /CLR wins over the clock, and a clock edge needs /CLR released at
    // the step before too (a clear and a clock arriving in one layer: the clock
    // sees the clear as it was). IC75's second half: D = /H6, CK = the strobe
    // line, /CLR = /H8.
    wire n75b = !i_h8_n ? 1'b0 : (strobe && !ck_l[13] && h8_l) ? i_h6_n : f75b;
    wire n99a = (ck99a && !ck_l[12]) ? pr39_q[1] : f99a;
    wire n99b = (ck99b && !ck_l[11]) ? pr39_q[3] : f99b;
    wire n92a = (ck92a && !ck_l[10]) ? pr39_q[0] : f92a;
    wire n92b = (ck92b && !ck_l[9])  ? pr39_q[2] : f92b;
    wire n75a = (ck75a && !ck_l[8])  ? (i_ext500_n & pr39_q[4]) : f75a;  // IC106 (4, 5 -> 6)
    wire [1:0] n112a = i_carcl ? 2'd0 : (!n86_4 && ck_l[7]) ? c112a + 2'd1 : c112a;

    // The internal state at the end of the pixel (after its 14 MHz edges)
    wire [68:0] state = {c101, c102, n112b, q87, n81c, fc, lo1, hi1, lo2, hi2,
                         lo3, hi3, l81a, l81d, l81b, o1a, o1b, o2a, o2b, f99a, f99b, f92a, f92b,
                         f75a, f75b, c112a, strobe, en1_n, en2_n, en3_n};
    assign busy = ck != ck_l || up80 || {n81a, n81d, n81b} != {l81a, l81d, l81b} ||
                  t1a || t1b || t2a || t2b ||
                  (!i_bridge && (m1a != 0 || m1b != 0 || m2a != 0 || m2b != 0)) ||
                  n87 != q87 || nfc != fc || n75b != f75b || h8_l != i_h8_n ||
                  {n99a, n99b, n92a, n92b, n75a} != {f99a, f99b, f92a, f92b, f75a} || n112a != c112a;

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            {i_h6_n, i_h8_n, i_hs_n, i_vs_n, i_v8_n, i_cs} <= 6'b111111;
            {i_l1, i_l2, i_r1, i_r2, i_rl} <= 5'b11111;
            {i_bridge, i_car_n, i_carcl, i_ext500_n, i_irreg_n, i_spcont} <= 6'b110110;
            i_acce <= 0;
            // The board has no reset; this is one power-up state.
            c101 <= 0; c102 <= 0; c112b <= 0; q87 <= 0; l81c <= 0; fc <= 0; run14 <= 0;
            {lo1, hi1, lo2, hi2, lo3, hi3} <= 0;
            {l81a, l81d, l81b} <= 0;
            {m1a, m1b, m2a, m2b} <= 0;
            {f99a, f99b, f92a, f92b, f75a, f75b} <= 0;
            c112a <= 0;
            ck_l <= 17'h16001;
            h8_l <= 1;
            {vs2, vs4, vs8, vs16, vs32, vs64} <= 0; sp <= 0; area <= 0;
            other_car_n <= 1; other_body_n <= 1; other_tiar_n <= 1; f_sound_n <= 1; dbg <= 0;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            if (edge2) begin
                // Settled outputs of the pixel that ends at this 7 MHz edge
                {vs64, vs32, vs16, vs8, vs4, vs2} <= {f_vs64, f_vs32, f_vs16, f_vs8, f_vs4, f_vs2};
                sp <= pr38_q[3:0];
                area <= {a5, a4, a3, a2, a1};
                other_tiar_n <= ~z118[0];
                other_body_n <= ~z118[1];
                other_car_n  <= ~z118[2];
                f_sound_n <= ~f75b;
                dbg <= state;
                // The two 14 MHz edges of the pixel (IC112 second half, IC81c)
                c112b <= n112b;
                l81c <= n81c;
                run14 <= 1;
                // The 7 MHz edge: IC101 and IC102 (CEP of IC102 = IC81c Q)
                if (!n80_8) begin
                    c101 <= 4'b0011;
                    c102 <= l108;
                end else begin
                    if (n81c) c102 <= c102 + 4'd1;
                    if (tc102) c101 <= c101 + 4'd1;
                end
                // One pixel of every running one-shot
                if (m1a != 0) m1a <= m1a - 25'd1;
                if (m1b != 0) m1b <= m1b - 25'd1;
                if (m2a != 0) m2a <= m2a - 25'd1;
                if (m2b != 0) m2b <= m2b - 25'd1;
                // Capture the next pixel
                {i_h6_n, i_h8_n, i_hs_n, i_vs_n, i_v8_n, i_cs} <= {h6_n, h8_n, hs_n, vs_n, v8_n, vca_v8_n};
                {i_l1, i_l2, i_r1, i_r2, i_rl} <= {l1_side_n, l2_side_n, r1_side_n, r2_side_n, rl_side_n};
                {i_bridge, i_car_n, i_carcl, i_ext500_n, i_irreg_n, i_spcont} <=
                    {bridge_ap, car_sp_cont_n, car_cont_cl, ext500_n, sp_irreg_n, sp_cont};
                i_acce <= acce;
            end else begin
                // One settling step
                ck_l <= ck;
                h8_l <= i_h8_n;
                if (up80) begin
                    {hi1, lo1} <= n1;
                    {hi2, lo2} <= n2;
                    {hi3, lo3} <= n3;
                end
                q87 <= n87;
                fc <= nfc;
                {l81a, l81d, l81b} <= {n81a, n81d, n81b};
                f75b <= n75b;
                {f99a, f99b, f92a, f92b, f75a} <= {n99a, n99b, n92a, n92b, n75a};
                c112a <= n112a;
                if (!i_bridge) begin
                    m1a <= 0; m1b <= 0; m2a <= 0; m2b <= 0;
                end else begin
                    if (t1a) m1a <= OS1A_PIXELS[24:0];
                    if (t1b) m1b <= OS1B_PIXELS[24:0];
                    if (t2a) m2a <= OS2A_PIXELS[24:0];
                    if (t2b) m2b <= OS2B_PIXELS[24:0];
                end
            end
        end
    end
endmodule
