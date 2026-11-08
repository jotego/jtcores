// SPDX-License-Identifier: GPL-3.0-or-later
// 96578-P sheet D (manual 420-0358, PDF page 31): scenery PROMs PR-134 to
// PR-137 with their multiplexers, the road-side decodes, the ROAD and M-ROAD
// flip-flops, and the scenery state network (IC24 decoder, seven state
// flip-flops, the IC49 distance counter and the IC68 latch).
// Pin-level transcription: docs/trace/SHEET_D_TRACE.md. Behaviour:
// docs/SHEET_D_LOGIC.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). Sheet E's H
// and V lines change at edge 0, sheet B's MH, M1V and M2V at edge 1.
// The whole sheet is evaluated one pixel late, like the sheet F control logic:
// - Edge 2: the inputs of the pixel are captured (all of them valid since
//   edge 1), and the outputs of the pixel before are registered.
// - Every later host clock up to edge 1 of the next pixel (four or five
//   clocks) is one settling step. PR-134 to PR-137 are synchronous memories:
//   their addresses must have settled by edge 0, so that the data registered
//   at edge 1 are those of the settled pixel. The design check (busy) fails if
//   a step at edge 1 would still change the state.
// Timing rule for one step ("settled layers", as for sheets B, F and G):
//   gates, the IC68 latch and the asynchronous clears are combinational on the
//   state; each flip-flop and the 74393 compare their clock nets with their
//   values at the previous step and change state for the next step. A part
//   clocked through gates by a counter of another sheet therefore samples its
//   D input after that counter has changed (IC88 lower half and IC74 take the
//   new /V8, IC40 lower half the new /HS). One loop of gates and latches is cut:
//   IC32 reads the stored state of the four flip-flops it watches, so that in
//   the step in which IC34 pin 10 clears them, IC49 still shows its count
//   (IC49 MR -> QC, QD -> IC47 -> IC34 -> the clears -> IC32 -> IC49 MR).
//   tests/sheet_d_reference.v implements the same rule with delays on a
//   pin-wired netlist.
// pxl_cen must be at least six host clocks apart. The three 470 pF capacitors
// and RA1 (the pull-ups of the S-100 inputs) are not reproduced.
//
// Pro Monaco GP (manual 420-0525, sheet D, PDF page 15), selected by pro = 1:
// pro/docs/SHEETS_B_C_D_PRO_LOGIC.md, from pro/docs/trace/SHEET_D_COMPARE.md.
// - A 74157 (Pro IC34, S = /DISPLAY) in front of the 7442: the S-100 pads, or
//   {NOT(1QC XOR 1QD), 2QC, 2QB, 2QA} of a 74393 (Pro IC41) whose first half
//   counts the falls of IC40 lower half's Q and whose second half counts the
//   falls of the first's QD; both halves clear while /DISPLAY is high. 2QD is
//   D-TIME. /CAR NO CONT and 100-C come after the multiplexer.
// - Decoder output 1 is unused; output 6 clears EXT. 500 (IC25 upper half);
//   IC38's other half is clocked by NOT(the decoder's D input); IC45 clears
//   only that half.
// - /D-GAME takes /COIN IN's place on IC34 pin 9.
// - EXTEND is D-EXTEND from sheet B.
// - New outputs: SLOW = NOT IC32 (the four-flip-flop NOR), BELT (IC58 pin 11)
//   and SLIP (IC31 SLIP Q, pad EH). /ACCI. AREA (pad E7) is not formed here:
//   sheet F already ANDs ROAD, /RESCUE (Y) and /BRIDGE (W) (see the logic note).
// The 470 pF capacitors added on Pro (C10-C13 and the scenery outputs) are
// not reproduced. With pro = 0 every output is as before.
module jtmonacogp_scenery #(
    // IC90's two sections are drawn as different gate types (13, 12, 10, 9 ->
    // 8 an AND, 2, 1, 4, 5 -> 6 a NOR), which one package cannot be; see the
    // trace. Aldo's comparison with the real game (29 October) shows the 7425
    // picture: green verges on both sides of the road. 1: both NOR (7425,
    // default); 0: as drawn; 2: both AND (7421).
    parameter integer IC90_TYPE = 1,
    // IC66 (3, 4, 5 -> 6): the scan is ambiguous (the 22 October review read
    // a NAND, the first transcription an AND; the output is labelled GRAVEL
    // without a bar). Aldo's comparison with the real game (29 October) shows
    // the AND picture. 0: AND (default), 1: NAND. See the trace.
    parameter integer IC66_NAND = 0
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E
    input            hs,                 // HS, active high; /HS (pad FJ) is formed here
    input            v7,                 // V7, pad EN
    input            v8,                 // V8; /V8 (pad FN) is formed here
    // Sheet B
    input      [8:0] mh,                 // MH0..MH8
    input            mhl_n,              // /MHL0 (sheet B /MHLD, IC55 pin 8)
    input      [7:0] m1v, m2v,           // M1V0..7, M2V0..7
    input            m1vl_n, m2vl_n,     // /M1VL0, /M2VL0 (R1, R2)
    input            v4dec_n,            // V-(4), IC54 pin 5
    // Sheet C
    input            extend,             // EXTEND
    // Sheet A
    input            coin_in_n,          // /COIN IN, pad ED
    // Sheet I
    input      [3:0] s100,               // {S-100-D, -C, -B, -A}; S-100-C also leaves as 100-C (M)
    // Pro board (sheet B); ignored while pro = 0. EXTEND above is D-EXTEND.
    input            pro,                // 1: Pro Monaco GP board
    input            display_n,          // /DISPLAY -> Pro IC34 pin 1, IC41 pins 2, 12
    input            d_game_n,           // /D-GAME -> IC34 pin 9 in place of /COIN IN
    output reg       d_time,             // D-TIME, Pro IC41 pin 8 -> (B)
    output reg       slow,               // SLOW, NOT IC32 pin 6 -> (B)
    output reg       belt,               // BELT, IC58 pin 11 -> (C)
    output reg       slip_eh,            // SLIP, IC31 pin 5, pad EH -> (H)
    output reg       c100,               // 100-C, the decoder's C input -> (M)
    output reg [7:0] dbg_pro,            // Pro IC41 {second half, first half}, previous pixel
    // PR-134 = IC113, PR-135 = IC106, PR-136 = IC99, PR-137 = IC120, 512 x 8.
    // Address A8..A0, data O8..O1.
    output     [8:0] pr134_addr, pr135_addr, pr136_addr, pr137_addr,
    input      [7:0] pr134_q, pr135_q, pr136_q, pr137_q,
    // Settled values for the previous pixel, registered at edge 2
    output reg       side_line_n,        // IC104 pin 8 -> (C)
    output reg       tree_grass_g_n,     // IC60 pin 8, /TREE & GRASS (G) -> (C)
    output reg       tree_grass_bl_n,    // IC34 pin 13, /TREE & GRASS (BL) -> (C)
    output reg       grass_area_n,       // IC56 pin 11 -> (C)
    output reg       grass_w_n,          // IC22 pin 4, /GRASS (W) -> (C)
    output reg       house_st_n,         // IC81 pin 8 -> (C)
    output reg [3:0] house_n,            // IC97 pins 5..2: /HOUSE (W), (St), (Mu), (R) -> (C)
    output reg       pool_n,             // IC72 pin 8 -> (C); pad FM -> (F)
    output reg       wall_n,             // IC72 pin 3 -> (C)
    output reg       gravel_n,           // IC72 pin 11 -> (C); pad F14 -> (G)
    output reg       slide_n,            // IC65 pin 4, pad FR -> (G)
    output reg       slip_n,             // IC59 pin 12 -> (C); pad FA -> (F)
    output reg       green_belt_n,       // IC94 pin 8 -> (C)
    output reg       y_line_n,           // IC87 pin 11 -> (C)
    output reg       tunnel_ap,          // IC80 pin 13 -> (C)
    output reg       bridge_ap,          // IC80 pin 1 -> (C); pad F18
    output reg       road, road_n,       // IC74 Q -> (C), pad E7 -> (F); /Q -> (C)
    output reg       tunnel_n,           // IC31 pin 8, pad EF -> (F), (G)
    output reg       tunnel_bridge_n,    // IC34 pin 4 -> (B)
    output reg       ext500,             // IC25 pin 9 -> (H)
    output reg       ext500_n,           // IC25 pin 8 -> (M); pad EJ -> (F)
    output reg       car_no_cont_n,      // IC24 pin 6, pad F3 -> (H), (M)
    output reg       r_side_n,           // IC81 pin 11, pad FD -> (H)
    output reg       l_side_n,           // IC81 pin 3, pad FC -> (H)
    output reg       zero_area_n,        // IC82 pin 10, /0-AREA -> (M)
    // Tests only
    output reg [23:0] dbg,               // internal state, previous pixel
    output           busy                // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge2 = cen_sr[1];

    // Captured inputs
    reg        i_hs, i_v7, i_v8, i_mhl_n, i_m1vl_n, i_m2vl_n, i_v4dec_n;
    reg  [8:0] i_mh;
    reg  [7:0] i_m1v, i_m2v;
    reg        i_extend, i_coin_in_n;
    reg  [3:0] i_s100;
    reg        i_display_n, i_d_game_n;
    wire hs_n = ~i_hs, v8_n = ~i_v8;

    // State: the stored outputs of the flip-flops, IC49 and IC68
    reg  f40a, f40b, f38a, f38b, f31a, f31b, f25a, f25b, f88a, f88b, f74;
    reg  [3:0] c49;
    reg  l68_r;
    // Pro IC41 (74393, both halves) and its second half's clock at the previous step
    reg  [3:0] p41a, p41b;
    reg  p41qd_l;
    // Clock nets at the previous step
    reg  [11:0] ck_l;

    // ---------------------------------------------------------------- Pro decoder input
    // Pro IC41: CLR (pins 2, 12) = /DISPLAY, active high. With pro = 0 it
    // stays clear and IC34 passes the pads.
    wire disp = pro & ~i_display_n;
    wire [3:0] q41a = disp ? p41a : 4'd0, q41b = disp ? p41b : 4'd0;
    // IC113 (XOR, 9, 10 -> 8) of 1QC, 1QD; IC36 (1 -> 2) to IC34 pin 14
    wire x41 = ~(q41a[2] ^ q41a[3]);
    // IC34 (74157, S = /DISPLAY): B = pads, A = {IC36 pin 2, 2QC, 2QB, 2QA}
    wire [3:0] code = disp ? {x41, q41b[2:0]} : i_s100;

    // ---------------------------------------------------------------- state network
    // IC24 (7442): A, B, C, D = S-100-A..D (pins 15..12); on Pro IC34's
    // outputs. Output n is low for code n; outputs 3, 8 and 9 are not drawn
    // (1 is not connected on Pro).
    wire [9:0] dec_n;
    genvar k;
    generate for (k = 0; k < 10; k = k + 1) begin: g24
        assign dec_n[k] = code != k;
    end endgenerate
    // IC47 (1, 2 -> 3) = AND(Vcc, /HS)
    wire hsb = hs_n;
    // IC32 (5, 2, 4, 1 -> 6) NOR of the GRAVEL, TUNNEL, SLIP and lower IC25 Q
    // outputs, read from the stored state (the loop cut). It is IC49's MR.
    wire mr49 = ~(f31a | f31b | f25a | f40a);
    wire [3:0] q49 = mr49 ? 4'd0 : c49;          // QA..QD = pins 11, 10, 9, 8
    // IC34 (8, 9 -> 10) = NOR(IC47 (12, 13 -> 11) = AND(QC, QD), /COIN IN):
    // the common clear of IC40's upper half, IC31 and IC25's lower half.
    // Pro: /D-GAME in place of /COIN IN (Pro 63 pin 3, C16).
    wire clr34_n = ~((q49[2] & q49[3]) | (pro ? i_d_game_n : i_coin_in_n));
    wire q40a = clr34_n & f40a;                  // GRAVEL, pins 5 (Q) and 6 (/Q)
    wire q31a = clr34_n & f31a;                  // SLIP, pins 5 and 6
    wire q31b = clr34_n & f31b;                  // TUNNEL, pins 9 and 8
    wire q25a = clr34_n & f25a;                  // IC25 lower half, pins 5 and 6
    // IC40 lower half (D = IC47 pin 3, CK = /MHL0) and IC38's POOL half
    // (pins 2-6): /PR and /CLR not drawn.
    wire q40b = f40b;                            // pins 9 (Q) and 8 (/Q)
    wire q38a = f38a;
    // IC45 (1, 2 -> 3) = NAND(IC40 pin 8, IC38 pin 5): the clear of IC38's
    // other half and of IC25's upper half.
    wire clr45_n = ~(~q40b & q38a);
    wire q38b = clr45_n & f38b;                  // pins 9 (Q), 8 not drawn
    // Pro: EXT. 500's /CLR is decoder output 6.
    wire clr25b_n = pro ? dec_n[6] : clr45_n;
    wire q25b = clr25b_n & f25b;                 // EXT. 500, pins 9 (Q) and 8 (/Q)
    // IC39 (12, 13 -> 11) = OR(QB, QC); IC48 and IC41 (74151) select by
    // {QD, IC39 pin 11, QA}, strobes grounded.
    wire [2:0] s49 = {q49[3], q49[1] | q49[2], q49[0]};
    // IC48: D0, D7 = IC47 pin 3, D1 = /MHL0, D2..D6 = Vcc.
    wire [7:0] d48 = {hsb, 5'b11111, i_mhl_n, hsb};
    // IC41: D0 = Vcc, D1..D6 = IC47 pin 3, D7 = /MHL0.
    wire [7:0] d41 = {i_mhl_n, {6{hsb}}, 1'b1};
    // IC68 (74279 latch 2): /S pin 6 = IC48 pin 5, /R pin 5 = IC41 pin 5, Q pin 7.
    wire l68 = !d48[s49] | (d41[s49] & l68_r);

    // ---------------------------------------------------------------- road sides
    // IC78 (1, 2, 4, 5 -> 6) and (9, 10, 12, 13 -> 8), inverted by IC82 (13 -> 12)
    // and (1 -> 2); IC117 (3 -> 4) inverts M2V2.
    wire ic82_12 = &{i_m1v[0], i_m1v[1], i_m1v[4], i_m1v[3]};
    wire ic82_2  = &{i_m2v[3], i_m2v[5], i_m2v[6], i_m2v[7]};
    // IC90 (13, 12, 10, 9 -> 8) on M1V2, M1V5..7 and (2, 1, 4, 5 -> 6) on M2V0,
    // M2V1, /M2V2, M2V4.
    wire [3:0] in90a = {i_m1v[2], i_m1v[5], i_m1v[6], i_m1v[7]};
    wire [3:0] in90b = {i_m2v[0], i_m2v[1], ~i_m2v[2], i_m2v[4]};
    wire ic90_8 = IC90_TYPE == 1 ? ~|in90a : &in90a;
    wire ic90_6 = IC90_TYPE == 2 ? &in90b : ~|in90b;
    // IC81 (12, 13 -> 11) /R-SIDE and (1, 2 -> 3) /L-SIDE
    wire rside_n = ~(ic82_12 & ic90_8);
    wire lside_n = ~(ic82_2 & ic90_6);
    // IC88 lower half: D = /V8, CK = IC81 pin 11, /CLR = IC81 pin 3.
    wire q88b = lside_n & f88b;                  // pin 9 (Q); pin 8 is /M-ROAD
    wire mroad_n = ~q88b;
    // IC74 (74 half, pins not numbered): D = /V8, CK = /M1VL0, /CLR = /M2VL0.
    wire q74 = i_m2vl_n & f74;                   // ROAD; /Q is /ROAD
    // IC88 upper half: D = MH6, CK = MH5, /CLR = IC95 (12, 13 -> 11) AND(MH8, MH7).
    wire q88a = i_mh[8] & i_mh[7] & f88a;        // pin 6 (/Q) to IC89 pin 3

    // ---------------------------------------------------------------- MH decodes
    // IC96 (7442): A, B, C = MH5, MH6, MH7, D = IC88 pin 9.
    wire [3:0] code96 = {q88b, i_mh[7:5]};
    wire d96_0 = code96 != 4'd0, d96_2 = code96 != 4'd2, d96_4 = code96 != 4'd4,
         d96_5 = code96 != 4'd5, d96_6 = code96 != 4'd6;
    // IC89 (1, 2, 13 -> 12) NOR(MH5, MH6, MH7), IC82 (11 -> 10): /0-AREA.
    wire ic82_10 = |i_mh[7:5];
    wire ic82_8 = ~d96_0;                        // IC82 (9 -> 8)
    wire ic95_6 = d96_6 & d96_5;                 // IC95 (4, 5 -> 6)
    wire ic104_11 = i_mh[8] | ic95_6;            // IC104 (13, 12 -> 11)
    wire ic56_3 = ~(ic104_11 & l68);             // IC56 (2, 1 -> 3)
    wire ic65_13 = ~(ic56_3 | ic82_8);           // IC65 (12, 11 -> 13)
    wire ic110_6 = ~(d96_2 & d96_4);             // IC110 (4, 5 -> 6)
    wire ic110_8 = ~(ic110_6 & i_mh[8]);         // IC110 (9, 10 -> 8) -> PR-134 A8

    // ---------------------------------------------------------------- control gates
    // IC80 (2, 3 -> 1) NOR(IC25 pin 6, IC68 Q): BRIDGE AP; IC22 (5 -> 6) /BRIDGE AP.
    wire bridge = ~(~q25a | l68);
    // IC80 (11, 12 -> 13) NOR(/TUNNEL = IC31 pin 8, IC68 Q): TUNNEL AP.
    wire tunnel = ~(~q31b | l68);
    wire ic80_4 = ~(bridge | tunnel);            // IC80 (6, 5 -> 4)
    wire wall = ~q74 & tunnel;                   // IC87 (4, 5 -> 6), /ROAD and TUNNEL AP
    wire ic87_8 = ~q74 & ic80_4;                 // IC87 (10, 9 -> 8)
    wire yline_n = rside_n & lside_n;            // IC87 (13, 12 -> 11)
    wire ic94_6 = ~(yline_n & d96_0 & ic80_4);   // IC94 (4, 3, 5 -> 6)
    wire green_n = ~(ic80_4 & q74 & mroad_n);    // IC94 (9, 11, 10 -> 8)
    wire ic80_10 = ~(ic94_6 | green_n);          // IC80 (9, 8 -> 10)
    // IC73 (4, 3, 5 -> 6) NOR(IC40 pin 6, IC68 Q, /M-ROAD) and (1, 13, 2 -> 12)
    // NOR(IC31 pin 6, IC68 Q, /M-ROAD): SLIP, inverted by IC59 (13 -> 12).
    wire ic73_6 = ~(~q40a | l68 | mroad_n);
    wire slip = ~(~q31a | l68 | mroad_n);
    // IC75 (3, 4, 5 -> 6) NAND(M2V6, M2V7, /M2V5) and (9, 11, 10 -> 8)
    // NAND(M2V5, /M2V6, M2V7); IC82 (5 -> 6) and (3 -> 4) are the inversions.
    wire ic75_6 = ~(i_m2v[6] & i_m2v[7] & ~i_m2v[5]);
    wire ic75_8 = ~(i_m2v[5] & ~i_m2v[6] & i_m2v[7]);
    wire ic66_and = ic75_6 & ic82_10 & ic73_6;
    wire ic66_6 = IC66_NAND ? ~ic66_and : ic66_and;  // IC66 (3, 4, 5 -> 6): GRAVEL control
    // IC89 (3, 4, 5 -> 6) NOR(IC88 pin 6, IC38 pin 6, IC75 pin 8): POOL control.
    wire pool = ~(~q88a | ~q38a | ic75_8);
    wire ic104_6 = ic80_10 | ic66_6;             // IC104 (4, 5 -> 6)
    wire g119_n = ~(pool | wall | ic104_6);      // IC89 (9, 10, 11 -> 8) -> IC119 strobes
    wire g112_n = ~(ic65_13 & ic87_8);           // IC81 (4, 5 -> 6) -> IC112 strobes
    wire g105_n = ~(ic56_3 & ic87_8);            // IC56 (12, 13 -> 11): /GRASS AREA
    wire g98_n  = ~(ic82_8 & ic87_8);            // IC81 (9, 10 -> 8): /HOUSE ST

    // ---------------------------------------------------------------- PROM paths
    // IC104 (1, 2 -> 3) = OR(V7, IC88 pin 9) selects M1V (low) or M2V (high) in
    // IC92 and IC67 (74157, strobes grounded).
    wire sel = i_v7 | q88b;
    wire [4:0] av = sel ? i_m2v[4:0] : i_m1v[4:0];
    wire lv = sel ? i_m2vl_n : i_m1vl_n;         // IC67 pin 7
    // PROM pins 8..4 = AV0..AV4, 3, 2, 1 = MH2, MH3, MH4 (PR-136: MH1, MH2, MH3),
    // 23 = A8. Enables at Vcc (18, 19) and GND (20, 21).
    assign pr134_addr = {ic110_8, i_mh[4:2], av};
    assign pr135_addr = {1'b0, i_mh[4:2], av};   // IC106 pin 23 grounded
    assign pr136_addr = {i_mh[4:1], av};
    assign pr137_addr = {~wall, i_mh[4:2], av};  // IC117 (1 -> 2)
    // IC112, IC105, IC119 (74153): 1C0..1C3 = O1..O4, 2C0..2C3 = O5..O8,
    // A = MH0, B = MH1, both strobes on one net.
    wire [2:0] s1c = {1'b0, i_mh[1:0]}, s2c = {1'b1, i_mh[1:0]};
    wire y112_7 = !g112_n & pr134_q[s1c], y112_9 = !g112_n & pr134_q[s2c];
    wire y105_7 = !g105_n & pr135_q[s1c], y105_9 = !g105_n & pr135_q[s2c];
    wire y119_7 = !g119_n & pr137_q[s1c], y119_9 = !g119_n & pr137_q[s2c];
    // IC98 (74157), S = MH0, /G = /HOUSE ST: 1A, 1B = O1, O2; 2A, 2B = O3, O4;
    // 3A, 3B = O5, O6 (4A, 4B = O7, O8 to the undrawn pin 12).
    wire [2:0] y98 = g98_n ? 3'd0 : i_mh[0] ? {pr136_q[5], pr136_q[3], pr136_q[1]}
                                             : {pr136_q[4], pr136_q[2], pr136_q[0]};
    // IC97 (7442): A, B, C = IC98 pins 4, 7, 9, D grounded; outputs 1..4.
    wire [3:0] house_c = {y98 != 3'd4, y98 != 3'd3, y98 != 3'd2, y98 != 3'd1};

    // ---------------------------------------------------------------- outputs
    wire ic58_11 = y119_7 & ic80_10;             // IC58 (13, 12 -> 11)
    wire slide_c = ~((mroad_n & ~bridge) | (bridge & i_v4dec_n));  // IC58 (2, 1 -> 3), (5, 4 -> 6), IC65 (5, 6 -> 4)

    wire [23:0] state = {f40a, f40b, f38a, f38b, f31a, f31b, f25a, f25b, f88a, f88b, f74,
                         q49, l68, q40a, q31a, q31b, q25a, q38b, q25b, q88a, q88b};
    // Clock nets: IC40 upper (decoded 0), IC31 SLIP (2), IC31 TUNNEL (7), IC25
    // lower (5), IC25 upper (4), IC38 (IC47 (4, 5 -> 6)), IC40 lower (/MHL0),
    // IC38 POOL (IC40 pin 9), IC49 (IC40 pin 8), IC88 upper (MH5), IC88 lower
    // (/R-SIDE), IC74 (/M1VL0). On Pro, IC38's other half is clocked by
    // IC36 (5 -> 6), NOT(IC34 pin 12), the decoder's D input.
    wire [11:0] ck = {dec_n[0], dec_n[2], dec_n[7], dec_n[5], dec_n[4],
                      pro ? ~code[3] : dec_n[1] & dec_n[6],
                      i_mhl_n, q40b, ~q40b, i_mh[5], rside_n, i_m1vl_n};
    wire [11:0] rise = ck & ~ck_l;
    // 7474: /CLR wins over the clock. 74393: counts falling clocks, MR high clears.
    wire n40a = !clr34_n ? 1'b0 : rise[11] ? i_extend : f40a;
    wire n31a = !clr34_n ? 1'b0 : rise[10] ? ~q38a    : f31a;  // D = IC38 pin 6
    wire n31b = !clr34_n ? 1'b0 : rise[9]  ? ~q31a    : f31b;  // D = IC31 pin 6
    wire n25a = !clr34_n ? 1'b0 : rise[8]  ? q25b     : f25a;  // D = IC25 pin 9
    wire n25b = !clr25b_n ? 1'b0 : rise[7]  ? i_extend : f25b;
    wire n38b = !clr45_n ? 1'b0 : rise[6]  ? ~q31b    : f38b;  // D = /TUNNEL
    wire n40b = rise[5] ? hsb  : f40b;
    wire n38a = rise[4] ? q38b : f38a;
    wire [3:0] n49 = mr49 ? 4'd0 : (ck_l[3] && !ck[3]) ? c49 + 4'd1 : c49;
    wire n88a = !(i_mh[8] & i_mh[7]) ? 1'b0 : rise[2] ? i_mh[6] : f88a;
    wire n88b = !lside_n ? 1'b0 : rise[1] ? v8_n : f88b;
    wire n74  = !i_m2vl_n ? 1'b0 : rise[0] ? v8_n : f74;
    // Pro IC41: the first half counts the falls of IC40 pin 9 (ck[4]), the
    // second the falls of the first's QD (pin 6).
    wire [3:0] n41a = !disp ? 4'd0 : (ck_l[4] && !ck[4]) ? p41a + 4'd1 : p41a;
    wire [3:0] n41b = !disp ? 4'd0 : (p41qd_l && !q41a[3]) ? p41b + 4'd1 : p41b;
    assign busy = ck != ck_l || l68 != l68_r || n49 != c49 ||
                  {n40a, n31a, n31b, n25a, n25b, n38b, n40b, n38a, n88a, n88b, n74} !=
                  {f40a, f31a, f31b, f25a, f25b, f38b, f40b, f38a, f88a, f88b, f74} ||
                  n41a != p41a || n41b != p41b || p41qd_l != q41a[3];

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            {i_hs, i_v7, i_v8, i_mhl_n, i_m1vl_n, i_m2vl_n, i_v4dec_n} <= 7'b0001111;
            i_mh <= 0; i_m1v <= 0; i_m2v <= 0;
            i_extend <= 0; i_coin_in_n <= 1; i_s100 <= 4'hf;
            // The board has no reset for these parts; this is one power-up state.
            {f40a, f40b, f38a, f38b, f31a, f31b, f25a, f25b, f88a, f88b, f74} <= 0;
            c49 <= 0; l68_r <= 0;
            i_display_n <= 1; i_d_game_n <= 1; p41a <= 0; p41b <= 0; p41qd_l <= 0;
            d_time <= 0; slow <= 0; belt <= 0; slip_eh <= 0; c100 <= 1; dbg_pro <= 0;
            ck_l <= 12'hfeb;
            side_line_n <= 1; tree_grass_g_n <= 1; tree_grass_bl_n <= 1; grass_area_n <= 1;
            grass_w_n <= 1; house_st_n <= 1; house_n <= 4'hf; pool_n <= 1; wall_n <= 1;
            gravel_n <= 1; slide_n <= 1; slip_n <= 1; green_belt_n <= 1; y_line_n <= 1;
            tunnel_ap <= 0; bridge_ap <= 0; road <= 0; road_n <= 1; tunnel_n <= 1;
            tunnel_bridge_n <= 1; ext500 <= 0; ext500_n <= 1; car_no_cont_n <= 1;
            r_side_n <= 1; l_side_n <= 1; zero_area_n <= 0; dbg <= 0;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            if (edge2) begin
                // Settled outputs of the pixel just evaluated
                side_line_n     <= i_mh[4] | lv;
                tree_grass_g_n  <= ~(y112_9 | y105_7 | ic58_11);   // IC60 (9, 10, 11 -> 8)
                tree_grass_bl_n <= ~(y112_7 | y105_9);              // IC34 (11, 12 -> 13)
                grass_area_n    <= g105_n;
                grass_w_n       <= ~y105_9;                         // IC22 (3 -> 4)
                house_st_n      <= g98_n;
                house_n         <= house_c;
                pool_n          <= ~(y119_9 & pool);                // IC72 (9, 10 -> 8)
                wall_n          <= ~(y119_7 & wall);                // IC72 (2, 1 -> 3)
                gravel_n        <= ~(y119_7 & ic66_6);              // IC72 (13, 12 -> 11)
                slide_n         <= slide_c;
                slip_n          <= ~slip;
                green_belt_n    <= green_n;
                y_line_n        <= yline_n;
                tunnel_ap       <= tunnel;
                bridge_ap       <= bridge;
                road            <= q74;
                road_n          <= ~q74;
                tunnel_n        <= ~q31b;
                tunnel_bridge_n <= ~(q31b | q25a);                  // IC34 (6, 5 -> 4)
                ext500          <= q25b;
                ext500_n        <= ~q25b;
                car_no_cont_n   <= dec_n[5];
                r_side_n        <= rside_n;
                l_side_n        <= lside_n;
                zero_area_n     <= ic82_10;
                dbg             <= state;
                // Pro outputs
                d_time          <= q41b[3];                         // IC41 pin 8
                slow            <= q40a | q31a | q31b | q25a;       // NOT IC32 pin 6
                belt            <= ic58_11;
                slip_eh         <= q31a;
                c100            <= code[2];                         // IC34 pin 9
                dbg_pro         <= {q41b, q41a};
                // Capture the next pixel
                {i_hs, i_v7, i_v8, i_mhl_n, i_m1vl_n, i_m2vl_n, i_v4dec_n} <=
                    {hs, v7, v8, mhl_n, m1vl_n, m2vl_n, v4dec_n};
                i_mh <= mh; i_m1v <= m1v; i_m2v <= m2v;
                i_extend <= extend; i_coin_in_n <= coin_in_n; i_s100 <= s100;
                i_display_n <= display_n; i_d_game_n <= d_game_n;
            end else begin
                // One settling step
                ck_l <= ck;
                l68_r <= l68;
                {f40a, f31a, f31b, f25a, f25b, f38b, f40b, f38a, f88a, f88b, f74} <=
                    {n40a, n31a, n31b, n25a, n25b, n38b, n40b, n38a, n88a, n88b, n74};
                c49 <= n49;
                p41a <= n41a; p41b <= n41b; p41qd_l <= q41a[3];
            end
        end
    end
endmodule
