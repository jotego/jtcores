// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-7/7 of board 96598-P: one other car's two MC3340s (front
// and back) and their output networks (docs/trace/SOUND_D7_TRACE.md; model
// and checks: docs/SOUND_LOGIC.md). Car 1: IC20 (front) and IC19 (back);
// car 2: IC34 and IC33.
//
// The bank's output (`mco`, unloaded, through the MC3340's 220 ohm) feeds
// both inputs through 2.2 uF; the node is solved with each input's linear
// part and the rest of its current, which moves a sixteenth of the way to
// its new value each step (taken whole, the input's knee made the node
// flip between steps). Each output
// goes through 2.2 uF, the IC25 4016 (on while `on`: the car's reset pulse
// is low), the 10K / 10K bias, 2.2 uF and the summing resistor: R207 / R204
// 10K to IC32 b (front), R220 / R217 51K to D-2 (back). Outputs: `ef`, the
// front current times R426 (33K), and `eb`, the back current times 51K.
// One step per `start`; `done` after about 70 clocks.
// tests/sound/d67_fixed.py (PathFixed, D67Fixed) is the same arithmetic.
module jtmonacogp_snd_d7car(
    input                    clk,
    input                    rst,
    input                    start,
    input  signed     [35:0] mco,      // the bank's output, previous step
    input  signed     [35:0] conf,     // front MC3340 CONTROL, previous step
    input  signed     [35:0] conb,     // back MC3340 CONTROL, previous step
    input                    on,       // IC25 on (reset pulse low), previous step
    output reg signed [35:0] ef,
    output reg signed [35:0] eb,
    output reg               done,
    // test views
    output reg signed [35:0] v_node, v_mf, v_mb, v_bf, v_bb
);
    `include "jtmonacogp_snd_d67.vh"

    localparam [4:0]
        S_IDLE=0, S_A0=1, S_A1=2, S_A2=3, S_A3=4, S_M=5, S_W=6,
        S_I0=7, S_I1=8, S_I2=9, S_I3=10,
        S_O0=11, S_O1=12, S_O2=13, S_O3=14, S_O4=15, S_O5=16;

    reg [4:0] st;
    reg       ph;
    reg       side;                   // output network: 0 front, 1 back
    reg       mul_st;
    always @* case (st)
        S_A0, S_A1, S_A2, S_A3, S_I0, S_I1, S_I2, S_I3, S_O0, S_O1, S_O2, S_O4, S_O5:
            mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    // ---- state (index 0 front, 1 back)
    reg signed [51:0] qin[0:1], qa[0:1], qb[0:1];
    reg signed [35:0] inl[0:1];       // rest of the IN current, relaxed
    reg signed [35:0] dn0, dn1;       // its new value, this step
    wire signed [36:0] dd0 = {dn0[35], dn0} - {inl[0][35], inl[0]};
    wire signed [36:0] dd1 = {dn1[35], dn1} - {inl[1][35], inl[1]};
    // ---- step registers
    reg signed [35:0] af, nd_a, node, mcin_f, mcin_b, mf, mb_, iif, iib, bt, b, e;
    reg               go, got_f, got_b;

    wire signed [35:0] qin0_s = qin[0][51:16];
    wire signed [35:0] qin1_s = qin[1][51:16];
    wire signed [35:0] qa_s   = qa[side][51:16];
    wire signed [35:0] qb_s   = qb[side][51:16];
    wire signed [35:0] mo     = side ? mb_ : mf;

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

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        case (st)
            S_A0: begin ma = qin0_s + MC_VB; mb = KTH_M; msh = KTH_S; end
            S_A1: begin ma = qin1_s + MC_VB; mb = KTH_M; msh = KTH_S; end
            S_A2: begin ma = mco; mb = KN1_M; msh = KN1_S; end
            S_A3: begin ma = af; mb = KN2_M; msh = KN2_S; end
            S_I0: begin ma = mcin_f - MC_VB; mb = KTH_M; msh = KTH_S; end
            S_I1: begin ma = iif; mb = KCIN_M; msh = KCIN_S; end
            S_I2: begin ma = mcin_b - MC_VB; mb = KTH_M; msh = KTH_S; end
            S_I3: begin ma = iib; mb = KCIN_M; msh = KCIN_S; end
            S_O0: begin ma = mo - qa_s; mb = side ? KBBA_M : KBFA_M; msh = side ? KBBA_S : KBFA_S; end
            S_O1: begin
                ma = qb_s;
                if (side) begin mb = on ? KBBB_M : KBBBO_M; msh = on ? KBBB_S : KBBBO_S; end
                else      begin mb = on ? KBFB_M : KBFBO_M; msh = on ? KBFB_S : KBFBO_S; end
            end
            S_O2: begin ma = mo - qa_s - b; mb = KQA_M; msh = KQA_S; end
            S_O4: begin ma = e; mb = side ? KQBB_M : KQBF_M; msh = side ? KQBB_S : KQBF_S; end
            S_O5: begin ma = e; mb = KIF_M; msh = KIF_S; end
            default:;
        endcase
    end

    wire               df, db;
    wire signed [35:0] mfo, mfi, mbo, mbi;
    jtmonacogp_snd_mc3340 u_front(
        .clk(clk), .rst(rst), .start(go), .mcin(mcin_f), .con(conf),
        .mco(mfo), .iin(mfi), .done(df));
    jtmonacogp_snd_mc3340 u_back(
        .clk(clk), .rst(rst), .start(go), .mcin(mcin_b), .con(conb),
        .mco(mbo), .iin(mbi), .done(db));

    integer k;
    always @(posedge clk) begin
        done <= 1'b0;
        go   <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0; side <= 1'b0;
            for (k = 0; k < 2; k = k + 1) begin
                qin[k] <= 52'sd0; qa[k] <= 52'sd0; qb[k] <= 52'sd0; inl[k] <= 36'sd0;
            end
            ef <= 36'sd0; eb <= 36'sd0; dn0 <= 36'sd0; dn1 <= 36'sd0;
            {v_node, v_mf, v_mb, v_bf, v_bb} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) st <= S_A0;
                // the node at both inputs
                S_A0: begin af <= inl[0] - mres_v; st <= S_A1; end
                S_A1: begin af <= af + inl[1] - mres_v; st <= S_A2; end
                S_A2: begin nd_a <= mres_v; st <= S_A3; end
                S_A3: begin node <= nd_a - mres_v; st <= S_M; end
                S_M: begin
                    mcin_f <= node - qin0_s;
                    mcin_b <= node - qin1_s;
                    go <= 1'b1; got_f <= 1'b0; got_b <= 1'b0;
                    st <= S_W;
                end
                S_W: begin
                    if (df) begin mf  <= mfo; iif <= mfi; got_f <= 1'b1; end
                    if (db) begin mb_ <= mbo; iib <= mbi; got_b <= 1'b1; end
                    if ((got_f || df) && (got_b || db)) st <= S_I0;
                end
                // input currents
                S_I0: begin dn0 <= iif - mres_v; st <= S_I1; end
                S_I1: begin
                    qin[0] <= qin[0] + mres_s;
                    inl[0] <= inl[0] + $signed(dd0[36:4]);
                    st <= S_I2;
                end
                S_I2: begin dn1 <= iib - mres_v; st <= S_I3; end
                S_I3: begin
                    qin[1] <= qin[1] + mres_s;
                    inl[1] <= inl[1] + $signed(dd1[36:4]);
                    side <= 1'b0; st <= S_O0;
                end
                // output networks, front then back
                S_O0: begin bt <= on ? mres_v : 36'sd0; st <= S_O1; end
                S_O1: begin
                    b <= bt + mres_v + (side ? (on ? BB_ON : BB_OFF) : (on ? BF_ON : BF_OFF));
                    st <= S_O2;
                end
                S_O2: begin
                    if (on) qa[side] <= qa[side] + mres_s;
                    e <= b - qb_s - V6;
                    st <= S_O4;
                end
                S_O4: begin
                    qb[side] <= qb[side] + mres_s;
                    if (side) begin
                        eb <= e; v_bb <= b;
                        v_node <= node; v_mf <= mf; v_mb <= mb_;
                        done <= 1'b1;
                        st <= S_IDLE;
                    end else st <= S_O5;
                end
                S_O5: begin ef <= mres_v; v_bf <= b; side <= 1'b1; st <= S_O0; end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
