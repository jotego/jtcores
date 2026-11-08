// SPDX-License-Identifier: GPL-3.0-or-later
// Sound board 96598-P, as far as it is built (docs/SOUND_LOGIC.md):
// the D-4/7 control gates, MY CAR SOUND (D-3/7, jtmonacogp_snd_d3.v), the
// D-4/7 noise source, skid tone and EXTEND beep (jtmonacogp_snd_noise.v),
// the explosion (jtmonacogp_snd_expl.v), the other cars (D-6/7 and D-7/7,
// jtmonacogp_snd_d67.v), the rescue car's siren and the back sound (D-2/7,
// jtmonacogp_snd_d2.v, with the other cars' back path), the slip-zone
// sound (D-1/7, jtmonacogp_snd_d1.v, on the D-4 S2688's noise), the
// hi-score tune (D-5/7, jtmonacogp_snd_d5.v, whose alarm line un-mutes
// SOUND OUT while it plays) and the mixer and SOUND OUT
// (jtmonacogp_snd_mix.v).
//
// The analog circuits are stepped at 480 kHz: one step every 100 clocks of
// the 48 MHz clk. The step's inputs are taken at its start and held through
// it, so the result does not depend on when an input changes inside a step.
// Outputs: pad 13 (SOUND OUT, `snd`) and D-2's pad R (BACK SOUND OUT,
// `snd_b`, for the cabinet's back speaker) as 16-bit samples at 48 kHz,
// the mean of ten steps, with a one-clock `sample` pulse.
module jtmonacogp_sound(
    input                clk,      // 48 MHz
    input                rst,
    // from the logic boards
    input          [3:0] acce,     // S-ACCE D..A (sheet F; bit 0 = A)
    input                s_acc1_n, // /S-ACC1 (sheet F)
    input                coin_in_n,// /COIN IN (sheet A)
    input                game_n,   // /GAME (sheet A)
    input                shift,    // SHIFT (sheet F), high = high gear
    input                nonroad_slip_n, // /NON ROAD & POOL SLIP (sheet F)
    input                slip_n,   // /SLIPZONE (sheet F pad AX) on pad J, SLIP ZONE
    input                excp,     // EX.CP (sheet A pad A29, pad 14)
    input                f_sound_n,// /F-SOUND (sheet H pad A19, pad C), sampled every clock
    input                rescue_cp_n, // /RESCUE CP (sheet M IC18, pad P)
    input                explo_loud, // DIP SW. 2 contact 2-15 closed (R423)
    input                back_mix, // DIP SW. 2: the back sound's contact (R424) closed
    input                hiscore_n,// HI SCORE (sheet A /HISCORE, pad AF), D-5 pad 3
    input                mute_in,  // MUTE (sheet A pad A26), D-5 IC35 pin 6
    // D-5's PROM (prm40.ic21)
    output         [4:0] prom_addr_d5,
    input          [7:0] prom_data_d5,
    output signed [15:0] snd,
    output signed [15:0] snd_b,
    output               sample,
    // test views: the gates as held for the current step
    output reg           my_car_on,
    output reg           shift_a,
    output reg           mute,
    output reg           explo_t,  // IC60 a: explosion trigger, 555 enable
    output reg           skid_on,  // 7432 pin 6: the skid 555's RES
    output               alarm     // D-5 IC35 pin 4 (D-4 IC67 pin 10)
);
    localparam [6:0] STEP_LAST = 7'd99;   // 100 clocks a step: 48 MHz / 480 kHz

    // ---- D-4/7 control gates (IC68 inverters, IC60 7402, 7432, IC67)
    wire coin_in = ~coin_in_n;
    wire game    = ~game_n;
    wire g60a    = ~(s_acc1_n | game_n);
    wire g60b    = ~(g60a | coin_in_n);          // MY CAR SOUND ON
    wire g60c    = ~(coin_in_n | game);
    wire g60d    = ~(g60c | ~shift);             // SHIFT A
    wire g32     = g60a | ~nonroad_slip_n;
    // D-5's alarm as its last step left it
    wire g67     = coin_in | alarm;              // low: IC57 shunts SOUND OUT

    reg  [6:0] cnt;
    reg  [3:0] acc_l;
    reg        excp_l, resc_l, back_l, slip_l, hs_l, mi_l;
    reg        tick;
    always @(posedge clk) begin
        tick <= 1'b0;
        if (rst) begin
            cnt <= 7'd0; acc_l <= 4'd0; excp_l <= 1'b0; resc_l <= 1'b0; back_l <= 1'b0;
            slip_l <= 1'b1; hs_l <= 1'b1; mi_l <= 1'b0;
            {my_car_on, shift_a, mute, explo_t, skid_on} <= 5'd0;
        end else begin
            cnt <= cnt == STEP_LAST ? 7'd0 : cnt + 7'd1;
            if (cnt == STEP_LAST) begin
                acc_l     <= acce;
                excp_l    <= excp;
                resc_l    <= ~rescue_cp_n;
                back_l    <= back_mix;
                slip_l    <= slip_n;
                hs_l      <= hiscore_n;
                mi_l      <= mute_in;
                my_car_on <= g60b;
                shift_a   <= g60d;
                mute      <= ~g67;
                explo_t   <= g60a;
                skid_on   <= g32;
                tick      <= 1'b1;
            end
        end
    end

    wire signed [35:0] i_my;
    wire               d3_done;
    jtmonacogp_snd_d3 u_d3(
        .clk(clk),.rst(rst),.tick(tick),.acc(acc_l),.shift_a(shift_a),.sound_on(my_car_on),
        .i_mix(i_my),.done(d3_done),
        .v_lag(),.v_cv(),.v_o1(),.v_o2(),.v_o3(),.v_c1(),.v_c2(),.v_c3(),
        .v_con(),.v_mcin(),.v_mco());

    // D-4 sources: the noise module computes the noise amplifier first,
    // then the explosion runs on its output while the skid tone and EXTEND
    // finish
    wire signed [35:0] namp, i_sk, i401;
    wire               namp_rdy, n_done, e_done, nbit;
    jtmonacogp_snd_noise u_noise(
        .clk(clk),.rst(rst),.tick(tick),.skid_on(skid_on),.excp(excp_l),
        .namp(namp),.namp_rdy(namp_rdy),.i_sk(i_sk),.done(n_done),.nbit(nbit),
        .v_noise(),.v_tri(),.v_o63d(),.v_ctl(),.v_c89(),.v_q555());
    jtmonacogp_snd_expl u_expl(
        .clk(clk),.rst(rst),.go(namp_rdy),.t(explo_t),.loud(explo_loud),.namp(namp),
        .i401(i401),.done(e_done),
        .v_q61a(),.v_q61b(),.v_expo(),.v_bpu(),.v_bpl(),.v_envu(),.v_envl(),.v_conu(),
        .v_conl(),.v_mciu(),.v_mcil(),.v_mcou(),.v_mcol());

    // D-6/D-7: the other cars; S-ACCE as held for the step, pad C over the
    // clocks before it. R109 (car 1's CONTROL bias) as drawn unless the
    // build defines MONACOGP_R109 (1 = 3.3K, 2 = 33K): an option for Aldo,
    // not a reading (docs/sound/OTHER_CAR_COMPARE.md).
`ifdef MONACOGP_R109
    localparam R109_OPT = `MONACOGP_R109;
`else
    localparam R109_OPT = 0;
`endif
    wire signed [35:0] i_mf, i_mb;
    wire               o_done;
    jtmonacogp_snd_d67 #(.R109(R109_OPT)) u_d67(
        .clk(clk),.rst(rst),.tick(tick),.acc(acc_l),.fs_n(f_sound_n),
        .i_mf(i_mf),.i_mb(i_mb),.done(o_done),.v_front(),.v_r6(),
        .v_feed(),.v_r14(),.v_r28(),.v_u1(),.v_u2(),.v_con20(),.v_con19(),.v_con34(),
        .v_con33(),.v_cv1(),.v_cv2(),.v_q59a(),.v_q59b(),.v_q58(),.v_c292(),.v_c2913(),
        .v_o1(),.v_o2(),.v_o3(),.v_con1(),.v_con2(),.v_o1b(),.v_snd1(),.v_snd2());

    // D-2: pad P as held for the step; BACK OTHER CAR is the other cars'
    // back current of the previous step (i_mb holds it until they finish
    // this one); BACK SOUND STB. is sunk with SOUND OUT's mute
    wire signed [35:0] i_d2, padr;
    wire               r_done;
    jtmonacogp_snd_d2 u_d2(
        .clk(clk),.rst(rst),.start(tick),.resc(resc_l),.mute(mute),.dip_back(back_l),
        .i_bk(i_mb),.i_mix(i_d2),.padr(padr),.done(r_done),
        .v_env_r(),.v_env_f(),.v_con41(),.v_con45(),.v_mc41o(),.v_mc45o(),.v_o40_7(),
        .v_z(),.v_o44_7(),.v_o42_1(),.v_o43_7(),.v_i410(),.v_i424(),.v_o42_8(),
        .v_o43_14(),.v_o43_1(),.v_o44_14(),.v_saw(),.v_o40_1(),.v_o555());

    // D-1: pad J as held for the step; the S2688's bit of this step from
    // the noise module
    wire signed [35:0] i_d1;
    wire               s_done;
    jtmonacogp_snd_d1 u_d1(
        .clk(clk),.rst(rst),.start(tick),.noise(nbit),.slip_n(slip_l),
        .i_mix(i_d1),.done(s_done),
        .v_c63(),.v_o8(),.v_na(),.v_o1(),.v_o7(),.v_sw());

    // D-5: HI SCORE and MUTE as held for the step
    wire signed [35:0] i_d5;
    wire               t_done;
    jtmonacogp_snd_d5 u_d5(
        .clk(clk),.rst(rst),.start(tick),.hiscore_n(hs_l),.mute(mi_l),
        .prom_addr_d5(prom_addr_d5),.prom_data_d5(prom_data_d5),
        .i_mix(i_d5),.alarm(alarm),.done(t_done),
        .v_lfo(),.v_cvu(),.v_cvl(),.v_sawu(),.v_sawl(),.v_mix(),.v_lp(),.v_hp(),
        .v_env(),.v_con(),.v_mco(),.v_addr(),.v_cnt(),.v_q123(),.v_clk());

    // the mixer steps once D-3, the noise module, the explosion, the other
    // cars, D-2, D-1 and D-5 are done
    reg  [6:0] dn;
    reg        mix_go;
    wire [6:0] dn_n = dn | {t_done, s_done, r_done, o_done, d3_done, n_done, e_done};
    always @(posedge clk) begin
        mix_go <= 1'b0;
        if (rst || tick) dn <= 7'd0;
        else if (dn_n == 7'b1111111) begin dn <= 7'd0; mix_go <= 1'b1; end
        else dn <= dn_n;
    end

    // the D-4 sources' currents, the other cars' R409 current, D-2's R410
    // and R424 currents, D-1's R412 current and D-5's R408 current are all
    // times R414
    jtmonacogp_snd_mix u_mix(
        .clk(clk),.rst(rst),.go(mix_go),.i_my(i_my),.i_d4(i_sk + i401 + i_mf + i_d2 + i_d1 + i_d5),
        .padr(padr),.mute(mute),.snd(snd),.snd_b(snd_b),.sample(sample),.v_mix(),.v_pad());
endmodule
