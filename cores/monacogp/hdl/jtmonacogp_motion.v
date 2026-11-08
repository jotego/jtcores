// SPDX-License-Identifier: GPL-3.0-or-later
// 96578-P sheet B (manual 420-0358, PDF page 29): road-motion counters MH,
// M1V and M2V with their load selection, the V decoder IC54, and the text
// PROM PR-133 with its gating. Pin-level transcription:
// docs/trace/SHEET_B_TRACE.md. Behaviour: docs/SHEET_B_LOGIC.md.
//
// Host clocks are counted from the pxl_cen clock edge (edge 0).
// - Edge 0 ends a pixel. The inputs of the counters are kept as they were
//   in that pixel (*_l), and the latches IC68 and IC69 store the state they
//   settled to in it.
// - Edge 1: the counters step on those values. MH (IC118, IC103, IC57)
//   counts every 7 MHz pixel. M1V (IC85, IC76) and M2V (IC91, IC77) count
//   the rises of /HS, at the pixel boundary where HS falls; the V counters
//   of sheet E are clocked by the same edge, so these see the /V8 of the
//   line that ends.
// - From edge 1 on every output is valid for the pixel. PR-133 is a
//   synchronous memory: its data follow the address, which changes at
//   edge 0, at edge 1.
// Timing rule ("settled layers", as for sheets F and G): the latches see the
// V lines and the counter carries after both have settled. On the board both
// change after the same /HS edge and C12 (C10) slows R1 (R2); the race this
// leaves out can move a road turn by one line (docs/SHEET_B_LOGIC.md).
// pxl_cen must be at least two host clocks apart. The capacitors (C10, C12,
// C15, the 220p and 470p parts) are not reproduced.
//
// Pro Monaco GP (manual 420-0525, sheet B, PDF page 13), selected by pro = 1:
// pro/docs/SHEETS_B_C_D_PRO_LOGIC.md, from pro/docs/trace/SHEETS_B_E_COMPARE.md.
// - The display timer IC72 (two 7474 halves, both /CLR on /COIN IN, pad E1
//   on Pro, the PROM's A8 net): 72a clocked by Vs/512 (pad E8, sheet H),
//   72b by 72a's drawn output with D = /COIN IN; 72b /Q (pin 8) is /DISPLAY.
//   IC72A selects the reading of 72a (see the parameter). Vs/512 comes from
//   sheet H's frame counter, not from the 7 MHz edge: the halves step at the
//   host clock after it rises, and are clear while /COIN IN is low.
// - IC70 (74157, S = /DISPLAY): D-EXTEND, /D-EXTEND and /D-GAME are A's
//   EXTEND, /EXTEND and /GAME while /DISPLAY is high, D-TIME, NOT D-TIME
//   (IC57 9 -> 8) and low while it is low.
// - IC29 (74157, S = /DISPLAY) in front of IC111 and IC110: SP.D..SP.A, or
//   {SLOW, 0, 0, 0} while /DISPLAY is low.
// With pro = 0 none of this is used and every output is as before.
module jtmonacogp_motion #(
    // Values of M1V and M2V after reset. The board has no reset for them;
    // /IN RESET (VSEL low) moves both by a line every frame.
    parameter [7:0] M1V_INIT = 8'd0,
    parameter [7:0] M2V_INIT = 8'd0,
    // Pro IC72a, whose D is drawn on its own output, numbered 5 (Q): as drawn
    // it never toggles (pro/docs/SHEETS_B_C_D_PRO_LOGIC.md, U1).
    // 0: as drawn (D and 72b's clock on Q); 1: the numeral read as 6 (D and
    // 72b's clock on /Q; default); 2: D on /Q, 72b's clock on Q.
    parameter integer IC72A = 1
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E. /H5, /H8, /V4, /V8 and /(V-CA x V8) are formed here.
    input      [8:0] h,                 // H0..H8
    input            hs,                // HS, active high; the counters see /HS
    input      [8:0] v,                 // V0..V8
    // Sheet H
    input      [3:0] sp,                // {SP.D, SP.C, SP.B, SP.A}, pads FU, F17, F7, F16
    input            vs2, vs4, vs16,    // pads E20, EW, E19
    // Sheet A
    input            coin_in_n,         // /COIN IN, pad ED -> PR-133 pin 23
    input            coin_in_e1_n,      // /COIN IN, pad E1 -> IC72 pin 5
    input            ex_signal_n,       // /EX. SIGNAL, pad F1
    input            game_n,            // /GAME, pad E6
    input            in_reset_n,        // /IN RESET, pad EA
    // Sheet D
    input            tunnel_bridge_n,   // /TUNNEL & BRIDGE -> IC95 pin 9
    // Pro board; ignored while pro = 0. /COIN IN for IC72 is coin_in_n (the
    // PROM's A8 net, pad E1 on Pro).
    input            pro,               // 1: Pro Monaco GP board
    input            vs512,             // Vs/512 (H), pad E8 -> IC72 pin 3
    input            extend, extend_n,  // EXTEND, /EXTEND (A), pads EB, E3 -> IC70 pins 3, 6
    input            d_time,            // D-TIME (D) -> IC70 pin 2, IC57 pin 9
    input            slow,              // SLOW (D) -> IC29 pin 14
    output           display_n,         // /DISPLAY, IC72 pin 8 -> (D)
    output           d_extend,          // D-EXTEND, IC70 pin 4 -> (C), (D), (M)
    output           d_extend_n,        // /D-EXTEND, IC70 pin 7 -> (C), (M)
    output           d_game_n,          // /D-GAME, IC70 pin 9 -> (D)
    // PR-133 = IC64, 512 x 8. Address A8..A0.
    output     [8:0] pr133_addr,
    input      [7:0] pr133_q,
    // Outputs
    output     [8:0] mh,                // MH0..MH8 -> (D); MH0..MH4 also (M)
    output           mhld_n,            // IC55 pin 8 -> (D)
    output     [7:0] m1v, m2v,          // -> (D)
    output           m1vld_n,           // R1, IC62 pin 4 -> (D)
    output           m2vld_n,           // R2, IC62 pin 8 -> (D)
    output     [5:1] vdec_n,            // V-(1)..V-(5), IC54 pins 2..6 -> (M); V-(4) also (D)
    output           ex_gameover_n,     // /EX. & GAME OVER, IC70 pin 11 -> (C)
    output           coin_start_n,      // /COIN & START, IC70 pin 8 -> (C)
    // Internal nets, for tests
    output           q1, q2,            // IC69 pins 9 (M1V half) and 5 (M2V half)
    output           q68,               // IC68 pin 13
    output           vsel,              // IC87 pin 3
    output           strobe_n,          // IC70 pin 6 -> IC63 pin 7
    output           txt                // IC63 pin 6
);
    reg        edge1;
    reg  [8:0] mh_q;
    reg  [7:0] m1v_q, m2v_q;
    reg        q1_r, q2_r, q68_r;
    // Counter inputs in the pixel that ends at edge 0
    reg        hs_l, v8_l, mhsel_l, vsel_l;
    reg  [3:0] sp_l;
    // Pro IC72: Q of each half, and Vs/512 in the pixel that ends
    reg        q72a, q72b, vs512_l;

    // ---------------------------------------------------------------- Pro IC72, IC70, IC29
    // 7474 /CLR wins: both halves read low while /COIN IN is low.
    wire clr72 = pro & ~coin_in_n;
    wire q72a_o = ~clr72 & q72a, q72b_o = ~clr72 & q72b;
    wire d72a  = IC72A == 0 ? q72a_o : ~q72a_o;          // 72a pin 2
    wire ck72b = IC72A == 1 ? ~q72a_o : q72a_o;          // 72b pin 11
    assign display_n = ~q72b_o;                          // 72b pin 8
    // IC70: 1A/1B -> 4, 2A/2B -> 7, 3A/3B -> 9
    assign d_extend   = display_n ? extend   : d_time;
    assign d_extend_n = display_n ? extend_n : ~d_time;
    assign d_game_n   = display_n ? game_n   : display_n;
    // IC29 outputs 12, 9, 7, 4 = SP.D..SP.A as IC111 and IC110 see them
    wire [3:0] spx = !pro || display_n ? sp : {slow, 3'b000};

    // IC54 (7442): A, B, C = V5, V6, V7; D at GND. Output n (pins 2..7, 9 for
    // n = 1..7) is low for V7..V5 = n; output 0 is not drawn.
    wire [7:1] dec_n = {v[7:5] != 3'd7, v[7:5] != 3'd6, v[7:5] != 3'd5, v[7:5] != 3'd4,
                        v[7:5] != 3'd3, v[7:5] != 3'd2, v[7:5] != 3'd1};
    assign vdec_n = dec_n[5:1];

    // ---------------------------------------------------------------- MH
    // IC118 (low nibble) and IC103 (161s, clock 7M), IC57 (74107, J, K and
    // /CLR at Vcc) toggling as IC103's carry falls, i.e. as MH0..MH7 leave FF.
    // /MHLD = IC55 (9, 10, 11 -> 8) = NAND(IC118 carry, IC103 carry, MH8).
    assign mh = mh_q;
    assign mhld_n = mh_q != 9'h1ff;
    // IC111 (74157) S = /(V-CA x V8), sheet E IC110 pin 3; V-CA is IC100's
    // carry, V0..V7 all high. So S is low on line 1FF only.
    wire mhsel = ~(&v[7:0] & v[8]);
    // Load word MH7..MH0 = {GND, GND, Vcc, IC111 pins 12, 9, 7, 4, GND}. IC111
    // I1 inputs (pins 13, 10, 6, 3) = Vcc, Vcc, GND, GND; I0 inputs (14, 11,
    // 5, 2) = SP.D, SP.C, SP.B, SP.A. So 0x38 (456 clocks, one line) or
    // 0x20 + 2*SP (480 - 2*SP clocks).
    wire [3:0] ic111 = mhsel_l ? 4'b1100 : sp_l;

    // ---------------------------------------------------------------- M1V, M2V
    // 161 pairs clocked by /HS; ENT of the low nibbles IC85, IC91 is /V8.
    // R1 = IC62 (3 -> 4) of IC76's carry; R2 = IC62 (9 -> 8) of IC77's.
    assign m1v = m1v_q;
    assign m2v = m2v_q;
    assign m1vld_n = ~(~v[8] & &m1v_q);
    assign m2vld_n = ~(~v[8] & &m2v_q);
    // IC69 (7474), D and CK not drawn: each half is a latch on /PR and /CL.
    // M1V half: /PR 10 = IC62 (11 -> 10) of IC61 (1, 2, 13 -> 12) = OR(D1, V4, R1);
    //           /CL 13 = IC62 (1 -> 2) of IC61 (3, 4, 5 -> 6) = OR(D2, /V4, R1).
    // M2V half: /PR 4 = UG1 (1, 2 -> 3) = OR(D5, R2);
    //           /CL 1 = IC62 (13 -> 12) of IC61 (9, 10, 11 -> 8) = OR(D7, /V4, R2).
    // A /PR and its /CL are never low together: they need different V7..V5.
    wire pr1_n = dec_n[1] | v[4] | m1vld_n;
    wire cl1_n = dec_n[2] | ~v[4] | m1vld_n;
    wire pr2_n = dec_n[5] | m2vld_n;
    wire cl2_n = dec_n[7] | ~v[4] | m2vld_n;
    assign q1 = ~pr1_n | (cl1_n & q1_r);
    assign q2 = ~pr2_n | (cl2_n & q2_r);
    // VSEL = IC87 (1, 2 -> 3) AND(/IN RESET, IC94 (1, 2, 13 -> 12)),
    // IC94 = NAND(Vs/4, Vs/2, IC95 (9, 10 -> 8)), IC95 = AND(/TUNNEL & BRIDGE,
    // IC110 (12, 13 -> 11)), IC110 = NAND(SP.D, SP.C).
    assign vsel = in_reset_n & ~(vs4 & vs2 & tunnel_bridge_n & ~(spx[3] & spx[2]));
    // IC83 (IC84) low-nibble load D..A: S low {/Q, Q, Q, Vcc} (7 or 9),
    // S high {Vcc, GND, GND, GND} (8). The high nibbles load 0000.
    wire [3:0] ld83 = vsel_l ? 4'b1000 : {~q1_r, q1_r, q1_r, 1'b1};
    wire [3:0] ld84 = vsel_l ? 4'b1000 : {~q2_r, q2_r, q2_r, 1'b1};

    // ---------------------------------------------------------------- text
    // IC68 (74279 latch 4): /S pin 15 = D2, /R pin 14 = D6.
    assign q68 = ~dec_n[2] | (dec_n[6] & q68_r);
    // IC64 = PR-133: pins 8..3 (A0..A5) = V1..V6, pin 2 (A6) = H3, pin 1 (A7)
    // = H8, pin 23 (A8) = /COIN IN. Enables at Vcc (18, 19) and GND (20, 21).
    assign pr133_addr = {coin_in_n, h[8], h[3], v[6:1]};
    // IC71 (1, 2, 4, 5 -> 6) = NAND(H4, H7, H6, IC68 Q)
    wire t_h = ~(h[4] & h[7] & h[6] & q68);
    // IC72 (4, 5 -> 6) = NAND(/EX. SIGNAL, /COIN IN)
    wire ic72_6 = ~(ex_signal_n & coin_in_e1_n);
    // IC71 (9, 10, 12, 13 -> 8) = NAND(/H8, Vs/16, H5, IC72 pin 6)
    wire t_msg = ~(~h[8] & vs16 & h[5] & ic72_6);
    // IC55 (3, 4, 5 -> 6) = NAND(/GAME, H8, /H5)
    wire t_coin = ~(game_n & h[8] & ~h[5]);
    // IC52 (4, 5 -> 6) AND, IC70 (4, 5 -> 6) OR -> IC63 strobe
    assign strobe_n = t_h | (t_msg & t_coin);
    // IC63 (74151): I0..I7 = PR-133 pins 9, 10, 11, 13..17; A, B, C = H0..H2.
    assign txt = strobe_n | ~pr133_q[h[2:0]];
    assign ex_gameover_n = txt | t_msg;     // IC70 (12, 13 -> 11)
    assign coin_start_n  = txt | t_coin;    // IC70 (9, 10 -> 8)

    always @(posedge clk) begin
        if (rst) begin
            // The board has no reset for these parts; this is one power-up state.
            edge1 <= 0;
            mh_q <= 0; m1v_q <= M1V_INIT; m2v_q <= M2V_INIT;
            q1_r <= 0; q2_r <= 0; q68_r <= 0;
            hs_l <= 0; v8_l <= 0; mhsel_l <= 1; vsel_l <= 1; sp_l <= 0;
            q72a <= 0; q72b <= 0; vs512_l <= vs512;
        end else begin
            edge1 <= pxl_cen;
            // Pro IC72: Vs/512 comes from sheet H's frame counter, not from
            // the 7 MHz edge, so the halves step at the host clock after it
            // rises. Held clear while /COIN IN is low (and with pro = 0).
            vs512_l <= vs512;
            if (clr72 || !pro) begin
                q72a <= 0; q72b <= 0;
            end else if (vs512 && !vs512_l) begin
                q72a <= d72a;
                // 72b sees its clock rise as 72a turns
                if (!ck72b && (IC72A == 1 ? ~d72a : d72a)) q72b <= coin_in_n;
            end
            if (pxl_cen) begin
                hs_l <= hs;
                v8_l <= v[8];
                mhsel_l <= mhsel;
                vsel_l <= vsel;
                sp_l <= spx;
                q1_r <= q1;
                q2_r <= q2;
                q68_r <= q68;
            end
            if (edge1) begin
                // 161 /LOAD is synchronous and overrides the count enables.
                if (mh_q[7:0] == 8'hff) mh_q[8] <= ~mh_q[8];
                mh_q[7:0] <= mh_q == 9'h1ff ? {3'b001, ic111, 1'b0} : mh_q[7:0] + 8'd1;
                if (hs_l && !hs) begin
                    if (!v8_l && &m1v_q) m1v_q <= {4'd0, ld83};
                    else if (!v8_l) m1v_q <= m1v_q + 8'd1;
                    if (!v8_l && &m2v_q) m2v_q <= {4'd0, ld84};
                    else if (!v8_l) m2v_q <= m2v_q + 8'd1;
                end
            end
        end
    end
endmodule
