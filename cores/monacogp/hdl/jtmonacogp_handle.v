// SPDX-License-Identifier: GPL-3.0-or-later
// Handle board 96599-P (manual 420-0358, PDF page 14): the steering wheel's
// two optical sensors to HAN-L-CP and HAN-R-CP. Pin-level transcription:
// docs/trace/STEERING_TRACE.md.
//
// - a, b: the sensors lit (IC1.12, IC1.10, after TR1/TR2 and the 7414);
// - IC2 (74107): the first half toggles when A falls while B is high, the
//   second when B falls while A is high; both cleared by IC1.8;
// - HAN-L-CP = 1Q AND B, HAN-R-CP = A AND 2Q (IC3, IC1);
// - IC3.6 = HAN-L-CP OR HAN-R-CP drives C4 (1 uF) through R3 (220 ohm); the
//   7414 at IC1.9 turns the clear on above its upper threshold and off
//   below its lower one. C4's voltage is stepped once per pixel as an
//   exponential (fixed point), so a pulse that ends early leaves C4 partly
//   charged, as on the board. Levels are typical LS values (output high
//   3.4 V, thresholds 1.7 V and 0.9 V): a full pulse lasts about 0.15 ms and
//   the clear about 0.29 ms more.
// The sensor lines are taken at the pixel enable.
module jtmonacogp_handle #(
    // 2^24 * (1 - exp(-T/RC)), T = 1/7.1525 MHz, RC = 220 ohm * 1 uF
    parameter integer RC_K = 10659,
    parameter integer V_OH = 3565158,  // 3.4 V in 2^-20 V
    parameter integer V_TP = 1782579,  // 1.7 V
    parameter integer V_TN = 943718    // 0.9 V
)(
    input      clk, rst,
    input      pxl_cen,
    input      a, b,                   // sensor 1 and sensor 2 lit
    output     han_l_cp, han_r_cp,
    output     clr_n                   // IC1.8, for tests
);
    reg        a_l, b_l, q1, q2, s9;
    reg [23:0] v;                      // C4, 2^-20 V
    assign clr_n    = ~s9;
    assign han_l_cp = q1 & b;
    assign han_r_cp = a & q2;
    wire       drive = han_l_cp | han_r_cp;            // IC3.6
    wire [23:0] tgt  = drive ? V_OH[23:0] : 24'd0;
    wire signed [25:0] diff = $signed({2'b0, tgt}) - $signed({2'b0, v});
    // rounded to the nearest step, so the discharge tail does not run down
    // to zero faster than the exponential
    wire signed [42:0] step = diff * $signed({1'b0, RC_K[15:0]}) + 43'sd8388608;
    wire signed [18:0] stq = step[42:24];
    wire [23:0] v_n = v + {{5{stq[18]}}, stq};
    wire        s9_n = v_n > V_TP[23:0] ? 1'b1 : v_n < V_TN[23:0] ? 1'b0 : s9;

    always @(posedge clk) begin
        if (rst) begin
            {a_l, b_l, q1, q2, s9} <= 0;
            v <= 0;
        end else if (pxl_cen) begin
            a_l <= a;
            b_l <= b;
            v   <= v_n;
            // 7414 with hysteresis; its output clears at once
            s9  <= s9_n;
            // 74107: clear dominates; J = K = the other line as it was
            // before the falling clock edge
            if (s9_n) q1 <= 0;
            else if (a_l && !a && b_l) q1 <= ~q1;
            if (s9_n) q2 <= 0;
            else if (b_l && !b && a_l) q2 <= ~q2;
        end
    end
endmodule
