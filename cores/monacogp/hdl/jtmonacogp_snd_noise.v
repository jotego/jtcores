// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-4/7 of board 96598-P: the S2688 noise source and its
// amplifier, the skid tone and the EXTEND beep (docs/trace/SOUND_D4_TRACE.md;
// docs/SOUND_LOGIC.md).
//
// - S2688 (IC62): 17-bit shift register, taps 14 and 17, shifted at about
//   100 kHz (a phase accumulator, 5/24 shifts per model step); its output,
//   bit 17, is 3.0 or 10.5 V.
// - Noise amplifier IC63 c: C79 1u, R361 150K, R362 51K around 6 V, its
//   output slewing at the LM324's 0.5 V/us. The bands (jtmonacogp_snd_band.v)
//   take its output: `namp_rdy` pulses when it is ready in a step.
// - Skid tone: the triangle oscillator IC64 b (R392 / R393 hysteresis, R394
//   and C94 10u) and follower IC64 a; IC63 d sums the noise (C80, R385) and
//   the triangle (R390) into R386 and drives the 555's CONTROL through C81
//   33u; the 555 (R383, R384, C89 4700p) runs while its RES (the 7432) is
//   high, stepped 8 times per model step; its output (the mean of the 8)
//   through R405 / R404, C101 and R403 to the mixer.
// - EXTEND: pad 14 EX.CP through 2.2u and R402 to the mixer.
// Output: i_sk, the currents in R402 and R403 times R414 (22K), 2^28 per
// volt. Same step and arithmetic as jtmonacogp_snd_d3.v;
// tests/sound/d4s_fixed.py (NoiseFixed) is the same in Python and generates
// jtmonacogp_snd_noise.vh.
module jtmonacogp_snd_noise(
    input                    clk,
    input                    rst,      // power-on: every capacitor at 0 V
    input                    tick,     // one model step
    input                    skid_on,  // the 7432 output: the 555's RES
    input                    excp,     // pad 14 EX.CP
    output reg signed [35:0] namp,     // IC63 c output
    output reg               namp_rdy, // one clock: namp is this step's
    output reg signed [35:0] i_sk,
    output reg               done,     // one clock when i_sk has been updated
    output reg               nbit,     // the S2688's output this step (D-1), from the step's second clock
    // test views, updated once per step
    output reg               v_noise,
    output reg signed [35:0] v_tri, v_o63d, v_ctl, v_c89,
    output reg               v_q555
);
    `include "jtmonacogp_snd_noise.vh"

    localparam [4:0]
        S_IDLE=0, S_A=1,  S_B=2,  S_C=3,  S_D=4,  S_E=5,  S_F=6,  S_G=7,
        S_H=8,    S_I=9,  S_J=10, S_K=11, S_L=12, S_M=13, S_N=14, S_O=15,
        S_P=16,   S_Q=17, S_R=18, S_S=19, S_T=20, S_U=21, S_V=22;

    reg [4:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_A, S_C, S_D, S_E, S_F, S_H, S_I, S_J, S_L, S_M, S_O, S_R, S_S,
        S_U, S_V: mul_st = 1'b1;
        default:  mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction

    // ---- state
    reg        [16:0] lfsr;
    reg        [4:0]  nph;
    reg signed [51:0] q79, c94, q80, q81, c89, q101, qex;
    reg               hi, q555;
    reg        [2:0]  sub;      // the 555's sub-step
    reg        [3:0]  nhi;      // its sub-steps with OUTPUT high
    // ---- step registers
    reg signed [35:0] vn, s, vt, vo, vm, tmp, trv, o63d, e81, ctl, e101, eex, i403;

    wire signed [35:0] q79_s  = q79[51:16];
    wire signed [35:0] c94_s  = c94[51:16];
    wire signed [35:0] q80_s  = q80[51:16];
    wire signed [35:0] q81_s  = q81[51:16];
    wire signed [35:0] c89_s  = c89[51:16];
    wire signed [35:0] q101_s = q101[51:16];
    wire signed [35:0] qex_s  = qex[51:16];
    wire signed [35:0] s80    = vn - q80_s;
    wire signed [35:0] dvt    = vt - namp;
    wire signed [35:0] vo_n   = clamp(namp + clamp(dvt, -SLEW, SLEW), VOL, VOH);
    wire signed [40:0] o555_m = O555_D * $signed({1'b0, nhi});
    wire signed [35:0] o555   = O555_LO + o555_m[38:3];

    wire [4:0]  nph_a = nph + NOISE_NUM;
    wire        shift = nph_a >= NOISE_DEN;
    wire [16:0] lfsr_n = {lfsr[15:0], lfsr[13] ^ lfsr[16] ^ (lfsr == 17'd0)};

    // ---- the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
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

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        case (st)
            S_A: begin ma = s - V6;  mb = K362_M; msh = K362_S; end
            S_C: begin ma = s;       mb = KMS_M;  msh = KMS_S;  end
            S_D: begin ma = vo;      mb = KMO_M;  msh = KMO_S;  end
            S_E: begin ma = s - vm;  mb = K79_M;  msh = K79_S;  end
            S_F: begin ma = (hi ? VTH_HI : VTH_LO) - c94_s; mb = K94_M; msh = K94_S; end
            S_H: begin ma = s80 - V6; mb = K385_M; msh = K385_S; end
            S_I: begin ma = trv - V6; mb = K390_M; msh = K390_S; end
            S_J: begin ma = s80 - V6; mb = K80_M;  msh = K80_S;  end
            S_L: begin ma = e81;     mb = KCTL_M; msh = KCTL_S; end
            S_M: begin ma = e81;     mb = K81_M;  msh = K81_S;  end
            S_O: begin ma = q555 ? VCC - c89_s : VDIS - c89_s;
                       mb = q555 ? KCH_M : KDIS_M; msh = q555 ? KCH_S : KDIS_S; end
            S_R: begin ma = e101;    mb = K101_M; msh = K101_S; end
            S_S: begin ma = e101;    mb = K403_M; msh = K403_S; end
            S_U: begin ma = eex;     mb = KEX_M;  msh = KEX_S;  end
            S_V: begin ma = eex;     mb = K402_M; msh = K402_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0; namp_rdy <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            lfsr <= 17'h1ffff; nph <= 5'd0; nbit <= 1'b0;
            q79 <= 52'sd0; c94 <= 52'sd0; q80 <= 52'sd0; q81 <= 52'sd0;
            c89 <= 52'sd0; q101 <= 52'sd0; qex <= 52'sd0;
            hi <= 1'b1; q555 <= 1'b0; sub <= 3'd0; nhi <= 4'd0;
            namp <= V6; i_sk <= 36'sd0;
            v_noise <= 1'b0; {v_tri, v_o63d, v_ctl, v_c89} <= 0; v_q555 <= 1'b0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (tick) begin
                    // the S2688
                    nbit <= shift ? lfsr_n[16] : lfsr[16];
                    if (shift) begin
                        nph <= nph_a - NOISE_DEN; lfsr <= lfsr_n;
                        vn  <= lfsr_n[16] ? VN_HI : VN_LO;
                        s   <= (lfsr_n[16] ? VN_HI : VN_LO) - q79_s;
                    end else begin
                        nph <= nph_a;
                        vn  <= lfsr[16] ? VN_HI : VN_LO;
                        s   <= (lfsr[16] ? VN_HI : VN_LO) - q79_s;
                    end
                    st <= S_A;
                end
                // noise amplifier IC63 c
                S_A: begin vt <= V6 - mres_v; st <= S_B; end
                S_B: begin
                    vo <= vo_n;
                    if (vo_n == vt) begin vm <= V6; st <= S_E; end
                    else st <= S_C;
                end
                S_C: begin tmp <= mres_v; st <= S_D; end
                S_D: begin vm <= tmp + mres_v; st <= S_E; end
                S_E: begin
                    q79 <= q79 + mres_s; namp <= vo; namp_rdy <= 1'b1;
                    st <= S_F;
                end
                // triangle IC64 b, follower IC64 a
                S_F: begin c94 <= c94 + mres_s; st <= S_G; end
                S_G: begin
                    if (hi && c94_s > VP_HI) hi <= 1'b0;
                    else if (!hi && c94_s < VP_LO) hi <= 1'b1;
                    trv <= clamp(c94_s, VOL, VOH);
                    st <= S_H;
                end
                // IC63 d
                S_H: begin tmp <= mres_v; st <= S_I; end
                S_I: begin o63d <= clamp(V6 - (tmp + mres_v), VOL, VOH); st <= S_J; end
                S_J: begin q80 <= q80 + mres_s; st <= S_K; end
                // C81 into the 555's CONTROL
                S_K: begin e81 <= o63d - q81_s - VCTL; st <= S_L; end
                S_L: begin ctl <= VCTL + mres_v; st <= S_M; end
                S_M: begin q81 <= q81 + mres_s; st <= S_N; end
                // the 555
                // the 555, in 8 sub-steps (RES is held through the step)
                S_N: begin
                    if (!skid_on) q555 <= 1'b0;
                    sub <= 3'd0; nhi <= 4'd0; st <= S_O;
                end
                S_O: begin c89 <= c89 + mres_s; nhi <= nhi + {3'd0, q555}; st <= S_P; end
                S_P: begin
                    if (skid_on) begin
                        if (c89_s >= ctl) q555 <= 1'b0;
                        else if (c89_s <= (ctl >>> 1)) q555 <= 1'b1;
                    end
                    sub <= sub + 3'd1;
                    st  <= sub == 3'd7 ? S_Q : S_O;
                end
                S_Q: begin e101 <= o555 - q101_s - V6; st <= S_R; end
                S_R: begin q101 <= q101 + mres_s; st <= S_S; end
                S_S: begin i403 <= mres_v; st <= S_T; end
                // EXTEND CP
                S_T: begin eex <= (excp ? VEX_HI : VEX_LO) - qex_s - V6; st <= S_U; end
                S_U: begin qex <= qex + mres_s; st <= S_V; end
                S_V: begin
                    i_sk <= i403 + mres_v; done <= 1'b1;
                    v_noise <= vn == VN_HI; v_tri <= trv; v_o63d <= o63d; v_ctl <= ctl;
                    v_c89 <= c89_s; v_q555 <= q555;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
