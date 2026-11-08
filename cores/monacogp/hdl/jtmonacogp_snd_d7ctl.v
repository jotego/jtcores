// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-7/7 of board 96598-P: the other cars' control
// (docs/trace/SOUND_D7_TRACE.md; model and checks: docs/SOUND_LOGIC.md).
//
// - Decoder: S-ACCE B, C, D (IC36 74145, IC38, IC47) choose R169 1.2K (codes
//   0-5) or R124 1.5K (6, 7) against R125 1K from 12 V: the feed node, also
//   loaded by the ramps' 33K inputs (their - inputs of the previous step).
// - Ramps: TL081 integrators IC14 / IC28 (33K, 11 uF), + at R151 / R127
//   with C30. While a car's 74123 output is high, TR12 / TR13 pull the -
//   input through 100 ohm (current table, from the reference's transistor).
//   Each integrator is in one of three modes per step: at its upper limit,
//   at its lower limit (its - input then away from + by the capacitor), or
//   linear (- input at +).
// - IC15: u = 6.857 V * 1.47 - 0.47 * ramp.
// - IC29: two LM339 stages per car with 2.2K / 100K hysteresis: c292 /
//   c2913 high while u is below about 6 V.
// - Triggers (IC55, IC46, IC56) with pad C (/F-SOUND, `fs_low`: low at any
//   clock of the step), and the 74123s IC59 a/b (6.59 ms) and IC58 (0.628 s),
//   retriggerable, counted in steps.
// - Shapers IC17 / IC16 on u, IC31 / IC30 choosing the larger of each pair
//   (with their hysteresis) through IC24 / IC23, the IC18 / IC32 followers:
//   the four MC3340 CONTROLs; IC18 c / d: CAR CON (2 * reference - front
//   CONTROL).
// One step per `start`; `done` after about 65 clocks.
// tests/sound/d67_fixed.py (CtlFixed) is the same arithmetic.
module jtmonacogp_snd_d7ctl(
    input                    clk,
    input                    rst,
    input                    start,
    input              [3:0] acc,      // S-ACCE D, C, B, A (pad high = 1)
    input                    fs_low,   // pad C low during the step
    output reg signed [35:0] con20, con19, con34, con33, cv1, cv2,
    output reg               q59a, q59b,
    output reg               done,
    // test views
    output reg signed [35:0] v_feed, v_r14, v_r28, v_u1, v_u2,
    output reg               v_c292, v_c2913, v_q58
);
    `include "jtmonacogp_snd_d67.vh"

    localparam [5:0]
        S_IDLE=0, S_F=1,
        S_R0=2,  S_R1=3,  S_R2=4,  S_R3=5,  S_R4=6,  S_R5=7,  S_R6=8,  S_R7=9,
        S_REF=10, S_U0=11, S_U1=12, S_H0=13, S_H1=14, S_D=15, S_RB=16, S_RD=17,
        S_S0=18, S_S1=19, S_S2=20, S_S3=21, S_S4=22,
        S_L0=23, S_L1=24, S_L2=25, S_L3=26, S_E=27;

    reg [5:0] st;
    reg       ph;
    reg       rk;                     // ramp 0 / 1 in S_R*
    reg       mul_st;
    always @* case (st)
        S_F, S_R1, S_R2, S_R3, S_R6, S_R7, S_REF, S_U0, S_U1, S_H0, S_H1, S_RB, S_RD,
        S_S0, S_S1, S_S2, S_S3, S_L0, S_L1, S_L2, S_L3: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    // ---- state
    reg signed [51:0] q[0:1];
    reg signed [51:0] ref14;
    reg signed [35:0] vmr[0:1];       // the ramps' - inputs
    reg               c29a, c29c;     // IC29 first stages high
    reg        [3:0]  sel;            // IC31 a, IC30 a, IC31 c, IC30 c high
    reg        [11:0] os59a, os59b;
    reg        [18:0] os58;
    reg               nor_a, nor_c;
    // ---- step registers
    reg signed [35:0] feed, cma, cmn, itr, pin, vmn, r14, r28, u1, u2, rb, rd;
    reg signed [35:0] sa1, sb1, sa2, sb2, dq;
    reg signed [35:0] s[0:7];

    wire signed [35:0] q_s    = q[rk][51:16];
    wire signed [35:0] ref_s  = ref14[51:16];
    wire        [2:0]  n      = acc[3:1];
    wire               n_hi   = n[2] & n[1];
    wire               tr_on  = rk ? os59b != 12'd0 : os59a != 12'd0;

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction
    function signed [35:0] lim(input signed [35:0] x);
        lim = x < VOL ? VOL : x > VOH ? VOH : x;
    endfunction

    // ---- table ROM (reset current)
    reg                tsel;
    reg  signed [35:0] tx;
    reg  [11:0]        ra;
    reg  [24:0]        fra, frb;
    reg  signed [35:0] rq0, rq1;
    wire signed [36:0] t_r   = {tx[35], tx} - {T_TR_X0[35], T_TR_X0};
    wire signed [36:0] t_i   = t_r >>> T_TR_F;
    wire        [24:0] t_fr  = t_r[24:0] & ((25'd1 << T_TR_F) - 25'd1);
    wire               t_neg = t_r[36];
    wire               t_top = !t_neg && t_i >= $signed({25'd0, T_TR_N}) - 37'sd1;
    wire        [11:0] t_idx = t_neg ? 12'd0 : t_top ? T_TR_N - 12'd2 : t_i[11:0];
    wire        [24:0] t_frc = t_neg ? 25'd0 : t_top ? (25'd1 << T_TR_F) : t_fr;
    wire        [11:0] ra1   = ra + 12'd1;
    always @(posedge clk) if (adv) begin
        if (tsel) begin
            ra  <= T_TR_BASE + t_idx;
            fra <= t_frc;
        end
        rq0 <= rom_tr[ra];
        rq1 <= rom_tr[ra1];
        frb <= fra;
    end

    // ---- the multiplier
    reg  signed [35:0] ma;
    reg  signed [26:0] mb;
    reg         [5:0]  msh;
    wire signed [62:0] prod = ma * mb;
    reg  signed [62:0] prod_q;
    always @(posedge clk) prod_q <= prod;
    wire signed [63:0] mrnd = {prod_q[62], prod_q} + (64'sd1 <<< (msh - 6'd1));
    wire signed [63:0] mres = mrnd >>> msh;
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres_v;

    // hysteresis stage: + = B + x * A (output high or low); x and the
    // previous output per state
    reg signed [35:0] hx;
    reg               hh;
    always @* begin
        case (st)
            S_H0:    begin hx = u1; hh = c29a; end
            S_H1:    begin hx = u2; hh = c29c; end
            S_L0:    begin hx = s[0]; hh = sel[0]; end
            S_L1:    begin hx = s[2]; hh = sel[1]; end
            S_L2:    begin hx = s[4]; hh = sel[2]; end
            default: begin hx = s[6]; hh = sel[3]; end
        endcase
    end
    wire signed [35:0] hplus = (hh ? HYST_BH : HYST_BL) + mres_v;

    // ramp mode: at the upper limit, the lower limit or linear
    wire signed [35:0] pin_h = PH0 + cmn;
    wire signed [35:0] pin_l = PL0 + cmn;
    wire signed [35:0] vm_h  = pin_h + q_s;
    wire signed [35:0] vm_l  = pin_l + q_s;

    // triggers
    wire c292  = !c29a;
    wire c2913 = !c29c;
    wire n56   = !n[2];
    wire nor_an = fs_low && !c292 && !n56;
    wire nor_bn = fs_low && !c2913 && !n56;
    wire nor_cn = nor_bn && c292 && os58 == 19'd0;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tsel = 1'b0; tx = 36'sd0;
        case (st)
            S_F:   begin ma = vmr[0] + vmr[1]; mb = n_hi ? KFHI_M : KFLO_M; msh = n_hi ? KFHI_S : KFLO_S; end
            S_R0:  begin tsel = 1'b1; tx = vmr[rk]; end
            S_R1:  begin ma = feed - q_s; mb = KP1_M; msh = KP1_S; end
            S_R2:  begin ma = tdel; mb = {2'b0, frb}; msh = T_TR_F; end
            S_R3:  begin ma = itr; mb = KP2_M; msh = KP2_S; end
            S_R6:  begin ma = feed - vmn; mb = KQ1_M; msh = KQ1_S; end
            S_R7:  begin ma = itr; mb = KQ2_M; msh = KQ2_S; end
            S_REF: begin ma = V6 - ref_s; mb = KREF_M; msh = KREF_S; end
            S_U0:  begin ma = r14; mb = KU_M; msh = KU_S; end
            S_U1:  begin ma = r28; mb = KU_M; msh = KU_S; end
            S_H0, S_H1, S_L0, S_L1, S_L2, S_L3:
                   begin ma = hx; mb = hh ? KHA_M : KHL_M; msh = hh ? KHA_S : KHL_S; end
            S_RB:  begin ma = u1 + u2; mb = KRB_M; msh = KRB_S; end
            S_RD:  begin ma = u1 + u2; mb = KRD_M; msh = KRD_S; end
            S_S0:  begin ma = u1; mb = KSA_M; msh = KSA_S; end
            S_S1:  begin ma = u1; mb = KSB_M; msh = KSB_S; end
            S_S2:  begin ma = u2; mb = KSA_M; msh = KSA_S; end
            S_S3:  begin ma = u2; mb = KSB_M; msh = KSB_S; end
            default:;
        endcase
    end

    integer k;
    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0; rk <= 1'b0;
            q[0] <= 52'sd0; q[1] <= 52'sd0; ref14 <= 52'sd0;
            vmr[0] <= 36'sd0; vmr[1] <= 36'sd0;
            c29a <= 1'b0; c29c <= 1'b0; sel <= 4'd0;
            os59a <= 12'd0; os59b <= 12'd0; os58 <= 19'd0;
            nor_a <= 1'b0; nor_c <= 1'b0;
            {con20, con19, con34, con33, cv1, cv2} <= 0;
            q59a <= 1'b0; q59b <= 1'b0;
            {v_feed, v_r14, v_r28, v_u1, v_u2} <= 0;
            {v_c292, v_c2913, v_q58} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) st <= S_F;
                S_F: begin
                    feed <= (n_hi ? FEED0_HI : FEED0_LO) + mres_v;
                    rk <= 1'b0; st <= S_R0;
                end
                // ramps
                S_R0: st <= S_R1;
                S_R1: begin cma <= mres_v; st <= S_R2; end
                S_R2: begin itr <= tr_on ? tval : 36'sd0; st <= S_R3; end
                S_R3: begin cmn <= cma - mres_v; st <= S_R4; end
                S_R4: st <= S_R5;
                S_R5: begin
                    if (vm_h <= ref_s) begin pin <= pin_h; vmn <= vm_h; end
                    else if (vm_l >= ref_s) begin pin <= pin_l; vmn <= vm_l; end
                    else begin pin <= ref_s - q_s; vmn <= ref_s; end
                    st <= S_R6;
                end
                S_R6: begin dq <= mres_v; st <= S_R7; end
                S_R7: begin
                    q[rk] <= q[rk] + {{16{dq[35]}}, dq} - mres_s;
                    vmr[rk] <= vmn;
                    if (rk) begin r28 <= pin; st <= S_REF; end
                    else begin r14 <= pin; rk <= 1'b1; st <= S_R0; end
                end
                S_REF: begin ref14 <= ref14 + mres_s; st <= S_U0; end
                S_U0:  begin u1 <= clamp(U0 - mres_v, VOL, VOH); st <= S_U1; end
                S_U1:  begin u2 <= clamp(U0 - mres_v, VOL, VOH); st <= S_H0; end
                S_H0:  begin c29a <= hplus > REF6; st <= S_H1; end
                S_H1:  begin c29c <= hplus > REF6; st <= S_D; end
                // triggers and one-shots
                S_D: begin
                    os59a <= nor_an && !nor_a ? OS59_N[11:0] : os59a != 12'd0 ? os59a - 12'd1 : 12'd0;
                    os58  <= nor_an && !nor_a ? OS58_N[18:0] : os58 != 19'd0 ? os58 - 19'd1 : 19'd0;
                    os59b <= nor_cn && !nor_c ? OS59_N[11:0] : os59b != 12'd0 ? os59b - 12'd1 : 12'd0;
                    nor_a <= nor_an; nor_c <= nor_cn;
                    st <= S_RB;
                end
                S_RB: begin rb <= RB0 + mres_v; st <= S_RD; end
                S_RD: begin rd <= RD0 + mres_v; st <= S_S0; end
                // shapers: s[0..3] car 1 (a, b, c, d), s[4..7] car 2
                S_S0: begin s[0] <= lim(SA0 - mres_v); st <= S_S1; end
                S_S1: begin s[1] <= lim(mres_v - rb);  st <= S_S2; end
                S_S2: begin s[4] <= lim(SA0 - mres_v); st <= S_S3; end
                S_S3: begin
                    s[5] <= lim(mres_v - rb);
                    s[2] <= lim(SC0 - u1); s[3] <= lim((u1 + rd) >>> 1);
                    s[6] <= lim(SC0 - u2); s[7] <= lim((u2 + rd) >>> 1);
                    st <= S_L0;
                end
                // selectors
                S_L0: begin sel[0] <= hplus > s[1]; st <= S_L1; end
                S_L1: begin sel[1] <= hplus > s[3]; st <= S_L2; end
                S_L2: begin sel[2] <= hplus > s[5]; st <= S_L3; end
                S_L3: begin sel[3] <= hplus > s[7]; st <= S_E; end
                S_E: begin
                    con20 <= sel[0] ? s[0] : s[1];
                    con19 <= sel[1] ? s[2] : s[3];
                    con34 <= sel[2] ? s[4] : s[5];
                    con33 <= sel[3] ? s[6] : s[7];
                    cv1 <= clamp(CV1_0 - (sel[0] ? s[0] : s[1]), VOL, CV_MAX);
                    cv2 <= clamp(CV2_0 - (sel[2] ? s[4] : s[5]), VOL, CV_MAX);
                    q59a <= os59a != 12'd0; q59b <= os59b != 12'd0;
                    v_feed <= feed; v_r14 <= r14; v_r28 <= r28; v_u1 <= u1; v_u2 <= u2;
                    v_c292 <= !c29a; v_c2913 <= !c29c; v_q58 <= os58 != 19'd0;
                    done <= 1'b1;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
