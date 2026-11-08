// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-2/7 of board 96598-P: the rescue car's siren tone
// (docs/trace/SOUND_D2_TRACE.md; model and checks: docs/SOUND_LOGIC.md).
//
// The 555 IC39 (12 V; R268 10K, R269 680K, C47 0.68 uF, about 1.4 Hz) keys
// node W through D15 / R230; IC40 d integrates node W's current from
// R232 30K on C49 0.033 uF, and while the Schmitt IC40 a (R272 51K from
// 6 V, R273 100K) is high TR16 discharges C49 through R231 680 ohm: a
// sawtooth of about 700 Hz, 3.9 to 10 V. One step per `start`: the 555
// once, then 8 sub-steps of the VCO, with IC40 a's output slewing (an
// internal node, as the LM324 model of the reference). `saw` (IC40 pin 14)
// holds the step's last value. `done` after about 76 clocks.
// tests/sound/d2_fixed.py (VcoFixed) is the same arithmetic.
module jtmonacogp_snd_d2vco(
    input                    clk,
    input                    rst,
    input                    start,
    output reg signed [35:0] saw,      // IC40 pin 14
    output reg               done,
    output reg signed [35:0] o40_1,    // IC40 pin 1
    // test view
    output reg               v_o555
);
    `include "jtmonacogp_snd_d2.vh"

    localparam [2:0] S_IDLE=0, S_T=1, S_A=2, S_B=3, S_C=4, S_D=5, S_E=6, S_F=7;

    reg  [2:0] st;
    reg        ph;
    wire       mul_st = st == S_T || st == S_B || st == S_C || st == S_F;
    wire       adv = !mul_st || ph;

    reg signed [51:0] v47;
    reg               o555;
    reg signed [35:0] q49, n40, sp;
    reg        [2:0]  n;

    wire signed [35:0] v47_s = v47[51:16];
    wire signed [35:0] v13 = o555 ? D2_V13_H : D2_V13_L;
    wire signed [35:0] iw  = o555 ? D2_IW_H  : D2_IW_L;
    wire signed [35:0] icm = o555 ? D2_ICM_H : D2_ICM_L;

    // ---- table ROM: issue in one state, the two entries two states later
    reg                tsel;          // 0 TR16, 1 SLEW
    reg                tiss;
    reg  signed [35:0] tx;
    reg  [9:0]         ra;
    reg  [24:0]        fra, frb;
    reg  [4:0]         ffa, ffb;
    reg  signed [35:0] rq0, rq1;
    wire [9:0]         t_base = tsel ? T_SLEW_BASE : T_TR16_BASE;
    wire [9:0]         t_n    = tsel ? T_SLEW_N    : T_TR16_N;
    wire [4:0]         t_f    = tsel ? T_SLEW_F    : T_TR16_F;
    wire signed [35:0] t_x0   = tsel ? T_SLEW_X0   : T_TR16_X0;
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
        rq0 <= rom_vco[ra];
        rq1 <= rom_vco[ra1];
        frb <= fra;
        ffb <= ffa;
    end

    // ---- the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
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

    // 555: C47 after this step
    wire signed [51:0] v47_n   = o555 ? v47 + mres_s : v47 - mres_s;
    wire signed [35:0] v47_n_s = v47_n[51:16];
    // VCO sub-step: TR16's current (at most what R231 passes), C49, the
    // sawtooth within the output limits
    wire signed [35:0] ic      = tval < icm ? tval : icm;
    wire signed [35:0] q49_a   = q49 + ic - iw;
    wire signed [35:0] tri_a   = v13 + q49_a;
    wire               tri_hi  = tri_a > D2_VOH;
    wire               tri_lo  = tri_a < D2_VOL;
    // the slewing node
    wire signed [35:0] n40_a   = n40 + tval;
    wire signed [35:0] n40_n   = n40_a < D2_N40_LO ? D2_N40_LO : n40_a > D2_N40_HI ? D2_N40_HI : n40_a;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tiss = 1'b0; tsel = 1'b0; tx = 36'sd0;
        case (st)
            S_T: begin
                ma  = o555 ? D2_V12 - v47_s : v47_s - D2_V_DSG;
                mb  = o555 ? KCH_M : KDSG_M;
                msh = o555 ? KCH_S : KDSG_S;
            end
            S_A: begin tiss = 1'b1; tsel = 1'b0; tx = o40_1; end
            S_B: begin ma = o40_1; mb = KSP_M; msh = KSP_S; end
            S_C: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_D: begin tiss = 1'b1; tsel = 1'b1; tx = D2_SP0 + sp - saw; end
            S_F: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0; n <= 3'd0;
            v47 <= 52'sd0; o555 <= 1'b1;
            q49 <= 36'sd0; n40 <= D2_VOL; sp <= 36'sd0;
            saw <= 36'sd0; o40_1 <= D2_VOL; v_o555 <= 1'b1;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) st <= S_T;
                S_T: begin
                    v47 <= v47_n;
                    if (o555) begin if (v47_n_s >= D2_TH_HI) o555 <= 1'b0; end
                    else if (v47_n_s <= D2_TH_LO) o555 <= 1'b1;
                    n  <= 3'd0;
                    st <= S_A;
                end
                S_A: st <= S_B;
                S_B: begin sp <= mres_v; st <= S_C; end
                S_C: begin
                    if (tri_hi)      begin saw <= D2_VOH; q49 <= D2_VOH - v13; end
                    else if (tri_lo) begin saw <= D2_VOL; q49 <= D2_VOL - v13; end
                    else             begin saw <= tri_a;  q49 <= q49_a; end
                    st <= S_D;
                end
                S_D: st <= S_E;
                S_E: st <= S_F;
                S_F: begin
                    n40     <= n40_n;
                    o40_1 <= n40_n < D2_VOL ? D2_VOL : n40_n > D2_VOH ? D2_VOH : n40_n;
                    if (n == D2_SUB - 1) begin
                        v_o555 <= o555;
                        done   <= 1'b1;
                        st     <= S_IDLE;
                    end else begin
                        n  <= n + 3'd1;
                        st <= S_A;
                    end
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
