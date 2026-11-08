// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-4/7 of board 96598-P: the summing amplifier IC66 b and the
// SOUND OUT network (docs/trace/SOUND_D4_TRACE.md; docs/SOUND_LOGIC.md).
//
// IC66 b sums its input currents into its 6 V virtual ground through R414
// (22K) and is clipped at the LM324's output limits. Its output goes through
// C103 10u and R413 1K to the R407 1K / pad 13 node; while IC67 is low
// (mute), IC57 (7417) sinks that node through R406 100 ohm. Pad 13 feeds the
// cabinet's amplifier, whose input is taken as 10K (assumed: it is not on
// the board). It mixes MY CAR SOUND (D-3, the R411 current) and the other
// inputs (the D-4 explosion, skid and EXTEND currents, the other cars' R409
// and D-2's R410 and R424, already times R414).
//
// One step per `go` (when the sources are done), same model step; every
// DECIM steps the mean of pad 13 becomes `snd` (16384 per volt) and the
// mean of D-2's pad R (BACK SOUND OUT) `snd_b` (4096 per volt), with a
// one-clock `sample` pulse: 48 kHz. tests/sound/d4_fixed.py (MixFixed) is
// the same arithmetic and generates jtmonacogp_snd_mix.vh.
module jtmonacogp_snd_mix(
    input                    clk,
    input                    rst,
    input                    go,       // one model step
    input  signed     [35:0] i_my,     // D-3: R411 current times 100K, 2^28 per volt
    input  signed     [35:0] i_d4,     // D-4: R401 + R402 + R403, D-7's R409, D-2's R410 + R424; times R414
    input  signed     [35:0] padr,     // D-2: pad R, BACK SOUND OUT
    input                    mute,     // IC57 sinking pad 13 through R406
    output reg signed [15:0] snd,
    output reg signed [15:0] snd_b,
    output reg               sample,
    // test views
    output reg signed [35:0] v_mix,    // IC66 b output
    output reg signed [35:0] v_pad     // pad 13
);
    `include "jtmonacogp_snd_mix.vh"

    localparam [2:0] S_IDLE=0, S_A=1, S_B=2, S_C=3, S_D=4, S_DB=5, S_E=6;

    reg        [2:0]  st;
    reg               ph;              // second clock of a multiplier state
    wire              mul_st = st == S_A || st == S_B || st == S_C || st == S_D || st == S_DB;
    reg        [3:0]  n;
    reg signed [51:0] c103;            // C103, IC66 b side minus R413 side
    reg signed [35:0] acc, acc_b, d;
    reg               mute_l;
    reg signed [35:0] i_d4_l, padr_l;

    wire signed [35:0] c103_s = c103[51:16];

    // the multiplier: mres = (ma * mb + 2^(msh-1)) >> msh
    reg  signed [35:0] ma;
    reg  signed [26:0] mb;
    reg         [5:0]  msh;
    wire signed [62:0] prod = ma * mb;
    reg  signed [62:0] prod_q;        // registered for timing: such a state takes two clocks
    always @(posedge clk) prod_q <= prod;
    wire signed [63:0] mrnd = {prod_q[62], prod_q} + (64'sd1 <<< (msh - 6'd1));
    wire signed [63:0] mres = mrnd >>> msh;
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [51:0] mres_s = mres[51:0];

    wire signed [35:0] vm_raw = V6 - mres_v - i_d4_l;
    wire signed [35:0] vm     = vm_raw < VOL ? VOL : vm_raw > VOH ? VOH : vm_raw;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        case (st)
            S_A: begin ma = i_my; mb = KMY_M; msh = KMY_S; end
            S_B: begin ma = d; mb = mute_l ? KC103M_M : KC103_M; msh = mute_l ? KC103M_S : KC103_S; end
            S_C: begin ma = d; mb = mute_l ? KPADM_M : KPAD_M; msh = mute_l ? KPADM_S : KPAD_S; end
            S_D: begin ma = acc; mb = KSND_M; msh = KSND_S; end
            S_DB: begin ma = acc_b; mb = KSNDB_M; msh = KSNDB_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        sample <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0; n <= 4'd0; c103 <= 52'sd0; acc <= 36'sd0; acc_b <= 36'sd0;
            d <= 36'sd0; mute_l <= 1'b0; i_d4_l <= 36'sd0; padr_l <= 36'sd0;
            snd <= 16'sd0; snd_b <= 16'sd0; v_mix <= 36'sd0; v_pad <= 36'sd0;
        end else if (mul_st && !ph) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (go) begin mute_l <= mute; i_d4_l <= i_d4; padr_l <= padr; st <= S_A; end
                S_A: begin
                    v_mix <= vm;
                    d     <= vm - c103_s;
                    st    <= S_B;
                end
                S_B: begin c103 <= c103 + mres_s; st <= S_C; end
                S_C: begin
                    v_pad <= mres_v;
                    acc   <= acc + mres_v;
                    acc_b <= acc_b + padr_l;
                    if (n == DECIM - 4'd1) begin n <= 4'd0; st <= S_D; end
                    else begin n <= n + 4'd1; st <= S_IDLE; end
                end
                S_D: begin
                    snd    <= mres > 64'sd32767 ? 16'sd32767 :
                              mres < -64'sd32768 ? 16'sh8000 : mres[15:0];
                    st     <= S_DB;
                end
                S_DB: begin
                    snd_b  <= mres > 64'sd32767 ? 16'sd32767 :
                              mres < -64'sd32768 ? 16'sh8000 : mres[15:0];
                    sample <= 1'b1;
                    st     <= S_E;
                end
                S_E: begin acc <= 36'sd0; acc_b <= 36'sd0; st <= S_IDLE; end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
