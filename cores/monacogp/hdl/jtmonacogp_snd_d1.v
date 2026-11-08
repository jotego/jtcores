// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-1/7 of board 96598-P: the SLIP ZONE SOUND
// (docs/trace/SOUND_D1_TRACE.md; model and checks: docs/SOUND_LOGIC.md).
//
// The S2688's noise (D-4) goes through C68, R345 / C105 and R350 into
// IC53 a's multiple-feedback band-pass (C70, C71 0.022 uF, R348 220K),
// whose input node A is shunted to ground by R349 and a 2SC458. The
// transistor's base follows C63 of the relaxation oscillator IC53 c
// (R309 10K, C63 22 uF, hysteresis from VR7's wiper through R351 1K and
// R307 100K) through IC53 d and R308, so the band's centre warbles. IC53 b
// (C69, R347 33K, R346 100K) amplifies it; the 4016 IC54 passes it while
// pad J (SLIP ZONE) is low, through C73 2.2 uF and R412 51K into the D-4
// mixer's 6 V virtual ground (R353 / R354 bias the node).
//
// IC53 a has the LM324's finite gain-bandwidth: its output is stepped by
// backward Euler from the capacitors' charges; C70 is stepped before C71,
// and C71 from C70's new charge. The transistor's current is a cubic in
// node A's voltage whose coefficients are tabulated against the follower's
// level (interpolated). IC53 c's output slews as the LM324 (table of the
// tanh step). `noise` is the S2688's bit for this step (jtmonacogp_snd_noise
// `nbit`, valid from the step's second clock; read about 35 clocks in).
// Output `i_mix`: the R412 current times R414 (22K), 2^28 per volt. One
// step per `start`; `done` after about 60 clocks. tests/sound/d1_fixed.py
// (D1Fixed) is the same arithmetic and generates jtmonacogp_snd_d1.vh.
module jtmonacogp_snd_d1(
    input                    clk,
    input                    rst,
    input                    start,
    input                    noise,    // the S2688's output bit this step
    input                    slip_n,   // pad J (SLIP ZONE), low in the slip zone
    output reg signed [35:0] i_mix,
    output reg               done,
    // test views, updated once per step
    output reg signed [35:0] v_c63, v_o8, v_na, v_o1, v_o7, v_sw
);
    `include "jtmonacogp_snd_d1.vh"

    localparam [5:0]
        S_IDLE=0, S_O0=1, S_O1=2, S_O2=3, S_O3=4, S_O4=5, S_O5=6, S_O6=7,
        S_O7=8, S_O8=9, S_O9=10, S_O10=11, S_O11=12, S_O12=13,
        S_T0=14, S_T1=15, S_T2=16, S_T3=17,
        S_N0=18, S_N1=19, S_N2=20, S_N3=21, S_N4=22, S_N5=23,
        S_G0=24, S_G1=25, S_G2=26, S_G3=27, S_G4=28, S_G5=29,
        S_W0=30, S_W1=31, S_W2=32, S_W3=33, S_W4=34;

    reg [5:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_O0, S_O1, S_O2, S_O3, S_O4, S_O5, S_O6, S_O7, S_O8,
        S_T0, S_T1, S_T2, S_T3, S_N1, S_N2, S_N3, S_N4, S_N5,
        S_G1, S_G3, S_G4, S_G5, S_W0, S_W1, S_W3, S_W4: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    // ---- state
    reg signed [51:0] v63, q68, v105, q70, q71, q69, q73;
    reg signed [35:0] n8, vo;
    // ---- step registers
    reg               on_l;
    reg signed [35:0] v63s_l, vf_l, q70s_l, q71s_l, d, a1, vraw, slo, shi, v1, va, x;
    reg signed [35:0] c3, c2, c1, c0, t, itr, nx, e345, e350, e3;
    reg signed [35:0] n69, o7r, o7, vm, sw, e412;

    wire signed [35:0] v63_s = v63[51:16];
    wire signed [35:0] q68_s = q68[51:16];
    wire signed [35:0] v105_s = v105[51:16];
    wire signed [35:0] q70_s = q70[51:16];
    wire signed [35:0] q71_s = q71[51:16];
    wire signed [35:0] q69_s = q69[51:16];
    wire signed [35:0] q73_s = q73[51:16];

    function signed [35:0] lim;
        input signed [35:0] v;
        lim = v < D1_VOL ? D1_VOL : v > D1_VOH ? D1_VOH : v;
    endfunction
    // IC53 c's output: its slewing node within the output limits
    wire signed [35:0] o8 = lim(n8);

    // ---- table ROM: issue in one state, the two entries two states later
    reg  [2:0]         tsel;          // SLEW, C0, C1, C2, C3
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
        3'd0:    begin t_base=T_SLEW_BASE; t_n=T_SLEW_N; t_f=T_SLEW_F; t_x0=T_SLEW_X0; end
        3'd1:    begin t_base=T_C0_BASE;   t_n=T_C0_N;   t_f=T_C0_F;   t_x0=T_C0_X0;   end
        3'd2:    begin t_base=T_C1_BASE;   t_n=T_C1_N;   t_f=T_C1_F;   t_x0=T_C1_X0;   end
        3'd3:    begin t_base=T_C2_BASE;   t_n=T_C2_N;   t_f=T_C2_F;   t_x0=T_C2_X0;   end
        default: begin t_base=T_C3_BASE;   t_n=T_C3_N;   t_f=T_C3_F;   t_x0=T_C3_X0;   end
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
        rq0 <= rom_d1[ra];
        rq1 <= rom_d1[ra1];
        frb <= fra;
        ffb <= ffa;
    end

    // ---- the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
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
    wire signed [35:0] tval = rq0 + mres_v;
    wire signed [35:0] c1_e = c1 >>> D1_E1;   // the linear continuation's slope

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tiss = 1'b0; tsel = 3'd0; tx = 36'sd0;
        case (st)
            // oscillator
            S_O0: begin ma = o8; mb = K10_M; msh = K10_S; tiss = 1'b1; tsel = 3'd4; tx = vf_l; end
            S_O1: begin ma = o8 - v63s_l; mb = K63_M; msh = K63_S; tiss = 1'b1; tsel = 3'd3; tx = vf_l; end
            S_O2: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; tiss = 1'b1; tsel = 3'd2; tx = vf_l; end
            S_O3: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; tiss = 1'b1; tsel = 3'd1; tx = vf_l; end
            S_O4: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; tiss = 1'b1; tsel = 3'd0; tx = d; end
            S_O5, S_O6: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            // IC53 a
            S_O7: begin ma = vo; mb = KA_M; msh = KA_S; end
            S_O8: begin ma = D1_V6 - q70s_l + q71s_l; mb = KB_M; msh = KB_S; end
            // the transistor: Horner in x, then the continuation beyond XLIM
            S_T0: begin ma = c3; mb = x[26:0]; msh = D1_S3; end
            S_T1: begin ma = t;  mb = x[26:0]; msh = D1_S2; end
            S_T2: begin ma = t;  mb = x[26:0]; msh = D1_S1; end
            S_T3: begin ma = va - x; mb = c1_e[26:0]; msh = D1_SE; end
            // the noise input, C70, C71
            S_N1: begin ma = e345; mb = K68_M; msh = K68_S; end
            S_N2: begin ma = e345 - e350; mb = K105_M; msh = K105_S; end
            S_N3: begin ma = q70s_l - q71s_l; mb = K3_M; msh = K3_S; end
            S_N4: begin ma = e350 - itr - e3; mb = K70_M; msh = K70_S; end
            S_N5: begin ma = q70_s - q71s_l; mb = K71_M; msh = K71_S; end
            // IC53 b
            S_G1: begin ma = n69 - D1_V6; mb = KG_M; msh = KG_S; end
            S_G3: begin ma = n69; mb = KGA_M; msh = KGA_S; end
            S_G4: begin ma = o7; mb = KGB_M; msh = KGB_S; end
            S_G5: begin ma = n69 - vm; mb = K69_M; msh = K69_S; end
            // the 4016 and the output
            S_W0: if (on_l) begin ma = o7; mb = KS1_M; msh = KS1_S; end
                  else begin ma = q73_s; mb = KS2F_M; msh = KS2F_S; end
            S_W1: begin ma = on_l ? q73_s : 36'sd0; mb = KS2_M; msh = KS2_S; end
            S_W3: begin ma = e412; mb = K73_M; msh = K73_S; end
            S_W4: begin ma = e412; mb = KMX_M; msh = KMX_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            v63 <= 52'sd0; q68 <= 52'sd0; v105 <= 52'sd0; q70 <= 52'sd0; q71 <= 52'sd0;
            q69 <= 52'sd0; q73 <= 52'sd0;
            n8 <= 36'sd0; vo <= 36'sd0;
            i_mix <= 36'sd0;
            {v_c63, v_o8, v_na, v_o1, v_o7, v_sw} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) begin
                    on_l   <= !slip_n;
                    v63s_l <= v63_s;
                    vf_l   <= lim(v63_s);         // IC53 d
                    q70s_l <= q70_s;
                    q71s_l <= q71_s;
                    st <= S_O0;
                end
                // ---- the oscillator IC53 c and the transistor's coefficients
                S_O0: begin d <= D1_A10 + mres_v - v63s_l; st <= S_O1; end
                S_O1: begin v63 <= v63 + mres_s; st <= S_O2; end
                S_O2: begin c3 <= tval; st <= S_O3; end
                S_O3: begin c2 <= tval; st <= S_O4; end
                S_O4: begin c1 <= tval; st <= S_O5; end
                S_O5: begin c0 <= tval; st <= S_O6; end
                S_O6: begin nx <= n8 + tval; st <= S_O7; end
                // ---- IC53 a's output, slew-limited, within its limits
                S_O7: begin
                    n8  <= nx < D1_N8_LO ? D1_N8_LO : nx > D1_N8_HI ? D1_N8_HI : nx;
                    a1  <= mres_v;
                    slo <= vo - D1_SLEW;
                    shi <= vo + D1_SLEW;
                    st <= S_O8;
                end
                S_O8: begin vraw <= a1 + mres_v; st <= S_O9; end
                S_O9: begin v1 <= vraw < slo ? slo : vraw > shi ? shi : vraw; st <= S_O10; end
                S_O10: begin vo <= lim(v1); st <= S_O11; end
                S_O11: begin va <= vo + q70s_l; st <= S_O12; end
                S_O12: begin x <= va < -D1_XLIM ? -D1_XLIM : va > D1_XLIM ? D1_XLIM : va; st <= S_T0; end
                S_T0: begin t <= c2 + mres_v; st <= S_T1; end
                S_T1: begin t <= c1 + mres_v; st <= S_T2; end
                S_T2: begin itr <= c0 + mres_v; st <= S_T3; end
                S_T3: begin itr <= itr + mres_v; st <= S_N0; end
                // ---- the noise input network, C70 and C71
                S_N0: begin
                    e345 <= (noise ? D1_VN_HI : D1_VN_LO) - q68_s - v105_s;
                    e350 <= v105_s - va;
                    st <= S_N1;
                end
                S_N1: begin q68 <= q68 + mres_s; st <= S_N2; end
                S_N2: begin v105 <= v105 + mres_s; st <= S_N3; end
                S_N3: begin e3 <= mres_v; st <= S_N4; end
                S_N4: begin q70 <= q70 + mres_s; st <= S_N5; end
                S_N5: begin q71 <= q71 + mres_s; st <= S_G0; end
                // ---- IC53 b
                S_G0: begin n69 <= vo - q69_s; st <= S_G1; end
                S_G1: begin o7r <= D1_V6 - mres_v; st <= S_G2; end
                S_G2: begin
                    if (o7r > D1_VOH || o7r < D1_VOL) begin
                        o7 <= lim(o7r); st <= S_G3;
                    end else begin
                        o7 <= o7r; vm <= D1_V6; st <= S_G5;
                    end
                end
                S_G3: begin vm <= mres_v; st <= S_G4; end
                S_G4: begin vm <= vm + mres_v; st <= S_G5; end
                S_G5: begin q69 <= q69 + mres_s; st <= S_W0; end
                // ---- the 4016, C73, R412
                S_W0: begin sw <= mres_v + (on_l ? D1_SB_ON : D1_SB_OFF); st <= S_W1; end
                S_W1: begin sw <= sw + mres_v; st <= S_W2; end
                S_W2: begin e412 <= sw - q73_s - D1_V6; st <= S_W3; end
                S_W3: begin q73 <= q73 + mres_s; st <= S_W4; end
                S_W4: begin
                    i_mix <= mres_v;
                    v_c63 <= v63_s; v_o8 <= o8; v_na <= va; v_o1 <= vo; v_o7 <= o7; v_sw <= sw;
                    done <= 1'b1;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
