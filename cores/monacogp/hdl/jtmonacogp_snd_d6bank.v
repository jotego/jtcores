// SPDX-License-Identifier: GPL-3.0-or-later
// Sound sheet D-6/7 of board 96598-P: one OTHER CAR SOUND bank
// (docs/trace/SOUND_D6_TRACE.md; model and checks: docs/SOUND_LOGIC.md).
//
// Three integrator / Schmitt-comparator cells as on D-3 (same values and
// arithmetic as jtmonacogp_snd_d3.v), their rate set by CAR CON (`cv`) and
// their comparators referred to D-6's own half-rail (`r6`). Cell 1 drives
// the bank MC3340's CONTROL through 22 uF against its bias divider (NO = 1:
// R108 10K / R109 330; NO = 2: R80 10K / R81 3.3K) and the pin's own source;
// cells 2 and 3 reach its input through MA150s, the 10K bus and 10 uF, as
// on D-3. Output: the MC3340's unloaded output `mco` (its loading by the two
// D-7 inputs is jtmonacogp_snd_d7car's), and `svp`, the sum of the three
// comparators' + inputs (their 51K load on the half-rail).
// One step per `start`; `done` after about 75 clocks.
// R109 (bank 1 only) is an option, not a reading: 0 = .33K as drawn (the
// default), 1 = 3.3K (R81's value), 2 = 33K (Monza's redraw); see
// docs/sound/OTHER_CAR_COMPARE.md.
// tests/sound/d67_fixed.py (BankFixed) is the same arithmetic.
module jtmonacogp_snd_d6bank #(parameter NO = 1, parameter R109 = 0) (
    input                    clk,
    input                    rst,
    input                    start,
    input  signed     [35:0] cv,       // CAR CON, held during the step
    input  signed     [35:0] r6,       // D-6 half-rail, held during the step
    output reg signed [35:0] mco,
    output reg signed [35:0] svp,
    output reg               done,
    // test views
    output reg signed [35:0] v_o1, v_o2, v_o3, v_con, v_mcin
);
    `include "jtmonacogp_snd_d67.vh"

    localparam signed [26:0] KCON1X_M = R109 == 1 ? KCON1R1_M : R109 == 2 ? KCON1R2_M : KCON1_M;
    localparam        [5:0]  KCON1X_S = R109 == 1 ? KCON1R1_S : R109 == 2 ? KCON1R2_S : KCON1_S;
    localparam signed [26:0] KCON_M = NO == 1 ? KCON1X_M : KCON2_M;
    localparam        [5:0]  KCON_S = NO == 1 ? KCON1X_S : KCON2_S;
    localparam signed [51:0] CON_I0 = NO == 1 ? CON_I0_1 : CON_I0_2;

    localparam [4:0]
        S_IDLE=0, S_R=1,  S_C0=2,  S_C1=3,  S_C2=4,  S_C3=5,  S_K0=6,  S_K1=7,
        S_B0=8,   S_B1=9, S_B2=10, S_B3=11, S_B4=12, S_B5=13, S_B6=14, S_B7=15,
        S_W=16,   S_I0=17, S_I1=18;
    localparam [1:0] T_NONE=0, TSOFT=1, TVDROP=2;

    reg [4:0] st;
    reg [1:0] ci;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_R, S_C0, S_C1, S_C2, S_K1, S_B1, S_B3, S_B6, S_I0, S_I1: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    // ---- state
    reg signed [51:0] cap[0:2];
    reg signed [35:0] cmp[0:2];
    reg        [2:0]  tr;
    reg signed [51:0] qcon, q64;
    reg signed [35:0] inl;
    // ---- step registers
    reg signed [51:0] dl;
    reg signed [35:0] r6k, vout, vplus, o1, o2, o3, con, hi_v, dneg, vth, top, bus, mcin;
    reg               vneg, mc_go;
    reg signed [35:0] mc_o, mc_i;

    wire signed [35:0] vm    = cv >>> 1;
    wire signed [35:0] q64_s = q64[51:16];
    wire signed [35:0] qcon_s = qcon[51:16];

    function signed [35:0] clamp(input signed [35:0] x, input signed [35:0] lo_, input signed [35:0] hi__);
        clamp = x < lo_ ? lo_ : x > hi__ ? hi__ : x;
    endfunction

    // ---- table ROM (bus tables)
    reg  [1:0]         tsel;
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
            TSOFT:  begin t_base=T_SOFT_BASE;  t_n=T_SOFT_N;  t_f=T_SOFT_F;  t_x0=T_SOFT_X0;  end
            default:begin t_base=T_VDROP_BASE; t_n=T_VDROP_N; t_f=T_VDROP_F; t_x0=T_VDROP_X0; end
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
        rq0 <= rom_bus[ra];
        rq1 <= rom_bus[ra1];
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
    wire signed [35:0] mres_v = mres[35:0];
    wire signed [51:0] mres_s = mres[51:0];
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres_v;

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
    wire signed [35:0] cmp_up = cmp_c + SLEW > VOH_C + CMP_OVER ? VOH_C + CMP_OVER : cmp_c + SLEW;
    wire signed [35:0] cmp_dn = cmp_c - SLEW < VOL_C - CMP_OVER ? VOL_C - CMP_OVER : cmp_c - SLEW;
    wire signed [35:0] cmp_n  = vplus > vout ? cmp_up : cmp_dn;
    wire signed [35:0] vdiff  = top - vth;

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tsel = T_NONE; tx = 36'sd0;
        case (st)
            S_R:  begin ma = r6; mb = KR6_M; msh = KR6_S; end
            S_C0: begin ma = cv - vm; mb = ka_m; msh = ka_s; end
            S_C1: begin ma = vm - VCE; mb = kb_m; msh = kb_s; end
            S_C2: begin ma = vo_c; mb = KSCH_M; msh = KSCH_S; end
            S_K1: begin ma = con; mb = KCON_M; msh = KCON_S; end
            S_B1: begin tsel = TSOFT; tx = -dneg; ma = q64_s + MC_VB; mb = KTH_M; msh = KTH_S; end
            S_B3: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_B4: begin tsel = TVDROP; tx = vdiff; end
            S_B6: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_I0: begin ma = mcin - MC_VB; mb = KTH_M; msh = KTH_S; end
            S_I1: begin ma = mc_i; mb = K64_M; msh = K64_S; end
            default:;
        endcase
    end

    wire mc_done;
    wire signed [35:0] mc_mco, mc_iin;
    jtmonacogp_snd_mc3340 u_mc(
        .clk(clk), .rst(rst), .start(mc_go), .mcin(mcin), .con(con),
        .mco(mc_mco), .iin(mc_iin), .done(mc_done));

    integer k;
    always @(posedge clk) begin
        done  <= 1'b0;
        mc_go <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ci <= 2'd0; ph <= 1'b0;
            for (k = 0; k < 3; k = k + 1) begin
                cap[k] <= 52'sd0;
                cmp[k] <= VOL_C - CMP_OVER;
            end
            tr <= 3'd0; qcon <= 52'sd0; q64 <= 52'sd0; inl <= 36'sd0;
            mco <= 36'sd0; svp <= 36'sd0;
            {v_o1, v_o2, v_o3, v_con, v_mcin} <= 0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) st <= S_R;
                S_R: begin r6k <= mres_v; ci <= 2'd0; svp <= 36'sd0; st <= S_C0; end
                // cells, as on D-3
                S_C0: begin dl <= mres_s; st <= S_C1; end
                S_C1: begin
                    cap[ci] <= cap[ci] + dl - (tr[ci] ? mres_s : 52'sd0);
                    st <= S_C2;
                end
                S_C2: begin
                    vplus <= r6k + mres_v;
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
                    svp     <= svp + vplus;
                    case (ci)
                        2'd0: o1 <= vout;
                        2'd1: o2 <= vout;
                        default: o3 <= vout;
                    endcase
                    if (ci == 2'd2) st <= S_K0;
                    else begin ci <= ci + 2'd1; st <= S_C0; end
                end
                // CONTROL node
                S_K0: begin con <= o1 - qcon_s; st <= S_K1; end
                S_K1: begin qcon <= qcon + mres_s - CON_I0; st <= S_B0; end
                // the bus, as on D-3
                S_B0: begin
                    if (o2 >= o3) begin hi_v <= o2; dneg <= o3 - o2; end
                    else          begin hi_v <= o3; dneg <= o2 - o3; end
                    st <= S_B1;
                end
                S_B1: begin vth <= mres_v - inl; st <= S_B2; end
                S_B2: st <= S_B3;
                S_B3: begin top <= hi_v + tval; st <= S_B4; end
                S_B4: begin vneg <= vdiff <= 0; st <= S_B5; end
                S_B5: st <= S_B6;
                S_B6: begin bus <= vneg ? vth : top - tval; st <= S_B7; end
                S_B7: begin mcin <= bus - q64_s; mc_go <= 1'b1; st <= S_W; end
                S_W:  if (mc_done) begin mc_o <= mc_mco; mc_i <= mc_iin; st <= S_I0; end
                S_I0: begin inl <= mc_i - mres_v; st <= S_I1; end
                S_I1: begin
                    q64 <= q64 + mres_s;
                    mco <= mc_o;
                    v_o1 <= o1; v_o2 <= o2; v_o3 <= o3; v_con <= con; v_mcin <= mcin;
                    done <= 1'b1;
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
