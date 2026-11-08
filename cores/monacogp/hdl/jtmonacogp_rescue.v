// SPDX-License-Identifier: GPL-3.0-or-later
// 96578-P sheet M (manual 420-0358, PDF page 33): the rescue car (position
// counters, PR-138, its timing and /RESCUE CP), the signs (PR-139), the
// lives counter IC46 with the spare cars and GAME OVER, and the bridge
// (PR-140, PR-141, the side lines). Pin-level transcription:
// docs/trace/SHEET_M_TRACE.md. Behaviour: docs/SHEET_M_LOGIC.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0). The sheet is
// evaluated one pixel late, like sheets D and H:
// - Edge 2 is the 7 MHz edge that ends a pixel. The outputs of that pixel are
//   registered; IC36 and IC37 (clocked by 7M) step on the pixel's settled
//   nets; IC18 counts the pixel; then the next pixel's inputs are captured.
// - Every later host clock up to edge 1 of the next pixel is one settling
//   step. The four PROMs are synchronous memories, read as one layer.
// Timing rule for one step ("settled layers", as on sheet H): gates are
//   combinational on the state; every flip-flop, counter and one-shot, and
//   every asynchronous clear and preset, takes one step: it compares its
//   clock, trigger and clear nets with their values at the previous step and
//   changes state for the next one. tests/sheet_m_reference.v implements the
//   same rule with delays on a pin-wired netlist.
// The capacitors on IC43's select (C9), on the /LOAD net, on IC37's carry,
// on IC42.8 (C6), IC44.6 (C7) and /DUMMY AREA (C5) are not reproduced.
// pxl_cen must be at least six host clocks apart.
//
// Pro Monaco GP (manual 420-0525, sheet M, PDF page 17), selected by pro = 1:
// the +200 graphic, pro/docs/trace/SHEET_M_C_PLUS200_TRACE.md. With pro = 0
// the new input is ignored, /+200 stays high and the module is the original
// sheet M.
//   - PR-54 (IC130, 6331, 32 x 8, /E1 at GND): A0..A4 = V0..V4 in straight
//     order. A1 = V1 and A2 = V2 is the trace's probable reading (R1/R2); a
//     swap would exchange address bits 1 and 2.
//   - IC129 (74151): D0..D7 = PR-54 O1..O8; A, B, C = H1, H2, H3 (H0
//     unused); /G = IC124.8; output W (pin 6) = /+200 (R) -> (C).
//   - IC124 (7410, 11, 10, 9 -> 8) = NAND(IC79.12 = NOT V-(4), BONUS CP,
//     IC128.8 = NOR(H4, H5, H6, H7)).
//   So /+200 is low where the selected PR-54 bit is 1, in the window
//   H 0x100-0x10F x V 0x080-0x09F while BONUS CP is high: one PROM word per
//   line, each bit for two H clocks. The 6331 outputs are open collector with
//   no pull-up drawn; a released output reads high at the 74151, as stored.
//   It is registered with the other outputs (one pixel late).
// PR-54 has no known dump. The table below (pr54) is Aldo's RECONSTRUCTION of
// the +200 artwork (pro/reconstruction/plus200-glyph.txt, 6 November 2026,
// O1 = bit 0), not original PROM data.
module jtmonacogp_rescue #(
    // IC18: 74123 data sheet, tw = 0.28*R*C*(1+0.7/R), R in kohm, in periods
    // of 7.1525 MHz. R16 47k (first digit blotted, U5 of the trace), C4 1.5 uF.
    parameter integer IC18_PIXELS = 143293
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E: 7M is the pixel clock itself; V-CA = V0..V7 all high
    input      [8:0] h,                 // H0..H8 (H7 on the Pro board only)
    input      [8:0] v,                 // V0..V8 (V5 unused)
    input            hs,                // HS, active high; the sheet uses /HS
    // Sheet B
    input      [5:1] vdec_n,            // V-(1)..V-(5), IC54 outputs (active low)
    input      [4:0] mh,                // MH0..MH4
    // Sheet H (frame counter)
    input            vs4, vs16,         // arrows (B)
    input            vs32, vs64,        // pads E18, EV
    // Sheet A (through C for EXTEND)
    input            extend, extend_n,
    input            game_n, coin_in_n,
    input            ex_signal_cp_n,    // /EX. SIGNAL CP, pad E2
    // Sheet D
    input            s100c,             // 100-C
    input            car_no_cont_n,     // CAR. NO. CONT (D), sheet D's /CAR NO CONT
    input            ext500, ext500_n,  // EXT. 500, /EXT. 500
    input            zero_area_n,       // /0-AREA
    input            bridge_ap,         // BRIDGE AP
    // Sheet C (from sheet H's /OTHER CAR)
    input            other_car_n,
    // Sheet F
    input            acce_d,            // ACCE. D, pad E14
    input            explo_sel_d,       // EXPLO. SEL. D, pad EM
    // Pro board (sheet N); ignored while pro = 0
    input            pro,               // 1: Pro Monaco GP board
    input            bonus_cp,          // BONUS CP (N) -> IC124 pin 10
    // PR-138 = IC30, PR-139 = IC51, PR-140 = IC12, PR-141 = IC17 (512 x 8)
    output     [8:0] pr138_addr, pr139_addr, pr140_addr,
    input      [7:0] pr138_q, pr139_q, pr140_q, pr141_q,
    // Settled values for the previous pixel, registered at edge 2
    output reg       rescue_bl_n, rescue_r_n, rescue_w_n, rescue_y_n,  // -> (C); (Y) also pad EB -> (F)
    output reg       rl_side_n,         // pad FE -> (H)
    output reg       ext_car_cont,      // pad EX -> (F)
    output reg       rescue_cp_n,       // pad D9 -> (S)
    output reg       sig_y_n, sig_bl_n, // -> (C)
    output reg       dummy_area_n, dummy_w_n, dummy_r_n, dummy_bl_n,   // -> (C)
    output reg       game_over,         // pad E16 -> (A)
    output reg       bridge_w_n,        // -> (C), pad EH -> (F)
    output reg       bridge_dbu_n, bridge_y_n, bridge_r_n, bridge_bu_n, // -> (C)
    output reg       l2_side_n, r2_side_n,                             // pads F4, F5 -> (H)
    output reg       plus200_n,         // Pro: IC129 pin 6 (W), /+200 (R) -> (C); high with pro = 0
    // Tests only
    output reg [21:0] dbg,              // internal state, previous pixel
    output           busy               // a further step would change the state
);
    reg  [2:0] cen_sr;
    wire edge2 = cen_sr[1];

    // Captured inputs
    reg  [8:0] i_h, i_v;
    reg        i_hs_n, i_vs4, i_vs16, i_vs32, i_vs64, i_extend, i_extend_n, i_game_n, i_coin_n;
    reg        i_excp_n, i_100c, i_cnc_n, i_ext500, i_ext500_n, i_zero_n, i_bap, i_other_n, i_acce_d, i_explo;
    reg  [5:1] i_vd;
    reg  [4:0] i_mh;
    reg        i_pro, i_bonus_cp;

    // State
    reg  [3:0] c36, c37, c49, c46;
    reg        q57, q35u, q35l;
    reg [17:0] m18;                     // IC18 pixels left
    // Nets at the previous step
    reg [10:0] ck_l;

    // ---------------------------------------------------------------- rescue counters
    // IC36 (low) and IC37 (high), 74161 on 7M; IC37 CET = IC36 TC. IC44
    // (9, 10, 11 -> 8) = NAND(IC36 TC, IC37 TC, IC57 Q) loads both: IC36 with
    // IC43 (A 1010, B 1000), IC37 with 0011. IC43 S = IC42 (3, 4, 5 -> 6)
    // = NAND(V-CA, V8, IC35 upper Q).
    wire tc36 = c36 == 4'hf;
    wire tc37 = tc36 && c37 == 4'hf;
    wire n44_8 = ~(tc36 & tc37 & q57);
    wire vca = &i_v[7:0];
    wire s43 = ~(vca & i_v[8] & q35u);
    wire [3:0] l43 = s43 ? 4'b1000 : 4'b1010;
    // IC44 (3, 4, 5 -> 6) = NAND(IC57 Q, IC37 QC, IC37 QD): IC35 upper CK and
    // the rescue strobe through IC10 (5, 4 -> 6) OR(IC44.6, /R-L-SIDE).
    wire n44_6 = ~(q57 & c37[2] & c37[3]);
    // IC60 (2, 1, 13 -> 12) = NOR(V-(3), IC35 upper /Q, /V4); IC59 (11 -> 10).
    wire n59_10 = ~(~(i_vd[3] | ~q35u | ~i_v[4]));
    wire g29_n = n44_6 | n59_10;
    // PR-138: A0..A3 = V0..V3, A4, A5 = IC36 QC, QD, A6, A7 = IC37 QA, QB,
    // A8 = Vs/4. IC29 (74157): S = IC36 QB, A = D0, D2, D4, D6, B = D1, D3,
    // D5, D7.
    assign pr138_addr = {i_vs4, c37[1:0], c36[3:2], i_v[3:0]};
    wire [3:0] y29 = g29_n ? 4'd0 : c36[1] ? {pr138_q[7], pr138_q[5], pr138_q[3], pr138_q[1]}
                                          : {pr138_q[6], pr138_q[4], pr138_q[2], pr138_q[0]};

    // ---------------------------------------------------------------- rescue timing
    // IC49 (74393 half): CP = Vs/64 (falling), CL = /EXTEND. IC45 (10, 9 -> 8)
    // = NAND(IC49 QD, ACCE. D); IC47 (9, 10 -> 8) = AND(IC45.8, Vs/64) clocks
    // IC35's lower half (D = 100-C, /PR = IC49 QC). IC42 (9, 10, 11 -> 8) =
    // NAND(IC35 lower /Q, IC49 QB, IC49 QA) presets the upper half (D = /HS,
    // CK = IC44.6).
    wire n47_8 = ~(c49[3] & i_acce_d) & i_vs64;
    wire n42_8 = ~(~q35l & c49[1] & c49[0]);
    wire o18 = m18 != 0;

    // ---------------------------------------------------------------- signs
    // PR-139: A0..A4 = V0..V4, A5..A8 = H1..H4. IC50 (74157): S = H0, /G at
    // GND; Y3 is not drawn.
    assign pr139_addr = {i_h[4:1], i_v[4:0]};
    wire y50_1 = i_h[0] ? pr139_q[1] : pr139_q[0];
    wire y50_2 = i_h[0] ? pr139_q[3] : pr139_q[2];
    wire y50_4 = i_h[0] ? pr139_q[7] : pr139_q[6];
    // IC42 (1, 2, 13 -> 12) = NAND(H6, H5, /H8); IC73 = NOR(IC42.12, Vs/16,
    // /GAME); IC65 = NOR(/EXT. 500, V-(4)); IC66 (7411) = AND(IC59.8 =
    // NOT CAR. NO. CONT, IC73.8, IC65.1).
    wire n42_12 = ~(i_h[6] & i_h[5] & ~i_h[8]);
    wire n73_8 = ~(n42_12 | i_vs16 | i_game_n);
    wire n65_1 = ~(i_ext500_n | i_vd[4]);
    wire n66_8 = ~i_cnc_n & n73_8 & n65_1;
    wire n9_3 = ~(y50_4 & n66_8);
    wire n9_11 = ~(n9_3 & n66_8);

    // ---------------------------------------------------------------- lives and spare cars
    // IC53 (74153): A, B = IC46 QA, QB; /1G = H8, 1C0..3 = GND, H5, Vcc, Vcc;
    // /2G = V-(1), 2C0..3 = GND, H6, H6, IC39 (9, 10 -> 8) OR(H5, H6).
    wire [1:0] sel53 = c46[1:0];
    wire y53_1 = !i_h[8] && (sel53 == 2'd1 ? i_h[5] : sel53 != 2'd0);
    wire y53_2 = !i_vd[1] && (sel53 == 2'd0 ? 1'b0 : sel53 == 2'd3 ? (i_h[5] | i_h[6]) : i_h[6]);
    // IC26 = NAND(EXTEND, V4, IC53 1Y, 2Y) = /DUMMY AREA; IC59 (3 -> 4) inverts.
    wire n26_8 = ~(i_extend & i_v[4] & y53_1 & y53_2);
    wire n52_8 = i_vs16 & ~n26_8;
    wire n56_6 = ~(n52_8 & y50_2);
    wire n56_8 = ~(n52_8 & y50_1);
    wire n55_12 = ~(n56_6 & n56_8 & ~n26_8);
    // IC46 (74193): UP = IC39 (4, 5 -> 6) OR(IC52 (2, 1 -> 3) AND(QA, QB),
    // /EX. SIGNAL CP); DOWN = IC59 (1 -> 2) NOT EXPLO. SEL. D; CLR = /COIN IN
    // (drawn with a bubble, active high on the part; a count needs it released
    // at the step before); data and /LOAD unused.
    // /BO is low while the count is 0 and DOWN is low; IC59 (5 -> 6) inverts
    // it into GAME OVER.
    wire up46 = (c46[0] & c46[1]) | i_excp_n;
    wire dn46 = ~i_explo;
    wire bo46_n = !(c46 == 4'd0 && !dn46);

    // ---------------------------------------------------------------- bridge
    // IC10 (13, 12 -> 11) = OR(/0-AREA, IC15 (13, 12 -> 11) AND(V-(5),
    // V-(3))): high enables PR-140 (CE3, CE4), low PR-141 (/CE1, /CE2).
    wire sel_140 = i_zero_n | (i_vd[5] & i_vd[3]);
    // IC52 (13, 12 -> 11) = AND(Vcc, V7): the mirror line. IC23: A0..A3 = V0..V3
    // XOR V7; IC28 and IC21 (11, 10, 9 -> 8): A4 = AND(V4 XOR V7, V-(2), V6 XOR
    // V7); A5..A8 = MH1..MH4.
    wire v7 = i_v[7];
    wire a4b = (i_v[4] ^ v7) & i_vd[2] & (i_v[6] ^ v7);
    assign pr140_addr = {i_mh[4:1], a4b, i_v[3:0] ^ {4{v7}}};
    wire [7:0] dbr = sel_140 ? pr140_q : pr141_q;
    // IC11 (74157): S = MH0, /G = IC22 (1 -> 2) NOT V-(4); A = D0..D2, B = D4..D6
    // (Y4 not drawn). IC6 (7442): A..C = IC11 Y1..Y3, D = IC16 (10, 9 -> 8)
    // NAND(BRIDGE AP, IC21 (1, 2, 13 -> 12) AND(V-(4), /DUMMY AREA, /OTHER CAR)).
    wire [2:0] y11 = !i_vd[4] ? 3'd0 : i_mh[0] ? dbr[6:4] : dbr[2:0];
    wire n21_12 = i_vd[4] & n26_8 & i_other_n;
    wire n16_8 = ~(i_bap & n21_12);
    wire [3:0] code6 = {n16_8, y11};
    // IC15 (9, 10 -> 8) = AND(EXT. 500, IC11 Y1); IC16 NANDs it with V7 (F4)
    // and /V7 (F5).
    wire n15_8 = i_ext500 & y11[0];

    // ---------------------------------------------------------------- +200 (Pro)
    // PR-54, Aldo's reconstruction (see the header): address A4..A0 =
    // V4..V0, data bit k = output O(k+1).
    function [7:0] pr54(input [4:0] a);
        case (a)
            5'd0,  5'd1,  5'd4,  5'd5,  5'd8,  5'd9,  5'd12, 5'd13: pr54 = 8'h7e;
            5'd2,  5'd3,  5'd10, 5'd11:                             pr54 = 8'h42;
            5'd16, 5'd17:                                           pr54 = 8'h4e;
            5'd18, 5'd19:                                           pr54 = 8'h52;
            5'd20, 5'd21:                                           pr54 = 8'h66;
            5'd24, 5'd25, 5'd28, 5'd29:                             pr54 = 8'h10;
            5'd26, 5'd27:                                           pr54 = 8'h7c;
            default:                                                pr54 = 8'h00;
        endcase
    endfunction
    wire [7:0] pr54_q = pr54(i_v[4:0]);
    wire n128_8 = ~|i_h[7:4];                                   // IC128 (13, 9, 10, 12 -> 8)
    wire n124_8 = ~(~i_vd[4] & i_bonus_cp & n128_8);            // IC79 (13 -> 12), IC124
    wire w129 = n124_8 | ~pr54_q[i_h[3:1]];                     // IC129 W; /G high forces it high

    // ---------------------------------------------------------------- step
    wire [10:0] ck = {i_coin_n, tc37, n44_6, n42_8, i_vs64, i_extend_n, n47_8, c49[2], q35l, up46, dn46};
    // 74123 (B and /CLR at Vcc): A falling.
    wire t18 = ck_l[2] && !q35l;
    wire n57 = (!tc37 && ck_l[9]) ? ~q57 : q57;
    // 7474s: the preset wins over the clock, and a clock edge needs the preset
    // released at the step before too.
    wire n35u = !n42_8 ? 1'b1 : (n44_6 && !ck_l[8] && ck_l[7]) ? i_hs_n : q35u;
    wire n35l = !c49[2] ? 1'b1 : (n47_8 && !ck_l[4] && ck_l[3]) ? i_100c : q35l;
    wire [3:0] n49 = i_extend_n ? 4'd0 : (!i_vs64 && ck_l[6] && !ck_l[5]) ? c49 + 4'd1 : c49;
    wire [3:0] n46 = !i_coin_n ? ck_l[10] ? c46 : (up46 && !ck_l[1] && dn46) ? c46 + 4'd1 :
                                 (dn46 && !ck_l[0] && up46) ? c46 - 4'd1 : c46 : 4'd0;
    wire [21:0] state = {c36, c37, q57, q35u, q35l, c49, c46, o18, g29_n, sel_140};
    assign busy = ck != ck_l || t18 || n57 != q57 || n35u != q35u || n35l != q35l ||
                  n49 != c49 || n46 != c46;

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            i_h <= 0; i_v <= 0; i_hs_n <= 1; i_vd <= 5'h1f; i_mh <= 0;
            {i_vs4, i_vs16, i_vs32, i_vs64} <= 0;
            {i_extend, i_extend_n, i_game_n, i_coin_n, i_excp_n} <= 5'b01111;
            {i_100c, i_cnc_n, i_ext500, i_ext500_n, i_zero_n, i_bap, i_other_n, i_acce_d, i_explo} <= 9'b010111100;
            {i_pro, i_bonus_cp} <= 0;
            // The board has no reset; this is one power-up state.
            c36 <= 0; c37 <= 0; c49 <= 0; c46 <= 0;
            q57 <= 0; q35u <= 0; q35l <= 0; m18 <= 0;
            ck_l <= 11'b10110100011;
            {rescue_bl_n, rescue_r_n, rescue_w_n, rescue_y_n, rl_side_n, rescue_cp_n} <= 6'h3f;
            ext_car_cont <= 0;
            {sig_y_n, sig_bl_n, dummy_area_n, dummy_w_n, dummy_r_n, dummy_bl_n} <= 6'h3f;
            game_over <= 0;
            {bridge_w_n, bridge_dbu_n, bridge_y_n, bridge_r_n, bridge_bu_n, l2_side_n, r2_side_n} <= 7'h7f;
            plus200_n <= 1;
            dbg <= 0;
        end else begin
            cen_sr <= {cen_sr[1:0], pxl_cen};
            if (edge2) begin
                // Settled outputs of the pixel that ends at this 7 MHz edge
                rescue_bl_n <= ~y29[3];                     // IC22 (11 -> 10)
                rescue_w_n  <= ~y29[1];                     // IC22 (9 -> 8)
                rescue_y_n  <= ~y29[0];                     // IC22 (13 -> 12)
                rescue_r_n  <= ~(y29[2] & i_vs32);          // IC16 (5, 4 -> 6)
                rl_side_n   <= n59_10;
                ext_car_cont <= c49[1];
                rescue_cp_n <= ~o18;                        // IC7 (3 -> 4)
                sig_y_n <= n9_3;
                sig_bl_n <= n9_11;
                dummy_area_n <= n26_8;
                dummy_w_n <= n56_6;
                dummy_r_n <= n56_8;
                dummy_bl_n <= n55_12;
                game_over <= ~bo46_n;
                bridge_bu_n  <= code6 != 4'd0;
                bridge_r_n   <= code6 != 4'd1;
                bridge_y_n   <= code6 != 4'd2;
                bridge_dbu_n <= code6 != 4'd4;
                bridge_w_n   <= code6 != 4'd5;
                l2_side_n <= ~(n15_8 & v7);
                r2_side_n <= ~(n15_8 & ~v7);
                plus200_n <= ~i_pro | w129;
                dbg <= state;
                // The 7 MHz edge: IC36 and IC37
                if (!n44_8) begin
                    c36 <= l43;
                    c37 <= 4'b0011;
                end else begin
                    c36 <= c36 + 4'd1;
                    if (tc36) c37 <= c37 + 4'd1;
                end
                // One pixel of IC18
                if (m18 != 0) m18 <= m18 - 18'd1;
                // Capture the next pixel
                i_h <= h; i_v <= v; i_hs_n <= ~hs; i_vd <= vdec_n; i_mh <= mh;
                {i_vs4, i_vs16, i_vs32, i_vs64} <= {vs4, vs16, vs32, vs64};
                {i_extend, i_extend_n, i_game_n, i_coin_n, i_excp_n} <=
                    {extend, extend_n, game_n, coin_in_n, ex_signal_cp_n};
                {i_100c, i_cnc_n, i_ext500, i_ext500_n, i_zero_n, i_bap, i_other_n, i_acce_d, i_explo} <=
                    {s100c, car_no_cont_n, ext500, ext500_n, zero_area_n, bridge_ap, other_car_n, acce_d, explo_sel_d};
                {i_pro, i_bonus_cp} <= {pro, bonus_cp};
            end else begin
                // One settling step
                ck_l <= ck;
                q57 <= n57;
                q35u <= n35u;
                q35l <= n35l;
                c49 <= n49;
                c46 <= n46;
                if (t18) m18 <= IC18_PIXELS[17:0];
            end
        end
    end
endmodule
