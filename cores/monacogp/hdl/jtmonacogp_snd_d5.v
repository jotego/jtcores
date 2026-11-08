// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-5/7 of board 96598-P: the HI SCORE tune
// (docs/trace/SOUND_D5_TRACE.md; model and checks: docs/SOUND_LOGIC.md).
//
// Sequencer (logic): the IC27 74LS132 tempo oscillator (R114, C106,
// R113), latch 1 (IC37) that HI SCORE sets, the 74161 IC26 counting each
// note's length from the PROM (IC21, prm40.ic21) and the 393 IC22
// stepping its address, END at address 17 (IC38), latch 2 and the
// IC35 gate whose output `alarm` un-mutes the D-4 output stage while the
// tune plays, and the 74123 that retriggers the envelope at each note.
// Its asynchronous logic settles in eight passes a step, one a clock.
//
// Analog part, stepped at 480 kHz: the IC1 a/b vibrato triangle, the IC1
// c/d note voltages (one per bank of trimmers, the PROM's C/B/A bits
// selecting the branch), the two sawtooth oscillators IC2/IC4/TR2 and
// IC3/IC5/TR3 (two-slope model with characterized turning points), the
// IC15 c mixer, the IC6 c/d Sallen-Key low- and high-pass (stepped
// exactly with first-order-hold matrices), the envelope (74123 through
// D4 into C14, IC6 a/b to CONTROL) and the MC3340 IC7 (the D-6/D-7
// table model, computed here on this module's own multiplier) with C8,
// the C100 pole, C15 and R408 into the D-4 mixer's 6 V virtual ground.
//
// One multiplier, pipelined: a product issued in one state is read in
// the next. One table ROM: an entry pair issued in one state is
// interpolated by the product issued two states later. One step per
// `start`; `done` about 80 clocks later. Inputs held through the step.
// The PROM's 32 bytes come from the ROM download (base 8768).
// tests/sound/d5_fixed.py (D5Fixed) is the same arithmetic and generates
// jtmonacogp_snd_d5.vh; with D5_REF defined the module reads the SPICE
// reference's settings (jtmonacogp_snd_d5_ref.vh, tests only).
module jtmonacogp_snd_d5(
    input                    clk,
    input                    rst,
    input                    start,
    input                    hiscore_n, // pad 3, HI SCORE (low pulse)
    input                    mute,      // pad, MUTE (IC35 pin 6)
    // the PROM (prm40.ic21)
    output             [4:0] prom_addr_d5,
    input              [7:0] prom_data_d5,
    output reg signed [35:0] i_mix,     // R408 current times R414, 2^28 per volt
    output reg               alarm,     // IC35 pin 4, to D-4 IC67 pin 10
    output reg               done,
    // test views, updated once per step
    output reg signed [35:0] v_lfo, v_cvu, v_cvl, v_sawu, v_sawl, v_mix,
    output reg signed [35:0] v_lp, v_hp, v_env, v_con, v_mco,
    output reg         [4:0] v_addr,
    output reg         [3:0] v_cnt,
    output reg               v_q123,
    output reg               v_clk
);
`ifdef D5_REF
    `include "jtmonacogp_snd_d5_ref.vh"
`else
    `include "jtmonacogp_snd_d5.vh"
`endif

    // ---- states
    localparam [6:0]
        S_IDLE=0,
        S_Q0=1, S_Q1=2, S_Q2=3, S_Q3=4, S_Q4=5, S_Q5=6, S_Q6=7, S_Q7=8,
        S_L2=9, S_A0=10,
        S_V0=11, S_V1=12, S_V2=13, S_V3=14, S_V4=15, S_V5=16, S_V6=17, S_V7=18,
        S_V8=19, S_V9=20, S_V10=21, S_V11=22, S_V12=23, S_V13=24, S_V14=25,
        S_V15=26, S_V16=27,
        S_F0=28, S_F1=29, S_F2=30, S_F3=31, S_F4=32, S_F5=33, S_F6=34, S_F7=35,
        S_F8=36, S_F9=37, S_F10=38,
        S_H0=39, S_H1=40, S_H2=41, S_H3=42, S_H4=43, S_H5=44, S_H6=45, S_H7=46,
        S_H8=47, S_H9=48, S_H10=49,
        S_M0=50, S_M1=51, S_M2=52, S_M3=53, S_M4=54, S_M5=55, S_M6=56, S_M7=57,
        S_M8=58, S_M9=59, S_M10=60, S_M11=61, S_M12=62, S_M13=63, S_M14=64,
        S_M15=65, S_M16=66, S_M17=67, S_M18=68, S_M19=69, S_M20=70, S_M21=71,
        S_M22=72, S_M23=73, S_M24=74, S_M25=75, S_M26=76, S_M27=77, S_M28=78;
    reg [6:0] st;

    // ---- sequencer state
    reg  [4:0]  addr;
    reg  [3:0]  cnt;
    reg         q8, q11, q3, q6, o11, clk_r, ck393, end_r, load_n_r, clr_n_r;
    reg  [14:0] q123;
    reg  signed [51:0] vc;
    reg         line_l, mute_l, ep;
    reg         q_on, h_l;
    reg  [2:0]  idx;

    // one pass of the asynchronous logic (tests/sound/d5_model.py, settle)
    wire        e_end  = addr[0] & addr[4];
    wire        e_rose = e_end & ~end_r;
    wire [3:0]  e_cnt1 = e_end ? 4'd0 : cnt;
    wire        e_o11  = e_end ? 1'b1 :
                         ( o11 && vc >= D5_VTP) ? 1'b0 :
                         (!o11 && vc <= D5_VTN) ? 1'b1 : o11;
    wire        e_clk  = ~e_o11;
    wire        e_q11a = ~(~e_clk & q8);
    wire        e_q8a  = ~(e_q11a & line_l);
    wire        e_q11b = ~(~e_clk & e_q8a);
    wire        e_q8b  = ~(e_q11b & line_l);
    wire [4:0]  e_addr1 = e_q8b ? 5'd0 : addr;
    wire        e_rco  = e_cnt1 == 4'd15;
    wire        e_load_n = ~(e_rco | e_q8b);
    wire        e_end2 = e_addr1[0] & e_addr1[4];
    wire        e_clr_n = ~e_end2;
    wire        e_rise = e_clk & ~clk_r;
    wire        e_ck   = ~(e_end2 | e_rco);
    wire [7:0]  e_pd   = prom_data_d5;

    // ---- analog state
    reg  signed [51:0] lfo, q, xlp0, xlp1, xhp0, xhp1, env, n50, q8c, q15;
    reg  signed [35:0] su, sl, p_mix, p_lp, mcf;
    reg                o17, init, mcf_first, upu, upl;
    // ---- step registers
    reg  signed [35:0] e, kl, d4s, cvu, cvl, envf, con;
    reg  signed [35:0] dnu, dnl, rupu, rupl, btu, btl, ratu, ratl, kau, su1, sl1;
    reg                xu, xl;
    reg  signed [35:0] mixr, mix, lx0, lx1, lp, w0, w1, hpr, hp;
    reg  signed [51:0] acc;
    reg  signed [35:0] mcin, g, vo0, lo, von, vonw, h, ib, u, wx, ic, w, heff, xs, mco, iin, e15;
    reg                icx, sx;

    wire signed [35:0] lfo_s  = lfo[51:16];
    wire signed [35:0] q_s    = q[51:16];
    wire signed [35:0] xlp0_s = xlp0[51:16];
    wire signed [35:0] xlp1_s = xlp1[51:16];
    wire signed [35:0] xhp0_s = xhp0[51:16];
    wire signed [35:0] xhp1_s = xhp1[51:16];
    wire signed [35:0] env_s  = env[51:16];
    wire signed [35:0] n50_s  = n50[51:16];
    wire signed [35:0] q8_s   = q8c[51:16];
    wire signed [35:0] q15_s  = q15[51:16];
    wire signed [35:0] vc_s   = vc[51:16];

    wire signed [51:0] lfo_n  = lfo - (o17 ? D5_DL_ON : D5_DL_OFF);
    localparam signed [51:0] LFO_LO = D5_VOL <<< 16, LFO_HI = D5_VOH <<< 16;

    function signed [35:0] lim;
        input signed [35:0] v;
        lim = v < D5_VOL ? D5_VOL : v > D5_VOH ? D5_VOH : v;
    endfunction

    reg signed [35:0] cv0u, cv0l;
    always @* begin
        case (idx)
            3'd0: begin cv0u = D5_CV0U0; cv0l = D5_CV0L0; end
            3'd1: begin cv0u = D5_CV0U1; cv0l = D5_CV0L1; end
            3'd2: begin cv0u = D5_CV0U2; cv0l = D5_CV0L2; end
            3'd3: begin cv0u = D5_CV0U3; cv0l = D5_CV0L3; end
            3'd4: begin cv0u = D5_CV0U4; cv0l = D5_CV0L4; end
            3'd5: begin cv0u = D5_CV0U5; cv0l = D5_CV0L5; end
            3'd6: begin cv0u = D5_CV0U6; cv0l = D5_CV0L6; end
            default: begin cv0u = D5_CV0U7; cv0l = D5_CV0L7; end
        endcase
    end

    // ---- table ROM: issued in one state, the entries two states later,
    // interpolated there; the value in the state after
    localparam [4:0]
        TT_TOP=0, TT_BOT=1, TT_RUP=2, TT_RUD=3, TT_RDU=4, TT_D4=5, TT_G=6,
        TT_VO0=7, TT_LO=8, TT_VON=9, TT_VONW=10, TT_H=11, TT_IB=12, TT_W=13,
        TT_IC=14, TT_S=15;
    reg  [4:0]         tsel;
    reg                tiss;
    reg  signed [35:0] tx;
    reg  [11:0]        ra;
    reg  [24:0]        fra, frb;
    reg  [4:0]         ffa, ffb;
    reg  signed [35:0] rq0, rq1, rq0_d;
    reg  [11:0]        t_base, t_n;
    reg  [4:0]         t_f;
    reg  signed [35:0] t_x0;
    always @* case (tsel)
        TT_TOP:  begin t_base=T_TOP_BASE;  t_n=T_TOP_N;  t_f=T_TOP_F;  t_x0=T_TOP_X0;  end
        TT_BOT:  begin t_base=T_BOT_BASE;  t_n=T_BOT_N;  t_f=T_BOT_F;  t_x0=T_BOT_X0;  end
        TT_RUP:  begin t_base=T_RUP_BASE;  t_n=T_RUP_N;  t_f=T_RUP_F;  t_x0=T_RUP_X0;  end
        TT_RUD:  begin t_base=T_RUD_BASE;  t_n=T_RUD_N;  t_f=T_RUD_F;  t_x0=T_RUD_X0;  end
        TT_RDU:  begin t_base=T_RDU_BASE;  t_n=T_RDU_N;  t_f=T_RDU_F;  t_x0=T_RDU_X0;  end
        TT_D4:   begin t_base=T_D4_BASE;   t_n=T_D4_N;   t_f=T_D4_F;   t_x0=T_D4_X0;   end
        TT_G:    begin t_base=T_G_BASE;    t_n=T_G_N;    t_f=T_G_F;    t_x0=T_G_X0;    end
        TT_VO0:  begin t_base=T_VO0_BASE;  t_n=T_VO0_N;  t_f=T_VO0_F;  t_x0=T_VO0_X0;  end
        TT_LO:   begin t_base=T_LO_BASE;   t_n=T_LO_N;   t_f=T_LO_F;   t_x0=T_LO_X0;   end
        TT_VON:  begin t_base=T_VON_BASE;  t_n=T_VON_N;  t_f=T_VON_F;  t_x0=T_VON_X0;  end
        TT_VONW: begin t_base=T_VONW_BASE; t_n=T_VONW_N; t_f=T_VONW_F; t_x0=T_VONW_X0; end
        TT_H:    begin t_base=T_H_BASE;    t_n=T_H_N;    t_f=T_H_F;    t_x0=T_H_X0;    end
        TT_IB:   begin t_base=T_IB_BASE;   t_n=T_IB_N;   t_f=T_IB_F;   t_x0=T_IB_X0;   end
        TT_W:    begin t_base=T_W_BASE;    t_n=T_W_N;    t_f=T_W_F;    t_x0=T_W_X0;    end
        TT_IC:   begin t_base=T_IC_BASE;   t_n=T_IC_N;   t_f=T_IC_F;   t_x0=T_IC_X0;   end
        default: begin t_base=T_S_BASE;    t_n=T_S_N;    t_f=T_S_F;    t_x0=T_S_X0;    end
    endcase
    wire signed [36:0] t_r   = {tx[35], tx} - {t_x0[35], t_x0};
    wire signed [36:0] t_i   = t_r >>> t_f;
    wire        [24:0] t_fr  = t_r[24:0] & ((25'd1 << t_f) - 25'd1);
    wire               t_neg = t_r[36];
    wire               t_top = !t_neg && t_i >= $signed({25'd0, t_n}) - 37'sd1;
    wire        [11:0] t_idx = t_neg ? 12'd0 : t_top ? t_n - 12'd2 : t_i[11:0];
    wire        [24:0] t_frc = t_neg ? 25'd0 : t_top ? (25'd1 << t_f) : t_fr;
    wire        [11:0] ra1   = ra + 12'd1;
    always @(posedge clk) begin
        if (tiss) begin
            ra  <= t_base + t_idx;
            fra <= t_frc;
            ffa <= t_f;
        end
        rq0   <= rom_d5[ra];
        rq1   <= rom_d5[ra1];
        rq0_d <= rq0;
        frb   <= fra;
        ffb   <= ffa;
    end

    // ---- the multiplier: issued in one state, mres in the next
    reg  signed [35:0] ma;
    reg  signed [26:0] mb;
    reg         [5:0]  msh;
    wire signed [62:0] prod = ma * mb;
    reg  signed [62:0] prod_q;
    reg         [5:0]  msh_q;
    always @(posedge clk) begin prod_q <= prod; msh_q <= msh; end
    wire signed [63:0] mrnd = {prod_q[62], prod_q} + (64'sd1 <<< (msh_q - 6'd1));
    wire signed [63:0] mres = mrnd >>> msh_q;
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0_d + mres_v;

    // the tempo capacitor's target (output high / low, below VT+ or not)
    wire        t_below = vc < D5_VTP;
    wire signed [35:0] vinf = o11 ? (t_below ? D5_VI_HB : D5_VI_HA) : (t_below ? D5_VI_LB : D5_VI_LA);

`define D5_MUL(a,m,s) begin ma = a; mb = m; msh = s; end
`define D5_INTERP begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
`define D5_TAB(s,x) begin tiss = 1'b1; tsel = s; tx = x; end

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tiss = 1'b0; tsel = TT_TOP; tx = 36'sd0;
        case (st)
            // envelope pieces and the note voltages' vibrato term while the
            // sequencer settles
            S_Q0: begin `D5_MUL(n50_s, K50_M, K50_S) `D5_TAB(TT_D4, D5_VQ - env_s) end
            S_Q2: `D5_INTERP
            S_Q3: `D5_MUL(e, KL_M, KL_S)
            S_Q4: `D5_MUL(e, KQ_M, KQ_S)
            S_L2: `D5_MUL(vinf - vc_s, KT_M, KT_S)
            S_A0: if (h_l) `D5_MUL(env_s, KE1_M, KE1_S) else `D5_MUL(env_s, KE0_M, KE0_S)
            // the oscillators
            S_V0: begin `D5_MUL(cvu, KDN_M, KDN_S) `D5_TAB(TT_RUP, cvu) end
            S_V1: begin `D5_MUL(cvl, KDN_M, KDN_S) `D5_TAB(TT_RUP, cvl) end
            S_V2: begin `D5_INTERP `D5_TAB(upu ? TT_TOP : TT_BOT, cvu) end
            S_V3: begin `D5_INTERP `D5_TAB(upl ? TT_TOP : TT_BOT, cvl) end
            S_V4: begin `D5_INTERP `D5_TAB(upu ? TT_RDU : TT_RUD, cvu) end
            S_V5: begin `D5_INTERP `D5_TAB(upl ? TT_RDU : TT_RUD, cvl) end
            S_V6, S_V7: `D5_INTERP
            S_V8: `D5_MUL(cvu, KA_M, KA_S)
            S_V9: `D5_MUL(cvl, KA_M, KA_S)
            S_V10: `D5_MUL(n50_s - envf, KC_M, KC_S)
            S_V11: if (upu) begin ma = su1 - btu; mb = ratu[26:0]; msh = 6'd28; end
                   else begin ma = ratu; mb = btu[26:0] - su1[26:0]; msh = 6'd24; end
            S_V12: if (upl) begin ma = sl1 - btl; mb = ratl[26:0]; msh = 6'd28; end
                   else begin ma = ratl; mb = btl[26:0] - sl1[26:0]; msh = 6'd24; end
            S_V14: `D5_MUL(sl - D5_V6, KM_M, KM_S)
            // the low-pass
            S_F0: `D5_MUL(lx0, LPA00_M, LPA00_S)
            S_F1: `D5_MUL(lx1, LPA01_M, LPA01_S)
            S_F2: `D5_MUL(p_mix, LPG00_M, LPG00_S)
            S_F3: `D5_MUL(mix, LPG01_M, LPG01_S)
            S_F4: `D5_MUL(lx0, LPA10_M, LPA10_S)
            S_F5: `D5_MUL(lx1, LPA11_M, LPA11_S)
            S_F6: `D5_MUL(p_mix, LPG10_M, LPG10_S)
            S_F7: `D5_MUL(mix, LPG11_M, LPG11_S)
            // the high-pass
            S_H0: `D5_MUL(lx0, HPA00_M, HPA00_S)
            S_H1: `D5_MUL(lx1, HPA01_M, HPA01_S)
            S_H2: `D5_MUL(w0, HPG00_M, HPG00_S)
            S_H3: `D5_MUL(w1, HPG01_M, HPG01_S)
            S_H4: `D5_MUL(lx0, HPA10_M, HPA10_S)
            S_H5: `D5_MUL(lx1, HPA11_M, HPA11_S)
            S_H6: `D5_MUL(w0, HPG10_M, HPG10_S)
            S_H7: `D5_MUL(w1, HPG11_M, HPG11_S)
            // the MC3340
            S_M1: `D5_TAB(TT_G, con)
            S_M2: `D5_TAB(TT_VO0, con)
            S_M3: begin `D5_INTERP `D5_TAB(TT_VON, con) end
            S_M4: begin `D5_INTERP `D5_TAB(TT_VONW, con) end
            S_M5: begin `D5_INTERP `D5_TAB(TT_H, mcin) end
            S_M6: begin `D5_INTERP `D5_TAB(TT_IB, mcin) end
            S_M7: begin `D5_INTERP `D5_TAB(TT_LO, con) end
            S_M8: begin `D5_INTERP `D5_TAB(TT_IC, u) end
            S_M9: begin `D5_INTERP `D5_TAB(TT_W, wx) end
            S_M10: if (icx) `D5_MUL(u - MC_U_MAX, KICS_M, KICS_S) else `D5_INTERP
            S_M11: `D5_INTERP
            S_M13: begin ma = MC_H_LOW - h; mb = w[29:3]; msh = 6'd25; end
            S_M15: begin ma = heff; mb = g[29:3]; msh = 6'd25; end
            S_M17: `D5_TAB(TT_S, xs)
            S_M19: `D5_INTERP
            // C8, the C100 pole, C15 and R408
            S_M21: `D5_MUL(iin, KC8_M, KC8_S)
            S_M22: `D5_MUL(mco - mcf, KROLL_M, KROLL_S)
            S_M25: `D5_MUL(e15, K15_M, K15_S)
            S_M26: `D5_MUL(e15, KMX_M, KMX_S)
            S_M27: `D5_MUL(e15, KPIN_M, KPIN_S)
            default:;
        endcase
    end
`undef D5_MUL
`undef D5_INTERP
`undef D5_TAB

    wire settling = st >= S_Q0 && st <= S_Q7;
    reg prom_pending;
    assign prom_addr_d5 = settling ? e_addr1 : addr;

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE;
            addr <= 5'd17; cnt <= 4'd0;
            q8 <= 1'b0; q11 <= 1'b1; q3 <= 1'b1; q6 <= 1'b0;
            o11 <= 1'b1; vc <= D5_VC0;
            clk_r <= 1'b0; ck393 <= 1'b0; end_r <= 1'b1; load_n_r <= 1'b1; clr_n_r <= 1'b0;
            q123 <= 15'd0;
            line_l <= 1'b1; mute_l <= 1'b0; ep <= 1'b0; q_on <= 1'b0; h_l <= 1'b0; idx <= 3'd0;
            lfo <= D5_LFO0; o17 <= 1'b1; q <= 52'sd0;
            su <= 36'sd0; sl <= 36'sd0; upu <= 1'b0; upl <= 1'b0; init <= 1'b1;
            xlp0 <= 52'sd0; xlp1 <= 52'sd0; xhp0 <= 52'sd0; xhp1 <= 52'sd0;
            p_mix <= 36'sd0; p_lp <= 36'sd0;
            env <= 52'sd0; n50 <= 52'sd0; q8c <= 52'sd0; q15 <= 52'sd0;
            mcf <= 36'sd0; mcf_first <= 1'b1;
            prom_pending <= 1'b0;
            i_mix <= 36'sd0; alarm <= 1'b0;
            {v_lfo, v_cvu, v_cvl, v_sawu, v_sawl, v_mix, v_lp, v_hp, v_env, v_con, v_mco} <= 0;
            v_addr <= 5'd17; v_cnt <= 4'd0; v_q123 <= 1'b0; v_clk <= 1'b0;
        end else begin
            // ---- one settling pass of the sequencer a clock
            if (settling) begin
                if (e_rose) ep <= 1'b1;
                end_r <= e_end;
                o11 <= e_o11;
                q11 <= e_q11b; q8 <= e_q8b;
                if (!e_clr_n) q123 <= 15'd0;
                else if ((load_n_r && !e_load_n) || (!clr_n_r && !e_load_n)) q123 <= D5_TW;
                load_n_r <= e_load_n; clr_n_r <= e_clr_n;
                if (e_rise) begin
                    clk_r <= 1'b1;
                    cnt   <= e_end2 ? e_cnt1 : e_cnt1 + 4'd1;
                    addr  <= e_addr1;
                    if (!e_load_n) prom_pending <= 1'b1;
                end else begin
                    clk_r <= e_clk;
                    cnt   <= e_cnt1;
                    addr  <= (ck393 && !e_ck && !e_q8b) ? e_addr1 + 5'd1 : e_addr1;
                    ck393 <= e_ck;
                end
            end
            if (prom_pending) begin
                cnt <= prom_data_d5[3:0];
                prom_pending <= 1'b0;
            end
            case (st)
                S_IDLE: if (start) begin
                    line_l <= hiscore_n;
                    mute_l <= mute;
                    ep <= 1'b0;
                    st <= S_Q0;
                end
                S_Q0: begin
                    // the vibrato: C3 steps by TR1's state
                    lfo <= lfo_n < LFO_LO ? LFO_LO : lfo_n > LFO_HI ? LFO_HI : lfo_n;
                    st <= S_Q1;
                end
                S_Q1: begin
                    n50 <= n50 + D5_N50A - mres_s;
                    o17 <= lfo_s < (o17 ? D5_TH_H : D5_TH_L);
                    e   <= lfo_s - q_s - D5_REF;
                    st <= S_Q2;
                end
                S_Q2: st <= S_Q3;
                S_Q3: begin d4s <= tval; st <= S_Q4; end
                S_Q4: begin kl <= mres_v; st <= S_Q5; end
                S_Q5: begin q <= q + mres_s; st <= S_Q6; end
                S_Q6: st <= S_Q7;
                S_Q7: st <= S_L2;
                // ---- latch 2, the 74123's pulse, the PROM's bits
                S_L2: begin
                    // latch 2: the END pulse resets it, HI SCORE sets it
                    // (two rounds, as the model)
                    begin : latch2
                        reg a3, a6;
                        a3 = ep ? 1'b1 : q3;
                        a6 = ep ? ~(a3 & line_l) : q6;
                        a3 = ~a6; a6 = ~(a3 & line_l);
                        a3 = ~a6; a6 = ~(a3 & line_l);
                        q3 <= a3; q6 <= a6;
                        alarm <= ~a3 & ~mute_l;
                    end
                    q_on <= q123 != 15'd0;
                    if (q123 != 15'd0) q123 <= q123 - 15'd1;
                    h_l <= prom_data_d5[7];
                    idx <= {~prom_data_d5[6], ~prom_data_d5[5], ~prom_data_d5[4]};
                    st <= S_A0;
                end
                S_A0: begin
                    vc  <= vc + mres_s;
                    cvu <= lim(cv0u - kl);
                    cvl <= lim(cv0l - kl);
                    st <= S_V0;
                end
                // ---- the envelope, then the oscillators
                S_V0: begin env <= env + (q_on ? {{16{d4s[35]}}, d4s} : 52'sd0) - mres_s; st <= S_V1; end
                S_V1: begin dnu <= mres_v; envf <= lim(env_s); st <= S_V2; end
                S_V2: begin dnl <= mres_v; st <= S_V3; end
                S_V3: begin rupu <= tval; st <= S_V4; end
                S_V4: begin rupl <= tval; st <= S_V5; end
                S_V5: begin btu <= tval; st <= S_V6; end
                S_V6: begin btl <= tval; st <= S_V7; end
                S_V7: begin ratu <= tval; st <= S_V8; end
                S_V8: begin ratl <= tval; st <= S_V9; end
                S_V9: begin kau <= mres_v; st <= S_V10; end
                S_V10: begin
                    // at power-up the + input's level, rising if below BOT
                    su1 <= init ? kau : upu ? su + rupu : su - dnu;
                    sl1 <= init ? mres_v : upl ? sl + rupl : sl - dnl;
                    st <= S_V11;
                end
                S_V11: begin
                    con <= lim(n50_s + mres_v);
                    xu <= upu ? su1 >= btu : su1 <= btu;
                    xl <= upl ? sl1 >= btl : sl1 <= btl;
                    st <= S_V12;
                end
                S_V12: begin
                    su  <= !xu || init ? su1 : upu ? btu - mres_v : btu + mres_v;
                    upu <= upu ^ xu;
                    st <= S_V13;
                end
                S_V13: begin
                    sl  <= !xl || init ? sl1 : upl ? btl - mres_v : btl + mres_v;
                    upl <= upl ^ xl;
                    init <= 1'b0;
                    st <= S_V14;
                end
                S_V14: st <= S_V15;
                S_V15: begin mixr <= D5_V6 - (su - D5_V6) - mres_v; st <= S_V16; end
                S_V16: begin
                    mix <= lim(mixr);
                    lx0 <= xlp0_s; lx1 <= xlp1_s;
                    st <= S_F0;
                end
                // ---- the low-pass
                S_F0: st <= S_F1;
                S_F1: begin acc <= mres_s; st <= S_F2; end
                S_F2: begin acc <= acc + mres_s; st <= S_F3; end
                S_F3: begin acc <= acc + mres_s; st <= S_F4; end
                S_F4: begin xlp0 <= xlp0 + acc + mres_s; st <= S_F5; end
                S_F5: begin acc <= mres_s; st <= S_F6; end
                S_F6: begin acc <= acc + mres_s; st <= S_F7; end
                S_F7: begin acc <= acc + mres_s; st <= S_F8; end
                S_F8: begin xlp1 <= xlp1 + acc + mres_s; p_mix <= mix; st <= S_F9; end
                S_F9: begin lp <= lim(xlp1_s); lx0 <= xhp0_s; lx1 <= xhp1_s; st <= S_F10; end
                S_F10: begin w0 <= p_lp - D5_V6; w1 <= lp - D5_V6; st <= S_H0; end
                // ---- the high-pass
                S_H0: st <= S_H1;
                S_H1: begin acc <= mres_s; st <= S_H2; end
                S_H2: begin acc <= acc + mres_s; st <= S_H3; end
                S_H3: begin acc <= acc + mres_s; st <= S_H4; end
                S_H4: begin xhp0 <= xhp0 + acc + mres_s; st <= S_H5; end
                S_H5: begin acc <= mres_s; st <= S_H6; end
                S_H6: begin acc <= acc + mres_s; st <= S_H7; end
                S_H7: begin acc <= acc + mres_s; st <= S_H8; end
                S_H8: begin xhp1 <= xhp1 + acc + mres_s; p_lp <= lp; st <= S_H9; end
                S_H9: begin hpr <= lp - xhp0_s - xhp1_s; st <= S_H10; end
                S_H10: begin hp <= lim(hpr); st <= S_M0; end
                // ---- the MC3340 (tests/sound/d67_fixed.py, mc3340)
                S_M0: begin mcin <= hp - q8_s; st <= S_M1; end
                S_M1: st <= S_M2;
                S_M2: st <= S_M3;
                S_M3: st <= S_M4;
                S_M4: begin g    <= tval; st <= S_M5; end
                S_M5: begin vo0  <= tval; st <= S_M6; end
                S_M6: begin von  <= tval; st <= S_M7; end
                S_M7: begin vonw <= tval; u <= mcin - von; st <= S_M8; end
                S_M8: begin h    <= tval; wx <= mcin - vonw; icx <= u > MC_U_MAX; st <= S_M9; end
                S_M9: begin ib   <= tval; st <= S_M10; end
                S_M10: begin lo  <= tval; st <= S_M11; end
                S_M11: begin ic  <= icx ? MC_IC_LAST + mres_v : tval; st <= S_M12; end
                S_M12: begin w   <= tval; st <= S_M13; end
                S_M13: st <= S_M14;
                S_M14: begin heff <= h + mres_v; st <= S_M15; end
                S_M15: st <= S_M16;
                S_M16: begin xs <= vo0 - mres_v - lo; st <= S_M17; end
                S_M17: begin sx <= xs >= MC_S_MAX; st <= S_M18; end
                S_M18: st <= S_M19;
                S_M19: st <= S_M20;
                S_M20: begin
                    mco <= (lo + (sx ? xs : tval)) > MC_MC_HI ? MC_MC_HI : lo + (sx ? xs : tval);
                    iin <= ib + ic;
                    st <= S_M21;
                end
                // ---- C8, the C100 pole, C15 and R408
                S_M21: st <= S_M22;
                S_M22: begin q8c <= q8c + mres_s; st <= S_M23; end
                S_M23: begin mcf <= mcf_first ? mco : mcf + mres_v; mcf_first <= 1'b0; st <= S_M24; end
                S_M24: begin e15 <= mcf - q15_s - D5_V6; st <= S_M25; end
                S_M25: st <= S_M26;
                S_M26: begin q15 <= q15 + mres_s; st <= S_M27; end
                S_M27: begin i_mix <= mres_v; st <= S_M28; end
                S_M28: begin
                    v_mco <= mcf - mres_v;
                    v_lfo <= lfo_s; v_cvu <= cvu; v_cvl <= cvl; v_sawu <= su; v_sawl <= sl;
                    v_mix <= mix; v_lp <= lp; v_hp <= hp; v_env <= env_s; v_con <= con;
                    v_addr <= addr; v_cnt <= cnt; v_q123 <= q_on; v_clk <= clk_r;
                    done <= 1'b1;
                    st <= S_IDLE;
                end
                default: st <= st + 7'd1;
            endcase
        end
    end
endmodule
