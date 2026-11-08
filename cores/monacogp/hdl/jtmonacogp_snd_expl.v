// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-4/7 of board 96598-P: the explosion (docs/trace/SOUND_D4_TRACE.md;
// docs/SOUND_LOGIC.md).
//
// - The trigger T (IC60 a) fires the 74123s IC61 a and IC69 a on its rising
//   edge; IC61 b fires as IC69's Q falls. Each Q lasts TW_STEPS model steps
//   (47K, 4.7u: about 63 ms); they retrigger.
// - Two bands (jtmonacogp_snd_band.v): about 540 Hz under IC61 a's envelope
//   and about 130 Hz under IC61 b's.
// - IC66 a sums the two MC3340 outputs through C83 1u / R365 150K and
//   C99 1u / 100K, with R400 1M feedback (R423 2M in parallel with DIP SW. 2
//   contact 2-15 closed: `loud`), limited to the LM324's range; its output
//   through C100 10u and R401 220K to the mixer.
// Output: i401, the current in R401 times R414 (22K), 2^28 per volt.
// tests/sound/d4s_fixed.py (ExplFixed) is the same arithmetic in Python and
// generates jtmonacogp_snd_expl.vh.
module jtmonacogp_snd_expl(
    input                    clk,
    input                    rst,
    input                    go,       // the noise amplifier's output is ready
    input                    t,        // IC60 a, held through the step
    input                    loud,     // DIP SW. 2 contact 2-15 closed
    input  signed     [35:0] namp,
    output reg signed [35:0] i401,
    output reg               done,
    // test views, updated once per step
    output reg               v_q61a, v_q61b,
    output reg signed [35:0] v_expo,
    output signed     [35:0] v_bpu, v_bpl, v_envu, v_envl, v_conu, v_conl,
    output signed     [35:0] v_mciu, v_mcil, v_mcou, v_mcol
);
    `include "jtmonacogp_snd_expl.vh"

    localparam [3:0]
        S_IDLE=0, S_W=1, S_E0=2, S_E1=3, S_E2=4, S_E3=5, S_E4=6, S_E5=7,
        S_E6=8, S_E7=9, S_E8=10, S_E9=11, S_E10=12;

    reg [3:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_E1, S_E2, S_E3, S_E4, S_E5, S_E6, S_E7, S_E9, S_E10: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction

    // ---- 74123s
    reg        t_prev;
    reg [15:0] n61a, n69, n61b;
    reg        q61a, q61b, go_b;
    // ---- bands
    wire signed [35:0] mcou, mcol;
    wire               du, dl;
    reg                du_l, dl_l;
    jtmonacogp_snd_band #(.UPPER(1)) u_bu(
        .clk(clk),.rst(rst),.go(go_b),.vsrc(namp),.q(q61a),.mco(mcou),.done(du),
        .v_bp(v_bpu),.v_env(v_envu),.v_con(v_conu),.v_mcin(v_mciu));
    jtmonacogp_snd_band #(.UPPER(0)) u_bl(
        .clk(clk),.rst(rst),.go(go_b),.vsrc(namp),.q(q61b),.mco(mcol),.done(dl),
        .v_bp(v_bpl),.v_env(v_envl),.v_con(v_conl),.v_mcin(v_mcil));
    assign v_mcou = mcou;
    assign v_mcol = mcol;

    // ---- IC66 a
    reg signed [51:0] qu, ql, q100;
    reg signed [35:0] su, sl, vo, vm, tmp, e100;
    wire signed [35:0] qu_s = qu[51:16];
    wire signed [35:0] ql_s = ql[51:16];
    wire signed [35:0] q100_s = q100[51:16];
    wire signed [35:0] vo_r = V6 - (tmp + mres_v);

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
            S_E1:  begin ma = su - V6; mb = loud ? KU_D_M : KU_N_M; msh = loud ? KU_D_S : KU_N_S; end
            S_E2:  begin ma = sl - V6; mb = loud ? KL_D_M : KL_N_M; msh = loud ? KL_D_S : KL_N_S; end
            S_E3:  begin ma = su; mb = loud ? AU_D_M : AU_N_M; msh = loud ? AU_D_S : AU_N_S; end
            S_E4:  begin ma = sl; mb = loud ? AL_D_M : AL_N_M; msh = loud ? AL_D_S : AL_N_S; end
            S_E5:  begin ma = vo; mb = loud ? AF_D_M : AF_N_M; msh = loud ? AF_D_S : AF_N_S; end
            S_E6:  begin ma = su - vm; mb = KQU_M;  msh = KQU_S;  end
            S_E7:  begin ma = sl - vm; mb = KQL_M;  msh = KQL_S;  end
            S_E9:  begin ma = e100;    mb = K100_M; msh = K100_S; end
            S_E10: begin ma = e100;    mb = K401_M; msh = K401_S; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0; go_b <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            t_prev <= 1'b0; n61a <= 16'd0; n69 <= 16'd0; n61b <= 16'd0;
            q61a <= 1'b0; q61b <= 1'b0; du_l <= 1'b0; dl_l <= 1'b0;
            qu <= 52'sd0; ql <= 52'sd0; q100 <= 52'sd0; i401 <= 36'sd0;
            v_q61a <= 1'b0; v_q61b <= 1'b0; v_expo <= 36'sd0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                // the 74123s for this step, then both bands
                S_IDLE: if (go) begin
                    t_prev <= t;
                    if (t && !t_prev) begin
                        q61a <= 1'b1; n61a <= TW_STEPS - 16'd1;
                        n69  <= TW_STEPS - 16'd1;
                        q61b <= n61b != 16'd0;
                        if (n61b != 16'd0) n61b <= n61b - 16'd1;
                    end else begin
                        q61a <= n61a != 16'd0;
                        q61b <= n61b != 16'd0;
                        if (n61a != 16'd0) n61a <= n61a - 16'd1;
                        if (n61b != 16'd0) n61b <= n61b - 16'd1;
                        if (n69 == 16'd1) n61b <= TW_STEPS;
                        if (n69 != 16'd0) n69 <= n69 - 16'd1;
                    end
                    go_b <= 1'b1; du_l <= 1'b0; dl_l <= 1'b0;
                    st <= S_W;
                end
                S_W: begin
                    if (du) du_l <= 1'b1;
                    if (dl) dl_l <= 1'b1;
                    if ((du || du_l) && (dl || dl_l)) st <= S_E0;
                end
                // IC66 a
                S_E0: begin su <= mcou - qu_s; sl <= mcol - ql_s; st <= S_E1; end
                S_E1: begin tmp <= mres_v; st <= S_E2; end
                S_E2: begin
                    vo <= clamp(vo_r, VOL, VOH);
                    if (vo_r >= VOL && vo_r <= VOH) begin vm <= V6; st <= S_E6; end
                    else st <= S_E3;
                end
                S_E3: begin tmp <= mres_v; st <= S_E4; end
                S_E4: begin tmp <= tmp + mres_v; st <= S_E5; end
                S_E5: begin vm <= tmp + mres_v; st <= S_E6; end
                S_E6: begin qu <= qu + mres_s; st <= S_E7; end
                S_E7: begin ql <= ql + mres_s; st <= S_E8; end
                S_E8: begin e100 <= vo - q100_s - V6; st <= S_E9; end
                S_E9: begin q100 <= q100 + mres_s; st <= S_E10; end
                S_E10: begin
                    i401 <= mres_v; done <= 1'b1;
                    v_q61a <= q61a; v_q61b <= q61b; v_expo <= vo;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
