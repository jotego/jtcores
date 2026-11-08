// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheets D-6/7 and D-7/7 of board 96598-P: the other cars
// (docs/trace/SOUND_D6_TRACE.md, docs/trace/SOUND_D7_TRACE.md; model and
// checks: docs/SOUND_LOGIC.md).
//
// Five blocks work side by side on each `tick` (one model step, 480 kHz):
// the control (jtmonacogp_snd_d7ctl), the two D-6 banks
// (jtmonacogp_snd_d6bank) and each car's two D-7 MC3340s
// (jtmonacogp_snd_d7car). Each takes the others' outputs of the previous
// step (held here), so the banks see CAR CON, and the D-7 MC3340s the banks'
// outputs and their CONTROLs, one step (about 2 us) late. When all five are
// done, this module steps D-6's half-rail (R82 / R83 1K, C22 + C23 200 uF,
// the six comparators' 51K loads) and the front mixer (IC32 b, R426 33K,
// C15 2.2 uF, R409 82K into the D-4 mixer's 6 V virtual ground).
// Outputs: i_mf, the R409 current times R414 (22K); i_mb, the current into
// D-2's IC40 pin 6 times 51K (D-2 is not built: unused for now).
// R109: bank 1's CONTROL bias option (jtmonacogp_snd_d6bank; 0 = .33K as
// drawn, the default; 1 = 3.3K; 2 = 33K; docs/sound/OTHER_CAR_COMPARE.md).
// tests/sound/d67_fixed.py (D67Fixed) is the same arithmetic.
module jtmonacogp_snd_d67 #(parameter R109 = 0) (
    input                    clk,
    input                    rst,
    input                    tick,
    input              [3:0] acc,      // S-ACCE D, C, B, A (pad high = 1)
    input                    fs_n,     // pad C, /F-SOUND (sheet H), sampled every clock
    output reg signed [35:0] i_mf,
    output reg signed [35:0] i_mb,
    output reg               done,
    // test views, updated once per step
    output reg signed [35:0] v_front, v_r6,
    output        signed [35:0] v_feed, v_r14, v_r28, v_u1, v_u2,
    output        signed [35:0] v_con20, v_con19, v_con34, v_con33, v_cv1, v_cv2,
    output                   v_q59a, v_q59b, v_q58, v_c292, v_c2913,
    output        signed [35:0] v_o1, v_o2, v_o3, v_con1, v_con2, v_o1b,
    output        signed [35:0] v_snd1, v_snd2
);
    `include "jtmonacogp_snd_d67.vh"

    localparam [3:0] S_IDLE=0, S_RUN=1, S_T0=2, S_T1=3, S_T2=4, S_T3=5, S_T4=6, S_T5=7;

    reg  [3:0] st;
    reg        ph;
    wire       mul_st = st == S_T0 || st == S_T1 || st == S_T4 || st == S_T5;
    wire       adv = !mul_st || ph;

    // pad C: low at any clock of the step
    reg        fs_acc, fs_step;
    reg  [3:0] acc_l;
    reg        go;
    // the blocks' outputs of the previous step
    reg signed [35:0] p_m1, p_m2, p_con20, p_con19, p_con34, p_con33, p_cv1, p_cv2;
    reg               p_q59a, p_q59b;
    // state
    reg signed [51:0] r6, q15;
    reg signed [35:0] d1, front, e15;
    reg        [4:0]  got;

    wire signed [35:0] r6_s  = r6[51:16];
    wire signed [35:0] q15_s = q15[51:16];

    wire        d_ctl, d_b1, d_b2, d_c1, d_c2;
    wire signed [35:0] con20, con19, con34, con33, cv1, cv2;
    wire               q59a, q59b;
    wire signed [35:0] m1, m2, svp1, svp2, ef1, eb1, ef2, eb2;
    wire signed [35:0] b2_o2, b2_o3, b2_mcin, b1_mcin;
    wire signed [35:0] c1_mf, c1_mb, c1_bf, c1_bb, c2_node, c2_mf, c2_mb, c2_bf, c2_bb;

    jtmonacogp_snd_d7ctl u_ctl(
        .clk(clk), .rst(rst), .start(go), .acc(acc_l), .fs_low(fs_step),
        .con20(con20), .con19(con19), .con34(con34), .con33(con33), .cv1(cv1), .cv2(cv2),
        .q59a(q59a), .q59b(q59b), .done(d_ctl),
        .v_feed(v_feed), .v_r14(v_r14), .v_r28(v_r28), .v_u1(v_u1), .v_u2(v_u2),
        .v_c292(v_c292), .v_c2913(v_c2913), .v_q58(v_q58));
    jtmonacogp_snd_d6bank #(.NO(1), .R109(R109)) u_bank1(
        .clk(clk), .rst(rst), .start(go), .cv(p_cv1), .r6(r6_s),
        .mco(m1), .svp(svp1), .done(d_b1),
        .v_o1(v_o1), .v_o2(v_o2), .v_o3(v_o3), .v_con(v_con1), .v_mcin(b1_mcin));
    jtmonacogp_snd_d6bank #(.NO(2)) u_bank2(
        .clk(clk), .rst(rst), .start(go), .cv(p_cv2), .r6(r6_s),
        .mco(m2), .svp(svp2), .done(d_b2),
        .v_o1(v_o1b), .v_o2(b2_o2), .v_o3(b2_o3), .v_con(v_con2), .v_mcin(b2_mcin));
    jtmonacogp_snd_d7car u_car1(
        .clk(clk), .rst(rst), .start(go), .mco(p_m1), .conf(p_con20), .conb(p_con19),
        .on(!p_q59a), .ef(ef1), .eb(eb1), .done(d_c1),
        .v_node(v_snd1), .v_mf(c1_mf), .v_mb(c1_mb), .v_bf(c1_bf), .v_bb(c1_bb));
    jtmonacogp_snd_d7car u_car2(
        .clk(clk), .rst(rst), .start(go), .mco(p_m2), .conf(p_con34), .conb(p_con33),
        .on(!p_q59b), .ef(ef2), .eb(eb2), .done(d_c2),
        .v_node(v_snd2), .v_mf(c2_mf), .v_mb(c2_mb), .v_bf(c2_bf), .v_bb(c2_bb));

    assign v_con20 = p_con20; assign v_con19 = p_con19;
    assign v_con34 = p_con34; assign v_con33 = p_con33;
    assign v_cv1 = p_cv1; assign v_cv2 = p_cv2;
    assign v_q59a = p_q59a; assign v_q59b = p_q59b;

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

    wire signed [35:0] front_r = V6 - ef1 - ef2;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        case (st)
            S_T0: begin ma = V6 - r6_s; mb = KR6A_M; msh = KR6A_S; end
            S_T1: begin ma = (r6_s <<< 2) + (r6_s <<< 1) - svp1 - svp2; mb = KR6B_M; msh = KR6B_S; end
            S_T4: begin ma = e15; mb = KMF_M; msh = KMF_S; end
            S_T5: begin ma = e15; mb = K15C_M; msh = K15C_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        go   <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            fs_acc <= 1'b0; fs_step <= 1'b0; acc_l <= 4'd0;
            {p_m1, p_m2, p_con20, p_con19, p_con34, p_con33, p_cv1, p_cv2} <= 0;
            p_q59a <= 1'b0; p_q59b <= 1'b0;
            r6 <= {R6_0, 16'd0}; q15 <= 52'sd0;
            i_mf <= 36'sd0; i_mb <= 36'sd0; v_front <= 36'sd0; v_r6 <= 36'sd0;
            got <= 5'd0;
        end else begin
            // the step that starts at this tick takes pad C as it was over
            // the clocks since the previous tick
            if (tick) begin
                fs_step <= fs_acc;
                fs_acc  <= !fs_n;
                acc_l   <= acc;
            end else fs_acc <= fs_acc || !fs_n;
            if (!adv) ph <= 1'b1;
            else begin
                ph <= 1'b0;
                case (st)
                    S_IDLE: if (tick) begin go <= 1'b1; got <= 5'd0; st <= S_RUN; end
                    S_RUN: begin
                        got <= got | {d_c2, d_c1, d_b2, d_b1, d_ctl};
                        if ((got | {d_c2, d_c1, d_b2, d_b1, d_ctl}) == 5'h1f) st <= S_T0;
                    end
                    S_T0: begin d1 <= mres_v; st <= S_T1; end
                    S_T1: begin r6 <= r6 + {{16{d1[35]}}, d1} - mres_s; st <= S_T2; end
                    S_T2: begin
                        front <= front_r < VOL ? VOL : front_r > VOH ? VOH : front_r;
                        st <= S_T3;
                    end
                    S_T3: begin e15 <= front - q15_s - V6; st <= S_T4; end
                    S_T4: begin i_mf <= mres_v; st <= S_T5; end
                    S_T5: begin
                        q15 <= q15 + mres_s;
                        i_mb <= eb1 + eb2;
                        v_front <= front; v_r6 <= r6_s;
                        p_m1 <= m1; p_m2 <= m2;
                        p_con20 <= con20; p_con19 <= con19; p_con34 <= con34; p_con33 <= con33;
                        p_cv1 <= cv1; p_cv2 <= cv2; p_q59a <= q59a; p_q59b <= q59b;
                        done <= 1'b1;
                        st <= S_IDLE;
                    end
                    default: st <= S_IDLE;
                endcase
            end
        end
    end
endmodule
