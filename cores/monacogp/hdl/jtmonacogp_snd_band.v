// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-4/7 of board 96598-P: one band of the explosion
// (docs/trace/SOUND_D4_TRACE.md; docs/SOUND_LOGIC.md). Two instances:
//   UPPER=1  IC63 b band-pass (R395 4.7K, R396 27K, C95/C96 0.01u, R391 220K,
//            about 540 Hz), IC61 a's envelope (D30, C77 10u, R374 330K),
//            IC66 d / IC66 c, MC3340 IC65
//   UPPER=0  IC63 a band-pass (R388 4.7K, R389 8.2K, C90/C91 0.047u, R387
//            220K, about 130 Hz), IC61 b's envelope (D31, C78 10u, R375 1M),
//            IC64 d / IC64 c, MC3340 IC71
// Each: the noise amplifier's output through C93 / C92 4.7u into the
// band-pass; the 74123 output `q` through its 330 ohm pull-up and diode into
// the envelope capacitor; the MC3340's control 7.74 V less the envelope; its
// input through C82 / C98 1u and R397 / R398 33K. The MC3340 output (`mco`,
// unloaded) goes to IC66 a (jtmonacogp_snd_expl.v), which also keeps its
// output capacitor. The MC3340 model is D-3's (jtmonacogp_snd_d3.v), with
// the input tables scaled for the 33K source.
// Same step and arithmetic as jtmonacogp_snd_d3.v; tests/sound/d4s_fixed.py
// (BandFixed) is the same in Python and generates jtmonacogp_snd_band.vh.
module jtmonacogp_snd_band #(parameter UPPER = 1)(
    input                    clk,
    input                    rst,      // power-on: every capacitor at 0 V
    input                    go,       // one model step; vsrc and q held
    input  signed     [35:0] vsrc,     // the noise amplifier's output
    input                    q,        // the 74123 output
    output reg signed [35:0] mco,      // MC3340 output, unloaded
    output reg               done,
    // test views, updated once per step
    output reg signed [35:0] v_bp, v_env, v_con, v_mcin
);
    `include "jtmonacogp_snd_band.vh"

    localparam signed [26:0] KIN_M  = UPPER ? KIN_U_M  : KIN_L_M;
    localparam        [5:0]  KIN_S  = UPPER ? KIN_U_S  : KIN_L_S;
    localparam signed [26:0] K1_M   = UPPER ? K1_U_M   : K1_L_M;
    localparam        [5:0]  K1_S   = UPPER ? K1_U_S   : K1_L_S;
    localparam signed [26:0] K2A_M  = UPPER ? K2A_U_M  : K2A_L_M;
    localparam        [5:0]  K2A_S  = UPPER ? K2A_U_S  : K2A_L_S;
    localparam signed [26:0] K2B_M  = UPPER ? K2B_U_M  : K2B_L_M;
    localparam        [5:0]  K2B_S  = UPPER ? K2B_U_S  : K2B_L_S;
    localparam signed [26:0] K2C_M  = UPPER ? K2C_U_M  : K2C_L_M;
    localparam        [5:0]  K2C_S  = UPPER ? K2C_U_S  : K2C_L_S;
    localparam signed [26:0] KENV_M = UPPER ? KENV_U_M : KENV_L_M;
    localparam        [5:0]  KENV_S = UPPER ? KENV_U_S : KENV_L_S;

    localparam [4:0]
        S_IDLE=0, S_B0=1,  S_B1=2,  S_B2=3,  S_B3=4,  S_B4=5,  S_B5=6,  S_B6=7,
        S_B7=8,   S_B8=9,  S_B9=10, S_B10=11, S_B11=12, S_B12=13, S_B13=14,
        S_B14=15, S_B15=16, S_B16=17, S_B17=18, S_B18=19, S_B19=20, S_B20=21,
        S_B21=22, S_B22=23, S_B23=24, S_B24=25, S_B25=26, S_B26=27;
    localparam [3:0]
        T_NONE=0, TDQ=1, TG=2, TVO0=3, TLO=4, TVON=5, TVONW=6, TH=7, TIB=8,
        TW=9, TIC=10, TS=11;

    reg [4:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_B1, S_B2, S_B3, S_B4, S_B5, S_B6, S_B8, S_B9, S_B12, S_B13, S_B14,
        S_B15, S_B16, S_B17, S_B18, S_B19, S_B20, S_B21, S_B22, S_B24, S_B25,
        S_B26: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction

    // ---- state
    reg signed [51:0] qin, q1, q2, env, qmc;
    reg signed [35:0] inl;
    // ---- step registers
    reg signed [35:0] vo, vx, vm, e, mcin, con;
    reg signed [35:0] g, vo0, lo, von, vonw, h, ib, w, ic, heff, xs;
    reg signed [51:0] d2, de;
    reg               ic_ext, s_ext;

    wire signed [35:0] qin_s = qin[51:16];
    wire signed [35:0] q1_s  = q1[51:16];
    wire signed [35:0] q2_s  = q2[51:16];
    wire signed [35:0] env_s = env[51:16];
    wire signed [35:0] qmc_s = qmc[51:16];
    wire signed [35:0] vo_r  = V6 + q1_s - q2_s;
    wire signed [35:0] vo_c  = clamp(vo_r, VOL, VOH);
    wire signed [35:0] u     = mcin - von;
    wire signed [35:0] iin   = ib + ic;

    // ---- table ROM (as jtmonacogp_snd_d3.v)
    reg  [3:0]         tsel;
    reg  signed [35:0] tx;
    reg  [11:0]        ra;
    reg  [24:0]        fra, frb;
    reg  [4:0]         ffa, ffb;
    reg  signed [35:0] rq0, rq1;
    reg  [11:0]        t_base, t_n;
    reg  [4:0]         t_f;
    reg  signed [35:0] t_x0;
    always @* begin
        case (tsel)
            TDQ:    begin t_base=T_DQ_BASE;   t_n=T_DQ_N;   t_f=T_DQ_F;   t_x0=T_DQ_X0;   end
            TG:     begin t_base=T_G_BASE;    t_n=T_G_N;    t_f=T_G_F;    t_x0=T_G_X0;    end
            TVO0:   begin t_base=T_VO0_BASE;  t_n=T_VO0_N;  t_f=T_VO0_F;  t_x0=T_VO0_X0;  end
            TLO:    begin t_base=T_LO_BASE;   t_n=T_LO_N;   t_f=T_LO_F;   t_x0=T_LO_X0;   end
            TVON:   begin t_base=T_VON_BASE;  t_n=T_VON_N;  t_f=T_VON_F;  t_x0=T_VON_X0;  end
            TVONW:  begin t_base=T_VONW_BASE; t_n=T_VONW_N; t_f=T_VONW_F; t_x0=T_VONW_X0; end
            TH:     begin t_base=T_H_BASE;    t_n=T_H_N;    t_f=T_H_F;    t_x0=T_H_X0;    end
            TIB:    begin t_base=T_IB_BASE;   t_n=T_IB_N;   t_f=T_IB_F;   t_x0=T_IB_X0;   end
            TW:     begin t_base=T_W_BASE;    t_n=T_W_N;    t_f=T_W_F;    t_x0=T_W_X0;    end
            TIC:    begin t_base=T_IC_BASE;   t_n=T_IC_N;   t_f=T_IC_F;   t_x0=T_IC_X0;   end
            default:begin t_base=T_S_BASE;    t_n=T_S_N;    t_f=T_S_F;    t_x0=T_S_X0;    end
        endcase
    end
    wire signed [36:0] t_r   = {tx[35], tx} - {t_x0[35], t_x0};
    wire signed [36:0] t_i   = t_r >>> t_f;
    wire        [24:0] t_fr  = t_r[24:0] & ((25'd1 << t_f) - 25'd1);
    wire               t_neg = t_r[36];
    wire               t_top = !t_neg && t_i >= $signed({25'd0, t_n}) - 37'sd1;
    wire        [11:0] t_idx = t_neg ? 12'd0 : t_top ? t_n - 12'd2 : t_i[11:0];
    wire        [24:0] t_frc = t_neg ? 25'd0 : t_top ? (25'd1 << t_f) : t_fr;
    wire        [11:0] ra1   = ra + 12'd1;
    always @(posedge clk) if (adv) begin
        if (tsel != T_NONE) begin
            ra  <= t_base + t_idx;
            fra <= t_frc;
            ffa <= t_f;
        end
        rq0 <= rom[ra];
        rq1 <= rom[ra1];
        frb <= fra;
        ffb <= ffa;
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
    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres[35:0];
    // the envelope's control: 7.74 V less the follower's output
    wire signed [35:0] con_n = clamp(VB2 - clamp(env_s, VOL_FOL, VOH), VOL, VOH);

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tsel = T_NONE; tx = 36'sd0;
        case (st)
            S_B1:  begin ma = e;        mb = KIN_M;  msh = KIN_S;  end
            S_B2:  begin ma = vm - vo;  mb = K1_M;   msh = K1_S;   end
            S_B3:  begin ma = e;        mb = K2A_M;  msh = K2A_S;  end
            S_B4:  begin ma = vx;       mb = K2B_M;  msh = K2B_S;  end
            S_B5:  begin ma = vm - vo;  mb = K2C_M;  msh = K2C_S;  end
            S_B6:  begin ma = env_s;    mb = KENV_M; msh = KENV_S;
                         tsel = TDQ; tx = VCC - env_s; end
            S_B8:  begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B9:  begin ma = vo - qmc_s; mb = KMS_M; msh = KMS_S; end
            S_B10: begin tsel = TG;   tx = con; end
            S_B11: begin tsel = TVO0; tx = con; end
            S_B12: begin tsel = TLO;  tx = con;  ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B13: begin tsel = TVON; tx = con;  ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B14: begin tsel = TVONW; tx = con; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B15: begin tsel = TH;   tx = mcin; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B16: begin tsel = TIB;  tx = mcin; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B17: begin tsel = TW;   tx = mcin - vonw; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B18: begin tsel = TIC;  tx = u;    ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B19: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B20: if (ic_ext) begin ma = u - U_MAX; mb = KICS_M; msh = KICS_S; end
                   else begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B21: begin ma = H_LOW - h; mb = w[29:3]; msh = 6'd25; end
            S_B22: begin ma = heff; mb = g[29:3]; msh = 6'd25; end
            S_B23: begin tsel = TS; tx = xs; end
            S_B24: begin ma = mcin - MC_VB; mb = KTH_M; msh = KTH_S; end
            S_B25: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B26: begin ma = iin; mb = KQ_M; msh = KQ_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            qin <= 52'sd0; q1 <= 52'sd0; q2 <= 52'sd0; env <= 52'sd0; qmc <= 52'sd0;
            inl <= 36'sd0; mco <= 36'sd0;
            {v_bp, v_env, v_con, v_mcin} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (go) st <= S_B0;
                // band-pass: the output, the X node and the - input, with
                // the virtual ground let go while the output is limited
                S_B0: begin
                    vo <= vo_c;
                    if (vo_r >= VOL && vo_r <= VOH) begin
                        vm <= V6; vx <= V6 + q1_s;
                        e  <= vsrc - qin_s - (V6 + q1_s);
                    end else begin
                        vx <= vo_c + q2_s; vm <= vo_c + q2_s - q1_s;
                        e  <= vsrc - qin_s - (vo_c + q2_s);
                    end
                    st <= S_B1;
                end
                S_B1: begin qin <= qin + mres_s; st <= S_B2; end
                S_B2: begin q1 <= q1 + mres_s; st <= S_B3; end
                S_B3: begin d2 <= mres_s; st <= S_B4; end
                S_B4: begin d2 <= d2 - mres_s; st <= S_B5; end
                S_B5: begin q2 <= q2 + d2 - mres_s; st <= S_B6; end
                // envelope
                S_B6: begin de <= -mres_s; st <= S_B7; end
                S_B7: st <= S_B8;
                S_B8: begin
                    env <= env + de + (q ? {{12{tval[35]}}, tval, 4'd0} : 52'sd0);
                    st <= S_B9;
                end
                // MC3340 input (the source is this step's band-pass output)
                S_B9:  begin mcin <= mres_v + MC_C0 - inl; con <= con_n; st <= S_B10; end
                S_B10: st <= S_B11;
                S_B11: st <= S_B12;
                S_B12: begin g    <= tval; st <= S_B13; end
                S_B13: begin vo0  <= tval; st <= S_B14; end
                S_B14: begin lo   <= tval; st <= S_B15; end
                S_B15: begin von  <= tval; st <= S_B16; end
                S_B16: begin vonw <= tval; st <= S_B17; end
                S_B17: begin h    <= tval; st <= S_B18; end
                S_B18: begin ib   <= tval; ic_ext <= u > U_MAX; st <= S_B19; end
                S_B19: begin w    <= tval; st <= S_B20; end
                S_B20: begin ic   <= ic_ext ? IC_LAST + mres_v : tval; st <= S_B21; end
                S_B21: begin heff <= h + mres_v; st <= S_B22; end
                S_B22: begin xs   <= vo0 - mres_v - lo; st <= S_B23; end
                S_B23: begin s_ext <= xs >= S_MAX; st <= S_B24; end
                S_B24: begin inl  <= iin - mres_v; st <= S_B25; end
                S_B25: begin
                    mco <= lo + (s_ext ? xs : tval) > MC_HI ? MC_HI : lo + (s_ext ? xs : tval);
                    st <= S_B26;
                end
                S_B26: begin
                    qmc <= qmc + mres_s; done <= 1'b1;
                    v_bp <= vo; v_env <= env_s; v_con <= con; v_mcin <= mcin;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
