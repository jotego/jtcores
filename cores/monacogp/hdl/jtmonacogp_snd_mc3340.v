// SPDX-License-Identifier: GPL-3.0-or-later
// One MC3340 attenuator of the sound board, evaluated on request: the
// separable table model of tests/sound/mc3340_fit.py, in the fixed point of
// the sound modules (2^28 per volt). For the D-6/D-7 other-car sounds
// (docs/SOUND_LOGIC.md); the D-3 engine has the same arithmetic inline.
//
// A `start` pulse with `mcin` (pin 1) and `con` (pin 2) held computes the
// unloaded output `mco` and the input current `iin` (times the D-3 bus's
// Thevenin resistance, see tests/sound/d67_fixed.py) and gives a one-clock
// `done` about 28 clocks later. Own table ROM and multiplier.
// tests/sound/d67_fixed.py (mc3340) is the same arithmetic.
module jtmonacogp_snd_mc3340(
    input                    clk,
    input                    rst,
    input                    start,
    input  signed     [35:0] mcin,
    input  signed     [35:0] con,
    output reg signed [35:0] mco,
    output reg signed [35:0] iin,
    output reg               done
);
    `include "jtmonacogp_snd_d67.vh"

    localparam [4:0]
        S_IDLE=0, S_0=1, S_1=2, S_2=3, S_3=4, S_4=5, S_5=6, S_6=7, S_7=8,
        S_8=9, S_9=10, S_10=11, S_11=12, S_12=13, S_13=14, S_14=15, S_15=16;
    localparam [3:0]
        T_NONE=0, TG=1, TVO0=2, TLO=3, TVON=4, TVONW=5, TH=6, TIB=7, TW=8,
        TIC=9, TS=10;

    reg [4:0] st;
    reg       ph;
    reg       mul_st;
    always @* case (st)
        S_2, S_3, S_4, S_5, S_6, S_7, S_8, S_9, S_10, S_11, S_12, S_15: mul_st = 1'b1;
        default: mul_st = 1'b0;
    endcase
    wire adv = !mul_st || ph;

    reg signed [35:0] g, vo0, lo, von, vonw, h, ib, w, ic, heff, xs;
    reg               ic_ext, s_ext;

    // ---- table ROM: issue in one state, the two entries two states later
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
            TG:     begin t_base=T_G_BASE;    t_n=T_G_N;    t_f=T_G_F;    t_x0=T_G_X0;    end
            TVO0:   begin t_base=T_VO0_BASE;  t_n=T_VO0_N;  t_f=T_VO0_F;  t_x0=T_VO0_X0;  end
            TLO:    begin t_base=T_LO_BASE;   t_n=T_LO_N;   t_f=T_LO_F;   t_x0=T_LO_X0;   end
            TVON:   begin t_base=T_VON_BASE;  t_n=T_VON_N;  t_f=T_VON_F;  t_x0=T_VON_X0;  end
            TVONW:  begin t_base=T_VONW_BASE; t_n=T_VONW_N; t_f=T_VONW_F; t_x0=T_VONW_X0; end
            TH:     begin t_base=T_H_BASE;    t_n=T_H_N;    t_f=T_H_F;    t_x0=T_H_X0;    end
            TIB:    begin t_base=T_IB_BASE;   t_n=T_IB_N;   t_f=T_IB_F;   t_x0=T_IB_X0;   end
            TW:     begin t_base=T_W_BASE;    t_n=T_W_N;    t_f=T_W_F;    t_x0=T_W_X0;    end
            TIC:    begin t_base=T_IC_BASE;   t_n=T_IC_N;   t_f=T_IC_F;   t_x0=T_IC_X0;   end
            default:begin t_base=T_S_BASE;    t_n=T_S_N;    t_f=T_S_F;    t_x0=T_S_X0;    end
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
        rq0 <= rom_mc[ra];
        rq1 <= rom_mc[ra1];
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
    wire signed [35:0] tdel = rq1 - rq0;
    wire signed [35:0] tval = rq0 + mres_v;
    wire signed [35:0] u    = mcin - von;
    wire signed [35:0] mo   = lo + (s_ext ? xs : tval);

    always @* begin
        ma = 36'sd0; mb = 27'sd0; msh = 6'd1;
        tsel = T_NONE; tx = 36'sd0;
        case (st)
            S_0:  begin tsel = TG;    tx = con; end
            S_1:  begin tsel = TVO0;  tx = con; end
            S_2:  begin tsel = TLO;   tx = con;  ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_3:  begin tsel = TVON;  tx = con;  ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_4:  begin tsel = TVONW; tx = con;  ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_5:  begin tsel = TH;    tx = mcin; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_6:  begin tsel = TIB;   tx = mcin; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_7:  begin tsel = TW;    tx = mcin - vonw; ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_8:  begin tsel = TIC;   tx = u;    ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_9:  begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_10: if (ic_ext) begin ma = u - U_MAX; mb = KICS_M; msh = KICS_S; end
                  else begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            S_11: begin ma = H_LOW - h; mb = w[29:3]; msh = 6'd25; end
            S_12: begin ma = heff; mb = g[29:3]; msh = 6'd25; end
            S_13: begin tsel = TS; tx = xs; end
            S_15: begin ma = tdel; mb = {2'b0, frb}; msh = {1'b0, ffb}; end
            default:;
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ph <= 1'b0;
            mco <= 36'sd0; iin <= 36'sd0;
        end else if (!adv) begin
            ph <= 1'b1;
        end else begin
            ph <= 1'b0;
            case (st)
                S_IDLE: if (start) st <= S_0;
                S_0:  st <= S_1;
                S_1:  st <= S_2;
                S_2:  begin g    <= tval; st <= S_3; end
                S_3:  begin vo0  <= tval; st <= S_4; end
                S_4:  begin lo   <= tval; st <= S_5; end
                S_5:  begin von  <= tval; st <= S_6; end
                S_6:  begin vonw <= tval; st <= S_7; end
                S_7:  begin h    <= tval; st <= S_8; end
                S_8:  begin ib   <= tval; ic_ext <= u > U_MAX; st <= S_9; end
                S_9:  begin w    <= tval; st <= S_10; end
                S_10: begin ic   <= ic_ext ? IC_LAST + mres_v : tval; st <= S_11; end
                S_11: begin heff <= h + mres_v; st <= S_12; end
                S_12: begin xs   <= vo0 - mres_v - lo; st <= S_13; end
                S_13: begin s_ext <= xs >= S_MAX; st <= S_14; end
                S_14: st <= S_15;
                S_15: begin
                    mco  <= mo > MC_HI ? MC_HI : mo;
                    iin  <= ib + ic;
                    done <= 1'b1;
                    st   <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
