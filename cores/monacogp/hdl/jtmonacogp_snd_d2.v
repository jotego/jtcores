// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-2/7 of board 96598-P: the RESCUE CAR siren and the BACK
// SOUND (docs/trace/SOUND_D2_TRACE.md; model and checks:
// docs/SOUND_LOGIC.md).
//
// Each /RESCUE CP pulse (pad P, sheet M) sets the IC42 latch: the rear
// envelope (IC42 b, 16.5 uF) falls through D18 / R283 51K until the
// comparator IC42 c (3.44 V) resets the latch, then rises through R282 82K
// / D17. As it falls below 4.9 V, IC43 a's edge (C55 into the Schmitt
// IC43 a) sets the IC43 latch: the front envelope (IC44 a, 23.5 uF) falls
// through D20 / R291 10K until IC44 d (3.44 V) resets it, then rises
// through R290 220K / D19. The envelopes drive the MC3340 CONTROLs through
// the followers IC40 c (rear, IC41) and IC44 c (front, IC45) with the
// 2.8 V rail. Both MC3340s attenuate the sawtooth of jtmonacogp_snd_d2vco.
// Rear: IC41, C52, R276 18K into IC40 b with BACK OTHER CAR (D-7), C50,
// R274 into node Z: pad R (BACK SOUND OUT, R279 1K into an assumed 10K
// amplifier input), BACK SOUND STB. (R275 50 ohm, sunk by D-4's IC57 in
// attract: `mute`) and, with DIP SW. 2's contact closed (`dip_back`), C114
// and R424 100K into the D-4 mixer. Front: IC45, C58, R292 10K into IC44 b
// (gain -10), C60 and R410 220K into the mixer.
//
// The two MC3340s share one jtmonacogp_snd_mc3340, rear then front; both
// take the previous step's sawtooth and CONTROLs (the VCO runs beside
// them). BACK OTHER CAR is D-7's output of the previous step. Outputs:
// `i_mix`, the R410 and R424 currents times R414 (22K), and `padr`, pad R;
// 2^28 per volt. One step per `start`; `done` after about 80 clocks.
// tests/sound/d2_fixed.py (D2Fixed) is the same arithmetic.
module jtmonacogp_snd_d2(
    input                    clk,
    input                    rst,
    input                    start,
    input                    resc,     // pad P low (/RESCUE CP)
    input                    mute,     // BACK SOUND STB. sunk (D-4 IC57)
    input                    dip_back, // DIP SW. 2: back sound into the mix
    input  signed     [35:0] i_bk,     // BACK OTHER CAR current times 51K
    output reg signed [35:0] i_mix,
    output reg signed [35:0] padr,
    output reg               done,
    // test views, updated once per step
    output reg signed [35:0] v_env_r, v_env_f, v_con41, v_con45,
    output reg signed [35:0] v_mc41o, v_mc45o, v_o40_7, v_z, v_o44_7,
    output reg signed [35:0] v_o42_1, v_o43_7, v_i410, v_i424,
    output reg               v_o42_8, v_o43_14, v_o43_1, v_o44_14,
    output        signed [35:0] v_saw, v_o40_1,
    output                   v_o555
);
    `include "jtmonacogp_snd_d2.vh"

    localparam [5:0]
        S_IDLE=0, S_E0=1, S_L0=2, S_L1=3, S_L2=4, S_L3=5,
        S_R0=6, S_R1=7, S_R2=8, S_R3=9, S_Q0=10, S_Q1=11,
        S_M0=12, S_M1=13, S_M2=14, S_M3=15,
        S_F0=16, S_F1=17, S_F2=18, S_F3=19,
        S_C0=20, S_C1=21, S_C2=22, S_W41=23,
        S_B0=24, S_B1=25, S_B2=26, S_B3=27, S_B4=28, S_B5=29, S_B6=30,
        S_B7=31, S_B8=32, S_B9=33, S_B10=34, S_B11=35, S_W45=36,
        S_G0=37, S_G1=38, S_G2=39, S_G3=40, S_G4=41, S_G5=42, S_G6=43,
        S_G7=44, S_WV=45;

    reg [5:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_R2, S_R3, S_Q1, S_F2, S_F3, S_C0, S_C1, S_C2,
        S_B0, S_B1, S_B2, S_B3, S_B4, S_B5, S_B6, S_B7, S_B8, S_B9, S_B10, S_B11,
        S_G0, S_G1, S_G2, S_G3, S_G4, S_G5, S_G6, S_G7: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    // the latch passes take two clocks: the first stage, then the second
    // from the first's registered output (one stage per clock for timing)
    wire lat42 = st == S_L0 || st == S_L1 || st == S_L2 || st == S_L3;
    wire lat43 = st == S_M0 || st == S_M1 || st == S_M2 || st == S_M3;
    wire adv = !(mul_st || lat42 || lat43) || ph;

    // ---- state
    reg               o42_8h, o43_14h, o43_1h, o44_14h;  // comparators: output high
    reg signed [35:0] o42_14, o42_1, o43_7, o43_8;       // latch outputs
    reg signed [51:0] qr, qf, q55;                       // integrators, C55
    reg signed [51:0] qin41, qin45, q52, q50, q114, q58, q60;
    reg signed [35:0] p_con41, p_con45;
    // ---- step registers
    reg               resc_l, mute_l, dip_l;
    reg signed [35:0] ibk_l, saw_l;
    reg signed [35:0] env_r, env_f, vm, tin, qv, cs, c41, c45;
    reg signed [35:0] m41o, i41, m45o, i45;
    reg signed [35:0] e, ir, t7, o40_7, va, z, i424, o44_7, i410, im;
    reg               got41, got45, gotv;

    wire signed [35:0] qr_s   = qr[51:16];
    wire signed [35:0] qf_s   = qf[51:16];
    wire signed [35:0] q55_s  = q55[51:16];
    wire signed [35:0] q52_s  = q52[51:16];
    wire signed [35:0] q50_s  = q50[51:16];
    wire signed [35:0] q114_s = q114[51:16];
    wire signed [35:0] q58_s  = q58[51:16];
    wire signed [35:0] q60_s  = q60[51:16];
    wire signed [35:0] qin41_s = qin41[51:16];
    wire signed [35:0] qin45_s = qin45[51:16];

    function signed [35:0] lim;
        input signed [35:0] x;
        lim = x < D2_VOL ? D2_VOL : x > D2_VOH ? D2_VOH : x;
    endfunction
    // one inverting stage of a latch pair: + at r, 1K from the other output
    // o, 100K feedback: r + 100 (r - o), within the output limits
    function signed [35:0] lstage;
        input signed [35:0] r, o;
        reg signed [43:0] d, x;
        begin
            d = {{8{r[35]}}, r} - {{8{o[35]}}, o};
            x = {{8{r[35]}}, r} + (d <<< 6) + (d <<< 5) + (d <<< 2);
            lstage = x < D2_VOL ? D2_VOL : x > D2_VOH ? D2_VOH : x[35:0];
        end
    endfunction

    // latch + inputs and comparator thresholds
    wire signed [35:0] r12  = o42_8h  ? D2_R12_H : D2_R12_L;
    wire signed [35:0] r3   = resc_l  ? D2_R3_OFF : D2_R3_ON;
    wire signed [35:0] r5   = o43_1h  ? D2_R12_H : D2_R12_L;
    wire signed [35:0] r10  = o44_14h ? D2_R12_H : D2_R12_L;
    wire signed [35:0] la42 = lstage(r12, o42_1);
    wire signed [35:0] lb42 = lstage(r3, o42_14);   // after la42 is in o42_14
    wire signed [35:0] la43 = lstage(r5, o43_8);
    wire signed [35:0] lb43 = lstage(r10, o43_7);   // after la43 is in o43_7
    // integrators: output, and the - input (6 V unless the output is at a
    // limit)
    wire signed [35:0] vr   = D2_V6 + qr_s;
    wire signed [35:0] vf   = D2_V6 + qf_s;
    wire signed [35:0] vm_r = vr > D2_VOH ? D2_VOH - qr_s : vr < D2_VOL ? D2_VOL - qr_s : D2_V6;
    wire signed [35:0] vm_f = vf > D2_VOH ? D2_VOH - qf_s : vf < D2_VOL ? D2_VOL - qf_s : D2_V6;
    // node Q
    wire signed [35:0] q_raw = (o43_14h ? D2_VOH : D2_VOL) - q55_s;
    wire               q_cl  = q_raw < D2_QCLAMP;

    // ---- table ROM (the envelopes' steering): issue in one state, the two
    // entries two states later
    reg  [1:0]         tsel;          // D51, D82, D10, D220
    reg                tiss;
    reg  signed [35:0] tx;
    reg  [9:0]         ra;
    reg  [24:0]        fra, frb;
    reg  [4:0]         ffa, ffb;
    reg  signed [35:0] rq0, rq1;
    reg  [9:0]         t_base, t_n;
    reg  [4:0]         t_f;
    reg  signed [35:0] t_x0;
    always @* case (tsel)
        2'd0:    begin t_base=T_D51_BASE;  t_n=T_D51_N;  t_f=T_D51_F;  t_x0=T_D51_X0;  end
        2'd1:    begin t_base=T_D82_BASE;  t_n=T_D82_N;  t_f=T_D82_F;  t_x0=T_D82_X0;  end
        2'd2:    begin t_base=T_D10_BASE;  t_n=T_D10_N;  t_f=T_D10_F;  t_x0=T_D10_X0;  end
        default: begin t_base=T_D220_BASE; t_n=T_D220_N; t_f=T_D220_F; t_x0=T_D220_X0; end
    endcase
    wire signed [36:0] t_r   = {tx[35], tx} - {t_x0[35], t_x0};
    wire signed [36:0] t_i   = t_r >>> t_f;
    wire        [24:0] t_fr  = t_r[24:0] & ((25'd1 << t_f) - 25'd1);
    wire               t_neg = t_r[36];
    wire               t_top = !t_neg && t_i >= $signed({27'd0, t_n}) - 37'sd1;
    wire        [9:0]  t_idx = t_neg ? 10'd0 : t_top ? t_n - 10'd2 : t_i[9:0];
    wire        [24:0] t_frc = t_neg ? 25'd0 : t_top ? (25'd1 << t_f) : t_fr;
    wire        [9:0]  ra1   = ra + 10'd1;
    always @(posedge clk) if (adv) begin
        if (tiss) begin
            ra  <= t_base + t_idx;
            fra <= t_frc;
            ffa <= t_f;
        end
        rq0 <= rom_env[ra];
        rq1 <= rom_env[ra1];
        frb <= fra;
        ffb <= ffa;
    end

    // ---- the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
    reg  signed [35:0] ma;
    reg  signed [26:0] mb;
    reg         [5:0]  msh;
    wire signed [62:0] prod = ma * mb;
    reg  signed [62:0] prod_q;
    // the shift and its rounding term are registered with the product (a
    // state's shift is the same in both of its clocks), which keeps the
    // state decoding out of the second clock's path (timing)
    reg         [5:0]  msh_q;
    reg  signed [63:0] rnd_q;
    always @(posedge clk) begin
        prod_q <= prod;
        msh_q  <= msh;
        rnd_q  <= 64'sd1 <<< (msh - 6'd1);
    end
    wire signed [63:0] mrnd = {prod_q[62], prod_q} + rnd_q;
    wire signed [63:0] mres = mrnd >>> msh_q;
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres_v;

    // IC40 b and IC44 b before their limits
    wire signed [35:0] o40_7_raw = D2_V6 - t7 - mres_v;
    wire signed [35:0] o44_7_raw = D2_V6 - mres_v;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tiss = 1'b0; tsel = 2'd0; tx = 36'sd0;
        case (st)
            S_R0: begin tiss = 1'b1; tsel = 2'd0; tx = o42_1 - vm_r; end
            S_R1: begin tiss = 1'b1; tsel = 2'd1; tx = vm - o42_1; end
            S_R2, S_R3, S_F2, S_F3: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_Q1: begin ma = qv; mb = KQ55_M; msh = KQ55_S; end
            S_F0: begin tiss = 1'b1; tsel = 2'd2; tx = o43_7 - vm_f; end
            S_F1: begin tiss = 1'b1; tsel = 2'd3; tx = vm - o43_7; end
            S_C0: begin ma = env_r + env_f; mb = KCS_M; msh = KCS_S; end
            S_C1: begin ma = env_r; mb = KH_M; msh = KH_S; end
            S_C2: begin ma = env_f; mb = KH_M; msh = KH_S; end
            // rear output
            S_B0: begin ma = i41; mb = KC51_M; msh = KC51_S; end
            S_B1: begin ma = m41o - q52_s - D2_V6; mb = KR7_M; msh = KR7_S; end
            S_B2: begin ma = ibk_l; mb = KBK_M; msh = KBK_S; end
            S_B3: begin ma = e; mb = KVA_M; msh = KVA_S; end
            S_B4: begin ma = o40_7; mb = KVB_M; msh = KVB_S; end
            S_B5: begin ma = ibk_l; mb = KVC_M; msh = KVC_S; end
            S_B6: begin ma = ir; mb = K52_M; msh = K52_S; end
            S_B7: begin ma = o40_7 - q50_s; mb = mute_l ? KZ1M_M : KZ1_M; msh = mute_l ? KZ1M_S : KZ1_S; end
            S_B8: begin ma = q114_s + D2_V6; mb = mute_l ? KZ2M_M : KZ2_M; msh = mute_l ? KZ2M_S : KZ2_S; end
            S_B9: begin ma = o40_7 - q50_s - z; mb = K50_M; msh = K50_S; end
            S_B10: begin ma = i424; mb = K114_M; msh = K114_S; end
            S_B11: begin ma = z; mb = KPR_M; msh = KPR_S; end
            // front output
            S_G0: begin ma = i45; mb = KC59_M; msh = KC59_S; end
            S_G1: begin ma = e - D2_V6; mb = KF7_M; msh = KF7_S; end
            S_G2: begin ma = e; mb = KFA_M; msh = KFA_S; end
            S_G3: begin ma = o44_7; mb = KFB_M; msh = KFB_S; end
            S_G4: begin ma = e - vm; mb = K58_M; msh = K58_S; end
            S_G5: begin ma = o44_7 - q60_s - D2_V6; mb = K60_M; msh = K60_S; end
            S_G6: begin ma = i410; mb = K410_M; msh = K410_S; end
            S_G7: begin ma = i424; mb = K424_M; msh = K424_S; end
            default:;
        endcase
    end

    // ---- the shared MC3340: rear (IC41) then front (IC45)
    reg                mc_go, mc_sel;
    reg  signed [35:0] mc_in, mc_con;
    wire               mc_done;
    wire signed [35:0] mc_out, mc_iin;
    jtmonacogp_snd_mc3340 u_mc(
        .clk(clk), .rst(rst), .start(mc_go), .mcin(mc_in), .con(mc_con),
        .mco(mc_out), .iin(mc_iin), .done(mc_done));

    // ---- the siren tone
    wire vco_done;
    jtmonacogp_snd_d2vco u_vco(
        .clk(clk), .rst(rst), .start(start && st == S_IDLE), .saw(v_saw), .done(vco_done),
        .o40_1(v_o40_1), .v_o555(v_o555));

    always @(posedge clk) begin
        done  <= 1'b0;
        mc_go <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            o42_8h <= 1'b0; o43_14h <= 1'b0; o43_1h <= 1'b0; o44_14h <= 1'b0;
            // the symmetric latches power up as the reference's do
            o42_14 <= D2_VOH; o42_1 <= D2_VOL; o43_7 <= D2_VOL; o43_8 <= D2_VOH;
            qr <= 52'sd0; qf <= 52'sd0; q55 <= 52'sd0;
            qin41 <= 52'sd0; qin45 <= 52'sd0; q52 <= 52'sd0; q50 <= 52'sd0;
            q114 <= 52'sd0; q58 <= 52'sd0; q60 <= 52'sd0;
            p_con41 <= 36'sd0; p_con45 <= 36'sd0;
            mc_sel <= 1'b0; got41 <= 1'b0; got45 <= 1'b0; gotv <= 1'b0;
            i_mix <= 36'sd0; padr <= 36'sd0;
            {v_env_r, v_env_f, v_con41, v_con45, v_mc41o, v_mc45o, v_o40_7, v_z, v_o44_7} <= 0;
            {v_o42_1, v_o43_7, v_i410, v_i424} <= 0;
            {v_o42_8, v_o43_14, v_o43_1, v_o44_14} <= 4'd0;
        end else begin
            // the MC3340 runs beside the step: rear, then front at once
            if (mc_done) begin
                if (!mc_sel) begin
                    m41o <= mc_out; i41 <= mc_iin; got41 <= 1'b1;
                    mc_in <= saw_l - qin45_s; mc_con <= p_con45; mc_sel <= 1'b1; mc_go <= 1'b1;
                end else begin
                    m45o <= mc_out; i45 <= mc_iin; got45 <= 1'b1;
                end
            end
            if (vco_done) gotv <= 1'b1;
            if (!adv) begin
                ph <= 1'b1;
                if (lat42) o42_14 <= la42;
                if (lat43) o43_7  <= la43;
            end else begin
                ph <= 1'b0;
                case (st)
                    S_IDLE: if (start) begin
                        resc_l <= resc; mute_l <= mute; dip_l <= dip_back; ibk_l <= i_bk;
                        saw_l  <= v_saw;
                        mc_in  <= v_saw - qin41_s; mc_con <= p_con41; mc_sel <= 1'b0; mc_go <= 1'b1;
                        got41 <= 1'b0; got45 <= 1'b0; gotv <= 1'b0;
                        st <= S_E0;
                    end
                    // ---- rear envelope: comparators on it, the IC42 latch
                    S_E0: begin
                        env_r   <= lim(vr);
                        o42_8h  <= (o42_8h  ? D2_TH42_H : D2_TH42_L) - lim(vr) > 0;
                        o43_14h <= (o43_14h ? D2_TH43_H : D2_TH43_L) - lim(vr) > 0;
                        st <= S_L0;
                    end
                    S_L0, S_L1, S_L2, S_L3: begin
                        o42_1 <= lb42;
                        st <= st == S_L3 ? S_R0 : st + 6'd1;
                    end
                    S_R0: begin vm <= vm_r; st <= S_R1; end
                    S_R1: st <= S_R2;
                    S_R2: begin tin <= tval; st <= S_R3; end
                    S_R3: begin qr <= qr - (tin - tval); st <= S_Q0; end
                    // ---- node Q and the IC43 Schmitt
                    S_Q0: begin
                        qv <= q_cl ? D2_QCLAMP : q_raw;
                        if (q_cl) q55 <= ((o43_14h ? D2_VOH : D2_VOL) - D2_QCLAMP) <<< 16;
                        st <= S_Q1;
                    end
                    S_Q1: begin
                        q55    <= q55 + mres_s - (o43_1h ? D2_Q55O_H : D2_Q55O_L);
                        o43_1h <= qv > (o43_1h ? D2_QTH_H : D2_QTH_L);
                        st <= S_M0;
                    end
                    // ---- the IC43 latch, the front envelope and IC44 d
                    S_M0, S_M1, S_M2, S_M3: begin
                        o43_8 <= lb43;
                        st <= st == S_M3 ? S_F0 : st + 6'd1;
                    end
                    S_F0: begin
                        env_f   <= lim(vf);
                        o44_14h <= (o44_14h ? D2_TH44_H : D2_TH44_L) - lim(vf) > 0;
                        vm <= vm_f;
                        st <= S_F1;
                    end
                    S_F1: st <= S_F2;
                    S_F2: begin tin <= tval; st <= S_F3; end
                    S_F3: begin qf <= qf - (tin - tval); st <= S_C0; end
                    // ---- the CONTROLs
                    S_C0: begin cs <= mres_v; st <= S_C1; end
                    S_C1: begin c41 <= lim(D2_CON0 + cs + mres_v); st <= S_C2; end
                    S_C2: begin c45 <= lim(D2_CON0 + cs + mres_v); st <= S_W41; end
                    S_W41: if (got41) st <= S_B0;
                    // ---- rear output: IC40 b, node Z
                    S_B0: begin qin41 <= qin41 + mres_s; e <= m41o - q52_s; st <= S_B1; end
                    S_B1: begin t7 <= mres_v; ir <= e - D2_V6; st <= S_B2; end
                    S_B2: begin
                        if (o40_7_raw > D2_VOH || o40_7_raw < D2_VOL) begin
                            o40_7 <= lim(o40_7_raw); st <= S_B3;
                        end else begin
                            o40_7 <= o40_7_raw; st <= S_B6;
                        end
                    end
                    S_B3: begin va <= mres_v; st <= S_B4; end
                    S_B4: begin va <= va + mres_v; st <= S_B5; end
                    S_B5: begin ir <= e - (va + mres_v); st <= S_B6; end
                    S_B6: begin q52 <= q52 + mres_s; st <= S_B7; end
                    S_B7: begin z <= mres_v; st <= S_B8; end
                    S_B8: begin z <= z + mres_v; st <= S_B9; end
                    S_B9: begin
                        q50  <= q50 + mres_s;
                        i424 <= dip_l ? z - q114_s - D2_V6 : 36'sd0;
                        st <= S_B10;
                    end
                    S_B10: begin q114 <= q114 + mres_s; st <= S_B11; end
                    S_B11: begin padr <= mres_v; st <= S_W45; end
                    S_W45: if (got45) st <= S_G0;
                    // ---- front output: IC44 b
                    S_G0: begin qin45 <= qin45 + mres_s; e <= m45o - q58_s; st <= S_G1; end
                    S_G1: begin
                        if (o44_7_raw > D2_VOH || o44_7_raw < D2_VOL) begin
                            o44_7 <= lim(o44_7_raw); st <= S_G2;
                        end else begin
                            o44_7 <= o44_7_raw; vm <= D2_V6; st <= S_G4;
                        end
                    end
                    S_G2: begin va <= mres_v; st <= S_G3; end
                    S_G3: begin vm <= va + mres_v; st <= S_G4; end
                    S_G4: begin q58 <= q58 + mres_s; i410 <= o44_7 - q60_s - D2_V6; st <= S_G5; end
                    S_G5: begin q60 <= q60 + mres_s; st <= S_G6; end
                    S_G6: begin im <= mres_v; st <= S_G7; end
                    S_G7: begin i_mix <= im + mres_v; st <= S_WV; end
                    S_WV: if (gotv || vco_done) begin
                        p_con41 <= c41; p_con45 <= c45;
                        v_env_r <= env_r; v_env_f <= env_f; v_con41 <= c41; v_con45 <= c45;
                        v_mc41o <= m41o; v_mc45o <= m45o; v_o40_7 <= o40_7; v_z <= z;
                        v_o44_7 <= o44_7; v_o42_1 <= o42_1; v_o43_7 <= o43_7;
                        v_i410 <= i410; v_i424 <= i424;
                        v_o42_8 <= o42_8h; v_o43_14 <= o43_14h; v_o43_1 <= o43_1h; v_o44_14 <= o44_14h;
                        done <= 1'b1;
                        st <= S_IDLE;
                    end
                    default: st <= S_IDLE;
                endcase
            end
        end
    end
endmodule
