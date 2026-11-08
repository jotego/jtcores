// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-3/7 of board 96598-P: MY CAR SOUND, the engine
// (docs/trace/SOUND_D3_TRACE.md; model and its checks: docs/SOUND_LOGIC.md).
//
// The analog circuit is stepped once per `tick` (480 kHz) as a set of
// difference equations, in fixed point: signals 2^28 per volt (36 bits),
// capacitor voltages 2^44 per volt (52 bits). One shared multiplier
// (36 x 27 bits, product rounded and shifted) and one table ROM (two
// neighbouring entries read at once, linear interpolation) serve the whole
// step. A state that uses the multiplier takes two clocks (the product is
// registered between them, for timing at 48 MHz), the others one: about 85
// clocks a step. The table pipeline advances once per state. tests/sound/d3_fixed.py is the
// same arithmetic in Python, operation for operation, and generates the
// constants and tables (jtmonacogp_snd_d3.vh) from the floating-point model
// tests/sound/d3_model.py, which is checked against a pin-wired SPICE
// reference of the sheet.
//
// - DAC: S-ACCE A..D (pads E, 5, F, 6) through open-collector buffers into
//   390K / 220K / 100K / 51K with R298; follower IC49 c.
// - Lag C62 47u: R300 150K; R302 68K through IC54 11-10 while S-ACCE D is
//   low; D21 + R299 33K back to the follower when the DAC falls.
// - IC50 d follower, R303 220K / R301 470K to the SHIFT inverter (sinking
//   while SHIFT A is high), IC50 c follower: CV.
// - Three integrator / Schmitt-comparator cells (IC51, IC50, IC49 a/b with
//   TR18, a C458, TR16) whose rate is set by CV.
// - IC51 c: twice V10 (CV through R305, clamped by D27/D28 to 3.92 V) less
//   cell 1 through C66 22u / R304: the MC3340's control (AM at cell 1's rate).
// - Cells 2 and 3 through D24 / D22 into R325 10K and C64 10u to the MC3340
//   (IC52) input; IC52 out through IC54 4-3 (on while MY CAR SOUND ON is
//   high), R356 / R355 51K and C72 22u to the mixer (R411 100K to its 6 V
//   virtual ground on D-4).
// Output: i_mix, the current in R411 times 100K (2^28 per volt).
module jtmonacogp_snd_d3(
    input                    clk,
    input                    rst,      // power-on: every capacitor at 0 V
    input                    tick,     // one model step
    input              [3:0] acc,      // S-ACCE D, C, B, A (pad high = 1)
    input                    shift_a,  // SHIFT A, high = shifted (lower CV)
    input                    sound_on, // MY CAR SOUND ON
    output reg signed [35:0] i_mix,
    output reg               done,     // one clock when i_mix has been updated
    // test views, updated once per step
    output reg signed [35:0] v_lag, v_cv, v_o1, v_o2, v_o3, v_c1, v_c2, v_c3,
    output reg signed [35:0] v_con, v_mcin, v_mco
);
    `include "jtmonacogp_snd_d3.vh"

    localparam [5:0]
        S_IDLE=0,  S_LAG0=1,  S_LAG1=2,  S_LAG2=3,  S_CV=4,
        S_C0=5,    S_C1=6,    S_C2=7,    S_C3=8,
        S_V0=9,    S_V1=10,   S_V2=11,   S_M1=12,   S_M2=13,  S_M3=14,
        S_M4=15,   S_M5=16,   S_M6=17,   S_M7=18,   S_M8=19,  S_M9=20,
        S_B1=21,   S_B2=22,   S_B3=23,   S_B4=24,
        S_N0=25,   S_N1=26,   S_N2=27,   S_N3=28,   S_N4=29,  S_N5=30,
        S_N6=31,   S_N7=32,   S_N8=33,   S_N9=34,   S_N10=35, S_N11=36,
        S_O0=37,   S_O1=38,   S_O2=39,   S_O3=40;
    localparam [3:0]
        T_NONE=0, TD21=1, TV10=2, TSOFT=3, TVDROP=4, TG=5, TVO0=6, TLO=7,
        TVON=8, TVONW=9, TH=10, TIB=11, TW=12, TIC=13, TS=14;

    reg [5:0] st;
    reg [1:0] ci;                     // cell 0..2 while in S_C0..S_C3
    reg       ph;                     // second clock of a multiplier state

    // states whose action uses the multiplier's result
    reg mul_st;
    always @* case (st)
        S_LAG0, S_LAG1, S_LAG2, S_CV, S_C0, S_C1, S_C2, S_V1, S_V2, S_M2,
        S_M4, S_M5, S_M6, S_M7, S_M8, S_M9, S_B3, S_N2, S_N3, S_N4, S_N5,
        S_N6, S_N7, S_N9, S_N10, S_N11, S_O0, S_O1, S_O3: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;         // the state's last clock

    // ---- state
    reg signed [51:0] lag, q66, q64, q72;
    reg signed [51:0] cap[0:2];
    reg signed [35:0] cmp[0:2];
    reg        [2:0]  tr;
    reg signed [35:0] inl;

    // ---- step registers
    reg signed [51:0] dl;
    reg signed [35:0] cv, v10, c66r, con, vth, top, hi_v, dneg, vdv, bus, mcin;
    reg signed [35:0] g, vo0, lo, von, vonw, h, ib, w, ic, heff, xs, mco, msum, swo_a, i72v;
    reg signed [35:0] vout, vplus, o1, o2, o3;
    reg               con_sat, vneg, ic_ext, s_ext;

    wire signed [35:0] f8    = dac_level(acc);
    wire signed [35:0] lag_s = lag[51:16];
    wire signed [35:0] q66_s = q66[51:16];
    wire signed [35:0] q64_s = q64[51:16];
    wire signed [35:0] q72_s = q72[51:16];
    wire signed [35:0] vm    = cv >>> 1;

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction

    // ---- table ROM: issue (address, fraction) in one state, the two
    // entries arrive two states later
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
            TD21:   begin t_base=T_D21_BASE;   t_n=T_D21_N;   t_f=T_D21_F;   t_x0=T_D21_X0;   end
            TV10:   begin t_base=T_V10_BASE;   t_n=T_V10_N;   t_f=T_V10_F;   t_x0=T_V10_X0;   end
            TSOFT:  begin t_base=T_SOFT_BASE;  t_n=T_SOFT_N;  t_f=T_SOFT_F;  t_x0=T_SOFT_X0;  end
            TVDROP: begin t_base=T_VDROP_BASE; t_n=T_VDROP_N; t_f=T_VDROP_F; t_x0=T_VDROP_X0; end
            TG:     begin t_base=T_G_BASE;     t_n=T_G_N;     t_f=T_G_F;     t_x0=T_G_X0;     end
            TVO0:   begin t_base=T_VO0_BASE;   t_n=T_VO0_N;   t_f=T_VO0_F;   t_x0=T_VO0_X0;   end
            TLO:    begin t_base=T_LO_BASE;    t_n=T_LO_N;    t_f=T_LO_F;    t_x0=T_LO_X0;    end
            TVON:   begin t_base=T_VON_BASE;   t_n=T_VON_N;   t_f=T_VON_F;   t_x0=T_VON_X0;   end
            TVONW:  begin t_base=T_VONW_BASE;  t_n=T_VONW_N;  t_f=T_VONW_F;  t_x0=T_VONW_X0;  end
            TH:     begin t_base=T_H_BASE;     t_n=T_H_N;     t_f=T_H_F;     t_x0=T_H_X0;     end
            TIB:    begin t_base=T_IB_BASE;    t_n=T_IB_N;    t_f=T_IB_F;    t_x0=T_IB_X0;    end
            TW:     begin t_base=T_W_BASE;     t_n=T_W_N;     t_f=T_W_F;     t_x0=T_W_X0;     end
            TIC:    begin t_base=T_IC_BASE;    t_n=T_IC_N;    t_f=T_IC_F;    t_x0=T_IC_X0;    end
            default:begin t_base=T_S_BASE;     t_n=T_S_N;     t_f=T_S_F;     t_x0=T_S_X0;     end
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

    // ---- the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
    reg  signed [35:0] ma;
    reg  signed [26:0] mb;
    reg         [5:0]  msh;
    wire signed [62:0] prod = ma * mb;
    reg  signed [62:0] prod_q;
    // the shift is registered with the product: every state that uses mres
    // takes two clocks with the same operands, so msh_q equals msh there,
    // and the state decode stays out of the shifter's path (timing)
    reg         [5:0]  msh_q;
    always @(posedge clk) begin prod_q <= prod; msh_q <= msh; end
    wire signed [63:0] mrnd = {prod_q[62], prod_q} + (64'sd1 <<< (msh_q - 6'd1));
    wire signed [63:0] mres = mrnd >>> msh_q;
    // interpolation of the entries that arrive in this state
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres[35:0];

    // cell constants
    reg signed [26:0] ka_m, kb_m;
    reg        [5:0]  ka_s, kb_s;
    always @* begin
        case (ci)
            2'd0:    begin ka_m=KA1_M; ka_s=KA1_S; kb_m=KB1_M; kb_s=KB1_S; end
            2'd1:    begin ka_m=KA2_M; ka_s=KA2_S; kb_m=KB2_M; kb_s=KB2_S; end
            default: begin ka_m=KA3_M; ka_s=KA3_S; kb_m=KB3_M; kb_s=KB3_S; end
        endcase
    end
    wire signed [35:0] cmp_c  = cmp[ci];
    wire signed [35:0] vo_c   = clamp(cmp_c, VOL_C, VOH_C);
    wire signed [35:0] vout_r = vm - cap[ci][51:16];
    // comparator internal node: slews toward the decision, up to CMP_OVER
    // beyond the output limits
    wire signed [35:0] cmp_up = cmp_c + SLEW > VOH_C + CMP_OVER ? VOH_C + CMP_OVER : cmp_c + SLEW;
    wire signed [35:0] cmp_dn = cmp_c - SLEW < VOL_C - CMP_OVER ? VOL_C - CMP_OVER : cmp_c - SLEW;
    wire signed [35:0] cmp_n  = vplus > vout ? cmp_up : cmp_dn;

    // values combined in the states that use them
    wire signed [35:0] con_raw = (v10 <<< 1) - c66r;
    wire signed [35:0] vdiff   = top - vth;
    wire signed [35:0] u       = mcin - von;
    wire signed [35:0] iin     = ib + ic;

    // ---- per-state multiplier operands and table issues
    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tsel = T_NONE; tx = 36'sd0;
        case (st)
            S_LAG0: begin ma = f8 - lag_s; mb = K300_M; msh = K300_S;
                          tsel = TD21; tx = lag_s - f8; end
            S_LAG1: begin ma = f8 - lag_s; mb = K302_M; msh = K302_S; end
            S_LAG2: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_CV:   begin ma = clamp(lag_s, VOL, VOH); mb = KSHIFT_M; msh = KSHIFT_S; end
            S_C0:   begin ma = cv - vm; mb = ka_m; msh = ka_s; end
            S_C1:   begin ma = vm - VCE; mb = kb_m; msh = kb_s; end
            S_C2:   begin ma = vo_c; mb = KSCH_M; msh = KSCH_S; end
            S_V0:   begin tsel = TV10; tx = cv; end
            S_V1:   begin ma = q64_s + MC_VB; mb = KTH_M; msh = KTH_S; end
            S_V2:   begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_M2:   begin ma = con_sat ? c66r - con : c66r - v10;
                          mb = con_sat ? K66B_M : K66_M; msh = con_sat ? K66B_S : K66_S;
                          tsel = TG; tx = con; end
            S_M3:   begin tsel = TVO0; tx = con; end
            S_M4:   begin tsel = TLO;  tx = con; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_M5:   begin tsel = TVON; tx = con; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_M6:   begin tsel = TVONW; tx = con; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_M7:   begin tsel = TSOFT; tx = -dneg; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_M8,
            S_M9:   begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B1:   begin tsel = TVDROP; tx = vdiff; end
            S_B3:   begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N0:   begin tsel = TH;  tx = mcin; end
            S_N1:   begin tsel = TIB; tx = mcin; end
            S_N2:   begin tsel = TW;  tx = mcin - vonw; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N3:   begin tsel = TIC; tx = u; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N4:   begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N5:   if (ic_ext) begin ma = u - U_MAX; mb = KICS_M; msh = KICS_S; end
                    else begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N6:   begin ma = H_LOW - h; mb = w[29:3]; msh = 6'd25; end
            S_N7:   begin ma = heff; mb = g[29:3]; msh = 6'd25; end
            S_N8:   begin tsel = TS; tx = xs; end
            S_N9:   begin ma = mcin - MC_VB; mb = KTH_M; msh = KTH_S; end
            S_N10:  begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_N11:  begin ma = iin; mb = K64_M; msh = K64_S; end
            S_O0:   begin ma = mco; mb = KOA_ON_M; msh = KOA_ON_S; end
            S_O1:   begin ma = q72_s; mb = sound_on ? KOB_ON_M : KOB_OFF_M;
                          msh = sound_on ? KOB_ON_S : KOB_OFF_S; end
            S_O3:   begin ma = i72v; mb = K72_M; msh = K72_S; end
            default:;
        endcase
    end

    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] mres_v = mres[35:0];

    integer k;
    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ci <= 2'd0; ph <= 1'b0;
            lag <= 52'sd0; q66 <= 52'sd0; q64 <= 52'sd0; q72 <= 52'sd0;
            for (k = 0; k < 3; k = k + 1) begin
                cap[k] <= 52'sd0;
                cmp[k] <= VOL_C - CMP_OVER;
            end
            tr <= 3'd0; inl <= 36'sd0; i_mix <= 36'sd0;
            {v_lag, v_cv, v_o1, v_o2, v_o3, v_c1, v_c2, v_c3, v_con, v_mcin, v_mco} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;               // the product is registered: act next clock
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (tick) st <= S_LAG0;
                // lag
                S_LAG0: begin dl <= mres_s; st <= S_LAG1; end
                S_LAG1: begin if (!acc[3]) dl <= dl + mres_s; st <= S_LAG2; end
                S_LAG2: begin
                    lag <= lag + dl - (lag_s > f8 ? {{16{tval[35]}}, tval} : 52'sd0);
                    st <= S_CV;
                end
                // CV
                S_CV: begin
                    cv   <= clamp(shift_a ? mres_v : clamp(lag_s, VOL, VOH), VOL, CV_MAX);
                    ci <= 2'd0;
                    st   <= S_C0;
                end
                // cells: the capacitor, then the output and its limits,
                // then the comparator
                S_C0: begin dl <= mres_s; st <= S_C1; end
                S_C1: begin
                    cap[ci] <= cap[ci] + dl - (tr[ci] ? mres_s : 52'sd0);
                    st <= S_C2;
                end
                S_C2: begin
                    vplus <= SCH0 + mres_v;
                    if (vout_r > VOH) begin
                        vout <= VOH; cap[ci] <= {vm - VOH, 16'd0};
                    end else if (vout_r < VOL) begin
                        vout <= VOL; cap[ci] <= {vm - VOL, 16'd0};
                    end else vout <= vout_r;
                    st <= S_C3;
                end
                S_C3: begin
                    cmp[ci] <= cmp_n;
                    tr[ci]  <= cmp_n > VTR;
                    case (ci)
                        2'd0: o1 <= vout;
                        2'd1: o2 <= vout;
                        default: o3 <= vout;
                    endcase
                    if (ci == 2'd2) st <= S_V0;
                    else begin ci <= ci + 2'd1; st <= S_C0; end
                end
                // attenuation control
                S_V0: st <= S_V1;
                S_V1: begin vth <= mres_v - inl; st <= S_V2; end
                S_V2: begin v10 <= tval; c66r <= o1 - q66_s; st <= S_M1; end
                S_M1: begin
                    con_sat <= con_raw > VOH || con_raw < VOL;
                    con     <= clamp(con_raw, VOL, VOH);
                    st <= S_M2;
                end
                S_M2: begin q66 <= q66 + mres_s; st <= S_M3; end
                // the audio bus, with IC52's control-side tables
                S_M3: begin
                    if (o2 >= o3) begin hi_v <= o2; dneg <= o3 - o2; end
                    else          begin hi_v <= o3; dneg <= o2 - o3; end
                    st <= S_M4;
                end
                S_M4: begin g    <= tval; st <= S_M5; end
                S_M5: begin vo0  <= tval; st <= S_M6; end
                S_M6: begin lo   <= tval; st <= S_M7; end
                S_M7: begin von  <= tval; st <= S_M8; end
                S_M8: begin vonw <= tval; st <= S_M9; end
                S_M9: begin top  <= hi_v + tval; st <= S_B1; end
                S_B1: begin vneg <= vdiff <= 0; vdv <= vdiff; st <= S_B2; end
                S_B2: st <= S_B3;
                S_B3: begin bus <= vneg ? vth : top - tval; st <= S_B4; end
                S_B4: begin mcin <= bus - q64_s; st <= S_N0; end
                // IC52
                S_N0: st <= S_N1;
                S_N1: st <= S_N2;
                S_N2: begin h  <= tval; st <= S_N3; end
                S_N3: begin ib <= tval; ic_ext <= u > U_MAX; st <= S_N4; end
                S_N4: begin w  <= tval; st <= S_N5; end
                S_N5: begin ic <= ic_ext ? IC_LAST + mres_v : tval; st <= S_N6; end
                S_N6: begin heff <= h + mres_v; st <= S_N7; end
                S_N7: begin xs <= vo0 - mres_v - lo; st <= S_N8; end
                S_N8: begin s_ext <= xs >= S_MAX; st <= S_N9; end
                S_N9: begin inl <= iin - mres_v; st <= S_N10; end
                S_N10: begin
                    msum <= lo + (s_ext ? xs : tval);    // limited in S_N11 (timing)
                    st <= S_N11;
                end
                S_N11: begin
                    q64 <= q64 + mres_s;
                    mco <= msum > MC_HI ? MC_HI : msum;
                    st  <= S_O0;
                end
                // output network
                S_O0: begin swo_a <= sound_on ? mres_v : 36'sd0; st <= S_O1; end
                S_O1: begin
                    i72v <= swo_a + mres_v + (sound_on ? OC_ON : OC_OFF) - q72_s - V6;
                    st <= S_O2;
                end
                S_O2: begin i_mix <= i72v; done <= 1'b1; st <= S_O3; end
                S_O3: begin
                    q72 <= q72 + mres_s;
                    v_lag <= lag_s; v_cv <= cv; v_o1 <= o1; v_o2 <= o2; v_o3 <= o3;
                    v_c1 <= clamp(cmp[0], VOL_C, VOH_C); v_c2 <= clamp(cmp[1], VOL_C, VOH_C);
                    v_c3 <= clamp(cmp[2], VOL_C, VOH_C);
                    v_con <= con; v_mcin <= mcin; v_mco <= mco;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
