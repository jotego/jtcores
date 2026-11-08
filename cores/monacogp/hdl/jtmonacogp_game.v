// SPDX-License-Identifier: GPL-3.0-or-later
// Monaco GP development core: sheet E timing; sheets A, B, D, F, G, H and M
// connected to each other in the "Connected sheets" view, with stand-ins for
// the cabinet and for sheet I (sheet C is not traced, so the picture is in
// false colours); the sheet G player car at a fixed test position and
// sheets B and D on a test stimulus in the older views; the PROM diagnostic.
module jtmonacogp_game #(
    // 1, for simulation only: one-shot capacitors divided by 1000, the 555's
    // by 100 (one game-timer count in about 0.6 frames)
    parameter integer FAST = 0,
    // 0, for simulation only: no sound board (tests/tb_play.v, whose game
    // would take too long in Icarus with it; tests/tb_play_sound.v has it)
    parameter integer SOUND = 1,
    // 0, for simulation only: no high-score memory, rank latches or score
    // display (sheets I's rank part, K, J); tests/tb_play.v does not check
    // them and runs over the one-hour limit with them. They have their own
    // tests (tb_rank*, tb_leds)
    parameter integer RANK = 1,
    // 1: the Pro Monaco GP board (manual 420-0525): sheet N's bonus circuit,
    // the Pro gates on sheets A, C, F, G, I, K and M, and the display timer,
    // SLOW, BELT and D-EXTEND logic of sheets B, C and D
    // (pro/docs/SHEETS_B_C_D_PRO_LOGIC.md). 0: the original board. On
    // MiSTer the board is chosen by the MRA instead (dipsw[15], below); the
    // parameter is for the simulations, whose DIP switches are 0.
    parameter integer PRO = 0
)(
`include "jtframe_game_ports.inc"
    input jtframe_mem_ports_end
);
    // The one-shot and 555 widths in pixels of 7.1525 MHz are the sheet
    // modules' defaults (drawn values), divided by CS and C555.
    localparam integer CS = FAST ? 1000 : 1, C555 = FAST ? 100 : 1;
    // Pro board (sheets A, B, C, D, F, G, I, K, M, N). One RBF, two games
    // (#89): the Pro MRA's switch default sets dipsw[15] and its DIP page
    // has no entry for it, so it cannot be changed from the OSD; the Monaco
    // GP MRA leaves it 0. JTFRAME does not pass the MRA's core_mod to the
    // game, which is why a hidden DIP bit carries it.
    wire pro = PRO != 0 || dipsw[15];

    wire [8:0] h,v,x,y,hpos,vpos;
    wire hb,vb;
    wire [179:0] prom_addr, diag_addr;
    wire [159:0] prom_q;
    reg loaded = 0,load_error = 0;
    reg [13:0] bytes_loaded = 0;
    wire [4:0] selected;
    wire [3:0] diag_r, diag_g, diag_b, pview_r, pview_g, pview_b, sview_r, sview_g, sview_b,
               gview_r, gview_g, gview_b;
    wire [4:0] d5_addr;
    // OSD "Display" (status bits 15:13): 0 player-car test, 1 PROM bits,
    // 2 timing grid, 3 road and scenery, 4 road and scenery with IC66 read as
    // a NAND (the other reading of the scan, docs/trace/SHEET_D_TRACE.md; the
    // real game shows the AND), 5 connected sheets in sheet C's colours, 6 the
    // same in false colours. 7 shows the player-car test.
    // The release build shows the connected sheets only. With
    // MONACOGP_DEVVIEWS (the tests) the OSD's Display option (status bits
    // 15:13) selects the development displays as before.
`ifdef MONACOGP_DEVVIEWS
    wire [2:0] dview = status[15:13];
    wire show_score = 1'b0, show_gear = 1'b0, show_panel = 1'b0;
`else
    wire [2:0] dview = 3'd5;
    // OSD Display page: "Show Score & Time" (bit 13) and "Show Gear" (bit 14),
    // On by default. The score panel shows only while button 3 is held.
    wire show_score = ~status[13], show_gear = ~status[14], show_panel = ~joystick1[6];
`endif
    wire diag_view = dview == 3'd1 || dview == 3'd2;
    wire grid = dview == 3'd2;
    wire scen_view = dview == 3'd3 || dview == 3'd4;
    wire ic66_nand = dview == 3'd4;
    wire game_view = dview == 3'd5 || dview == 3'd6;
    wire false_colour = dview == 3'd6;

    jtmonacogp_timing u_timing(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.h(h),.v(v),
        .hblank(hb),.vblank(vb),.hs(HS),.vs(VS),
        .x(x),.y(y),.hpos(hpos),.vpos(vpos));
    assign LHBL=~hb;
    assign LVBL=~vb;
    assign rom00_addr = prom_addr[0*9+:9];
    assign rom01_addr = prom_addr[1*9+:9];
    assign rom02_addr = prom_addr[6*9+:9];
    assign rom03_addr = prom_addr[2*9+:9];
    assign rom04_addr = prom_addr[3*9+:9];
    assign rom05_addr = prom_addr[4*9+:9];
    assign rom06_addr = prom_addr[5*9+:9];
    assign rom07_addr = prom_addr[7*9+:9];
    assign rom08_addr = prom_addr[18*9+:5];
    assign rom09_addr = prom_addr[17*9+:5];
    assign rom10_addr = prom_addr[15*9+:9];
    assign rom11_addr = prom_addr[16*9+:9];
    assign rom12_addr = prom_addr[13*9+:9];
    assign rom13_addr = prom_addr[14*9+:9];
    assign rom14_addr = prom_addr[8*9+:9];
    assign rom15_addr = prom_addr[11*9+:9];
    assign rom16_addr = prom_addr[10*9+:9];
    assign rom17_addr = prom_addr[9*9+:9];
    assign rom18_addr = prom_addr[12*9+:9];
    assign rom19_addr = diag_view ? prom_addr[19*9+:5] : d5_addr;
    assign prom_q[0*8+:8] = rom00_data;
    assign prom_q[1*8+:8] = rom01_data;
    assign prom_q[2*8+:8] = rom03_data;
    assign prom_q[3*8+:8] = rom04_data;
    assign prom_q[4*8+:8] = rom05_data;
    assign prom_q[5*8+:8] = rom06_data;
    assign prom_q[6*8+:8] = rom02_data;
    assign prom_q[7*8+:8] = rom07_data;
    assign prom_q[8*8+:8] = rom14_data;
    assign prom_q[9*8+:8] = rom17_data;
    assign prom_q[10*8+:8] = rom16_data;
    assign prom_q[11*8+:8] = rom15_data;
    assign prom_q[12*8+:8] = rom18_data;
    assign prom_q[13*8+:8] = rom12_data;
    assign prom_q[14*8+:8] = rom13_data;
    assign prom_q[15*8+:8] = rom10_data;
    assign prom_q[16*8+:8] = rom11_data;
    assign prom_q[17*8+:8] = rom09_data;
    assign prom_q[18*8+:8] = rom08_data;
    assign prom_q[19*8+:8] = rom19_data;
    // JTFRAME may hold prom_we high between host writes. Count each
    // address once per assertion, including back-to-back address changes.
    reg prom_active = 0;
    reg [21:0] last_prom_addr = 0;
    always @(posedge clk) begin
        prom_active <= prom_we;
        if (prom_we) last_prom_addr <= prog_addr;
        if (prom_we && (!prom_active || prog_addr != last_prom_addr)) begin
        if (prog_addr == 0) begin
            bytes_loaded <= 1;
            load_error <= 0;
            loaded <= 0;
        end else if (!load_error && prog_addr == {8'd0,bytes_loaded}
                     && prog_addr < 22'd8864) begin
            bytes_loaded <= bytes_loaded + 14'd1;
            if (prog_addr == 22'd8863) loaded <= 1;
        end else begin
            loaded <= 0;
            load_error <= 1;
        end
    end
    end

    // Host clocks are counted from the pxl_cen clock (edge 0). Sheets D and H
    // register their outputs for the previous pixel at edge 2; sheets A and F
    // capture their inputs at edge 3.
    reg [2:0] cen_sr;
    wire edge3 = cen_sr[2];
    always @(posedge clk) cen_sr <= rst ? 3'd0 : {cen_sr[1:0], pxl_cen};

    // ---------------------------------------------------------------- stand-ins
    // Cabinet for the connected sheets (jtmonacogp_gtest.v)
    wire coin_sw, test_sw, credit_sw, two_play, cab_tilt_n, shift_no, shift_nc;
    wire han_l_cp, han_r_cp, high_gear, ic27_3, ic51_3;
    wire [1:0] acce_ab;
    jtmonacogp_gtest u_gtest(
        .clk(clk),.rst(rst),.enable(game_view),
        .joy_n(joystick1[5:0]),.pedal_y(joyana_r1[15:8]),
        // player 1's right trigger: the patched hps_io of the MiSTer build
        // puts {RT, LT} on this input (scripts/mister_overlay.py); zero otherwise
        .pedal_t(joyana_r4[15:8]),.coin_n(coin[0]),.start_n(cab_1p[0]),
        .service_n(service),.tilt_in_n(tilt),.dip_two_play(dipsw[0]),
        .coin_sw(coin_sw),.test_sw(test_sw),.credit_sw(credit_sw),.two_play(two_play),
        .tilt_n(cab_tilt_n),.acce_ab(acce_ab),.shift_no(shift_no),.shift_nc(shift_nc),
        .high_gear(high_gear),
        .ic27_3(ic27_3),.ic51_3(ic51_3));

    // ---------------------------------------------------------------- handle board
    // JTFRAME's dial is a quadrature pair, like the wheel's two optical
    // sensors: A = dial_x[1], B = dial_x[0] (JTFRAME's "increase" turns
    // right). A spinner, the mouse or the joystick's left/right (JTFRAME
    // dial emulation) turn it.
    jtmonacogp_handle u_handle(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),
        .a(game_view & dial_x[1]),.b(game_view & dial_x[0]),
        .han_l_cp(han_l_cp),.han_r_cp(han_r_cp),.clr_n());

    // ---------------------------------------------------------------- sheet I
    // The score counter and its lines to sheets A (S-100-D', pad A30), D
    // (S-100-A..D), M (100-C) and H (SP. CONT.).
    wire [3:0] g_s100;
    wire [15:0] score;
    wire a30, sp_cont;
    // The Pro board's RAM RESET switch (sheet I, SW.1): dipsw[14], an entry
    // on the Pro MRA's DIP page only (the Monaco GP MRA has none, so Monaco
    // GP users never see it). On holds the switch closed: the sequencer
    // writes 0000 into every slot while it is held. JTFRAME's OSD cannot
    // hide a core option by mode (its menu mask is fixed in jtframe_mister),
    // so it is not a status-bit trigger. Ignored with pro = 0.
    wire ram_reset_n = ~(pro & dipsw[14]);
    jtmonacogp_score u_score(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.score_cp_n(f_score_cp_n),
        .coin_test_n(a_coin_test_n),.ini_reset_n(a_ini_reset_n),
        // Pro board: 91.3 and the unstopped count (ignored with pro = 0)
        .pro(pro),.ram_reset_n(ram_reset_n),
        .digits(score),.s100(g_s100),.s100_d2(a30),.sp_cont(sp_cont));

    // Test stimulus for the player-car test (sheet G alone)
    wire [1:0] tstate;
    wire [4:0] tframe;
    wire t_pl_h_st, t_pl_v_st, t_coin_in_n, t_explo_st, t_explo_st_n, t_acc1_n, t_home_pos_n;
    wire t_extend_n, t_gravel_n, t_slide_n, t_vs4, t_vs8, t_vs16, t_vs32, t_ic51_3;
    wire ptest_off = diag_view | scen_view | game_view;
    jtmonacogp_ptest u_ptest(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.h(h),.v(v),.vs(VS),
        .next_n(ptest_off | joystick1[4]),.prev_n(ptest_off | joystick1[5]),
        .state(tstate),.frame(tframe),.pl_h_st(t_pl_h_st),.pl_v_st(t_pl_v_st),
        .coin_in_n(t_coin_in_n),.explo_st(t_explo_st),.explo_st_n(t_explo_st_n),
        .acc1_n(t_acc1_n),.home_pos_n(t_home_pos_n),.extend_n(t_extend_n),
        .gravel_n(t_gravel_n),.slide_n(t_slide_n),
        .vs4(t_vs4),.vs8(t_vs8),.vs16(t_vs16),.vs32(t_vs32),
        .ic51_3(t_ic51_3));

    // Test stimulus for the road and scenery view (sheets B and D alone).
    // The buttons act on it only while that view is displayed.
    wire [3:0] t_s100, t_sp;
    wire t_in_reset_n, t_s_vs2, t_s_vs4, t_s_vs16, t_s_coin_in_n, t_ex_signal_n, t_game_n, t_extend;
    wire [4:0] sframe;
    jtmonacogp_stest u_stest(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.vs(VS),.enable(scen_view),
        .joy_n(joystick1[5:0]),.s100(t_s100),.sp(t_sp),.in_reset_n(t_in_reset_n),
        .frame(sframe),.vs2(t_s_vs2),.vs4(t_s_vs4),.vs16(t_s_vs16),.coin_in_n(t_s_coin_in_n),
        .ex_signal_n(t_ex_signal_n),.game_n(t_game_n),.extend(t_extend));

    // ---------------------------------------------------------------- nets
    // Sheet A
    wire a_game, a_game_n, a_coin_in, a_coin_in_n, a_coin_test_n, a_extend, a_extend_n;
    wire a_ex_signal_n, a_ex_signal_cp_n, a_ex_cp, a_car_cont_cl, a_pts8000, a_ini_reset_n, a_credit_lamp, a_busy;
    wire a_mute, a_hiscore_n;
    wire a_snd_coin_in_n;                                 // pad A28 (S)
    wire [3:0] a_t1, a_t2;
    wire [27:0] a_dbg;
    // Sheet F
    wire f_pl_h_st, f_pl_v_st, f_acce_st, f_acc1_n, f_sp_irreg_n, f_home_pos_n;
    wire f_explo_st, f_explo_st_n, f_busy;
    wire f_shift, f_nonroad_slip_n, f_s_acc1_n;           // pads AW, A20, AR to the sound board
    wire f_slipzone_n;                                    // pad AX (S) to the sound board's pad J
    wire f_splay_a_n, f_splay_b, f_score_cp_n;          // sheet F's "/SPLAY B" port is IC49 Q
    wire [3:0] f_acce, f_explo_sel;
    wire [7:0] f_ic19_q, f_ic40_q;
    wire [6:0] f_hpos_t;
    wire [7:0] f_vpos_t;
    wire [36:0] f_dbg;
    // Sheet H
    wire h_vs2, h_vs4, h_vs8, h_vs16, h_vs32, h_vs64;
    wire h_other_car_n, h_other_body_n, h_other_tiar_n, h_f_sound_n, h_busy;
    wire [3:0] h_sp;
    wire [5:1] h_area;
    wire [4:0] pr38_addr, pr39_addr;
    wire [8:0] pr132_addr;
    wire [68:0] h_dbg;
    // Sheet M
    wire rescue_bl_n, rescue_r_n, rescue_w_n, rescue_n, rl_side_n, ext_car_cont, rescue_cp_n;
    wire sig_y_n, sig_bl_n, dummy_area_n, dummy_w_n, dummy_r_n, dummy_bl_n, game_over;
    wire bridge_n, bridge_dbu_n, bridge_y_n, bridge_r_n, bridge_bu_n, l2_side_n, r2_side_n, m_busy;
    wire [8:0] pr138_addr, pr139_addr, pr140_addr;
    wire [21:0] m_dbg;
    // Sheet D
    wire side_line_n, tree_grass_g_n, tree_grass_bl_n, grass_area_n, grass_w_n, house_st_n;
    wire [3:0] house_n;
    wire pool_n, wall_n, gravel_n, slide_n, slip_n, green_belt_n, y_line_n;
    wire tunnel_ap, bridge_ap, road, road_n, tunnel_n, tunnel_bridge_n, ext500, ext500_n;
    wire car_no_cont_n, r_side_n, l_side_n, zero_area_n, scen_busy;
    wire [23:0] scen_dbg;
    // Sheet G
    wire [8:0] pr127_addr, pr128_addr, pr129_addr, pr130_addr;
    wire player_body_n, tire_n, player_bl_n, player_n, player;
    wire sp_down_n, sp_down, acc1_pulse_n, acc1_st_n, score_st_n, ic66_3;
    wire ic68_3, ic19_q;
    wire [7:0] hc, vc, pbus;
    wire vwin, hwin, strobe_n;
    wire [3:0] prom_en, ic38_q;
    wire [1:0] pmux;
    wire [8:0] pr125_addr, pr126_addr, pr131_addr;
    wire light_n, explo_r_n, explo_y_n, explo_area_n, splay_n;
    wire g_player_st;                                     // PLAYER ST (Pro IC31) to sheet N
    // Sheet N (Pro board only), named as drawn on N
    wire n_bonus_sound;                                   // BONUS SOUND -> sheet A
    wire n_bonus_point_n;                                 // /BONUS POINT -> sheet F
    wire n_bonus_cp_n;                                    // /BONUS CP -> sheet A
    wire n_bonus_cp;                                      // BONUS CP, pad CE -> sheet M (+200)
    // BONUS D..A, pads M4..M1 -> sheet I: they address only the lamp PROMs
    // PR-01/PR-02 (pro/docs/trace/SHEET_I_TRACE.md, section 5), modelled in
    // jtmonacogp_lamps.v with the reconstructed contents (no known dump).
    wire [3:0] n_bonus;
    wire n_game_end_n;                                    // /GAME END, pad M5 -> sheet I (HP: 72.5, 65.1)
    wire n_busy;
    wire [23:0] n_dbg;

    // ---------------------------------------------------------------- sheet A
    jtmonacogp_coin #(
        .TILT_PIXELS(44898531/CS),.IC49_PIXELS(9552879/CS),.HI_PIXELS(9553/CS),
        .T555_FIRST(8289622/C555),.T555_HIGH(5230169/C555),.T555_LOW(2204053/C555)) u_coin(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),
        .coin_sw(coin_sw),.test_sw(test_sw),.credit_sw(credit_sw),.two_play(two_play),
        .tilt_n(cab_tilt_n),
        .acce_st(f_acce_st),.game_over(game_over),.v2(v[2]),.vs16(h_vs16),.a30(a30),
        // Pro board: BONUS SOUND and /BONUS CP from sheet N (ignored with pro = 0)
        .pro(pro),.bonus_sound(n_bonus_sound),.bonus_cp_n(n_bonus_cp_n),.snd_coin_in_n(a_snd_coin_in_n),
        .game(a_game),.game_n(a_game_n),.coin_in(a_coin_in),.coin_in_n(a_coin_in_n),
        .coin_test_n(a_coin_test_n),.extend(a_extend),.extend_n(a_extend_n),
        .ex_signal_n(a_ex_signal_n),.ex_signal_cp_n(a_ex_signal_cp_n),.ex_cp(a_ex_cp),.car_cont_cl(a_car_cont_cl),
        .pts8000(a_pts8000),.mute(a_mute),.hiscore_n(a_hiscore_n),.ini_reset_n(a_ini_reset_n),
        .t1(a_t1),.t2(a_t2),.coin_meter(),.credit_lamp(a_credit_lamp),
        .dbg(a_dbg),.busy(a_busy));

    // ---------------------------------------------------------------- sheet F
    // PLAYER is sheet G's net for the current pixel, settled from edge 3.
    // Sheets D and H give F theirs for the previous pixel (registered at
    // edge 2), so PLAYER is held for one pixel to meet ROAD, /SLIP, /POOL(2)
    // and /OTHER BODY on the same raster position, as on the board.
    reg player_l;
    always @(posedge clk) if (edge3) player_l <= player;
    jtmonacogp_control #(
        .IC1A_PIXELS(448985/CS),.IC1B_PIXELS(448985/CS),.IC43A_PIXELS(955288/CS),
        .IC43B_PIXELS(1432932/CS),.IC49_PIXELS(2101633/CS)) u_control(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),
        .h4(h[4]),.h5(h[5]),.h6(h[6]),.h8(h[8]),.hs(HS),.v(v[7:4]),
        .coin_test_n(a_coin_test_n),.game_n(a_game_n),.extend(a_extend),.pts8000(a_pts8000),
        .vs2(h_vs2),.vs8(h_vs8),.vs16(h_vs16),.vs32(h_vs32),.vs64(h_vs64),
        .other_body_n(h_other_body_n),
        .slip_n(slip_n),.pool2_n(pool_n),.road(road),.tunnel_n(tunnel_n),.ext500_n(ext500_n),
        .rescue_n(rescue_n),.bridge_n(bridge_n),.ext_car_cont(ext_car_cont),
        .sp_down_n(sp_down_n),.sp_down(sp_down),.score_st_n(score_st_n),.acc1_st_n(acc1_st_n),
        .acc1_pulse_n(acc1_pulse_n),.player(player_l),
        .acce_cont_a(acce_ab[1]),.acce_cont_b(acce_ab[0]),.han_l_cp(han_l_cp),.han_r_cp(han_r_cp),
        .shift_no(shift_no),.shift_nc(shift_nc),.ic27_3(ic27_3),
        .pro(pro),.bonus_point_n(n_bonus_point_n),       // /BONUS POINT (N), ignored with pro = 0
        .pl_h_st(f_pl_h_st),.pl_v_st(f_pl_v_st),.shift(f_shift),.slipzone_n(f_slipzone_n),.nonroad_slip_n(f_nonroad_slip_n),
        .acce_st(f_acce_st),.acce(f_acce),.score_cp_n(f_score_cp_n),.s_acc1_n(f_s_acc1_n),.acc1_n(f_acc1_n),
        .splay_a_n(f_splay_a_n),.splay_b_n(f_splay_b),.sp_irreg_n(f_sp_irreg_n),.home_pos_n(f_home_pos_n),
        .explo_sel(f_explo_sel),.explo_st(f_explo_st),.explo_st_n(f_explo_st_n),
        .ic19_q(f_ic19_q),.ic40_q(f_ic40_q),.hpos_t(f_hpos_t),.vpos_t(f_vpos_t),
        .dbg(f_dbg),.dbg_live(),.busy(f_busy));

    // ---------------------------------------------------------------- sheet H
    jtmonacogp_cars #(
        .OS1A_PIXELS(9552879/CS),.OS1B_PIXELS(9552879/CS),
        .OS2A_PIXELS(21016334/CS),.OS2B_PIXELS(21016334/CS)) u_cars(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),
        .h6_n(~h[6]),.h8_n(~h[8]),.hs_n(~HS),.vs_n(~VS),.v8_n(~v[8]),
        .vca_v8_n(~(&v[7:0] & v[8])),
        .l1_side_n(l_side_n),.l2_side_n(l2_side_n),.r1_side_n(r_side_n),.r2_side_n(r2_side_n),
        .rl_side_n(rl_side_n),.bridge_ap(bridge_ap),.car_sp_cont_n(car_no_cont_n),
        .car_cont_cl(a_car_cont_cl),.ext500_n(ext500_n),.sp_irreg_n(f_sp_irreg_n),.acce(f_acce),
        .sp_cont(sp_cont),
        .pr38_addr(pr38_addr),.pr39_addr(pr39_addr),.pr38_q(prom_q[17*8+:8]),
        .pr39_q(prom_q[18*8+:8]),.pr132_addr(pr132_addr),.pr132_q(prom_q[7*8+:8]),
        .vs2(h_vs2),.vs4(h_vs4),.vs8(h_vs8),.vs16(h_vs16),.vs32(h_vs32),.vs64(h_vs64),
        .sp(h_sp),.area(h_area),.other_car_n(h_other_car_n),.other_body_n(h_other_body_n),
        .other_tiar_n(h_other_tiar_n),.f_sound_n(h_f_sound_n),.dbg(h_dbg),.busy(h_busy));

    // ---------------------------------------------------------------- sheet G
    // Sheets A, D, F and H in the connected view, the test stimulus otherwise
    jtmonacogp_player #(.IC119_PIXELS(955290/CS),.IC19_PIXELS(955290/CS)) u_player(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.hs(HS),
        .pl_h_st   (game_view ? f_pl_h_st    : t_pl_h_st),
        .pl_v_st   (game_view ? f_pl_v_st    : t_pl_v_st),
        .explo_st  (game_view ? f_explo_st   : t_explo_st),
        .explo_st_n(game_view ? f_explo_st_n : t_explo_st_n),
        .acc1_n    (game_view ? f_acc1_n     : t_acc1_n),
        .home_pos_n(game_view ? f_home_pos_n : t_home_pos_n),
        .coin_in_n (game_view ? a_coin_in_n  : t_coin_in_n),
        .extend_n  (game_view ? a_extend_n   : t_extend_n),
        .gravel_n  (game_view ? gravel_n     : t_gravel_n),
        .slide_n   (game_view ? slide_n      : t_slide_n),
        .vs4       (game_view ? h_vs4        : t_vs4),
        .vs8       (game_view ? h_vs8        : t_vs8),
        .vs16      (game_view ? h_vs16       : t_vs16),
        .vs32      (game_view ? h_vs32       : t_vs32),
        .ic51_3    (game_view ? ic51_3       : t_ic51_3),
        .pro(pro),.player_st(g_player_st),
        .pr127_addr(pr127_addr),.pr128_addr(pr128_addr),
        .pr129_addr(pr129_addr),.pr130_addr(pr130_addr),
        .pr127_q(prom_q[2*8+:8]),.pr128_q(prom_q[3*8+:8]),
        .pr129_q(prom_q[4*8+:8]),.pr130_q(prom_q[5*8+:8]),
        .player_body_n(player_body_n),.tire_n(tire_n),.player_bl_n(player_bl_n),
        .player_n(player_n),.player(player),.sp_down_n(sp_down_n),.sp_down(sp_down),
        .acc1_pulse_n(acc1_pulse_n),.acc1_st_n(acc1_st_n),.score_st_n(score_st_n),
        .ic66_3(ic66_3),
        .hc(hc),.vc(vc),.vwin(vwin),.hwin(hwin),.strobe_n(strobe_n),
        .prom_en(prom_en),.bus(pbus),.mux(pmux),.ic38_q(ic38_q),
        .ic68_3(ic68_3),.ic19_q(ic19_q));
    // Headlight, explosion and splash: sheet F's lines and the player path's
    // counters and windows; their output only reaches the connected view.
    jtmonacogp_effects u_effects(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.hc(hc),.vc(vc),.hwin(hwin),.vwin(vwin),.ic66_3(ic66_3),
        .acc1_n(f_acc1_n),.tunnel_n(tunnel_n),.explo_st(f_explo_st),.explo_st_n(f_explo_st_n),
        .explo_sel(f_explo_sel),.splay_a_n(f_splay_a_n),.splay_b(f_splay_b),
        .pr125_addr(pr125_addr),.pr126_addr(pr126_addr),.pr131_addr(pr131_addr),
        .pr125_q(prom_q[0*8+:8]),.pr126_q(prom_q[1*8+:8]),.pr131_q(prom_q[6*8+:8]),
        .light_n(light_n),.explo_r_n(explo_r_n),.explo_y_n(explo_y_n),.explo_area_n(explo_area_n),
        .splay_n(splay_n),.eq(),.w(),.splash_win());
    jtmonacogp_pview u_pview(
        .x(x),.y(y),.active(LHBL && LVBL),.loaded(loaded),.load_error(load_error),
        .state(tstate),.prom_en(prom_en),.vs4(t_vs4),.vs8(t_vs8),.vs16(t_vs16),.vs32(t_vs32),
        .strobe_n(strobe_n),.slide_n(t_slide_n),.player_body_n(player_body_n),.tire_n(tire_n),
        .player_bl_n(player_bl_n),.red(pview_r),.green(pview_g),.blue(pview_b));

    // ---------------------------------------------------------------- sheets B and D
    // Sheets A, H and the sheet I stand-in in the connected view, the test
    // stimulus otherwise
    wire [3:0] s100 = game_view ? g_s100 : t_s100;
    wire [3:0] sp   = game_view ? h_sp   : t_sp;
    wire b_vs2  = game_view ? h_vs2  : t_s_vs2;
    wire b_vs4  = game_view ? h_vs4  : t_s_vs4;
    wire b_vs16 = game_view ? h_vs16 : t_s_vs16;
    wire coin_in_n   = game_view ? a_coin_in_n   : t_s_coin_in_n;
    // Sheet B labels pad E1 /COIN IN, but sheet A's pad B1, the same wire by
    // the pad rule (docs/CONNECTED.md), is COIN IN, IC37's Q.
    wire b_pad_e1    = game_view ? a_coin_in     : t_s_coin_in_n;
    wire ex_signal_n = game_view ? a_ex_signal_n : t_ex_signal_n;
    wire b_game_n    = game_view ? a_game_n      : t_game_n;
    wire in_reset_n  = game_view ? a_ini_reset_n : t_in_reset_n;  // pad BA (A) = EA (B)
    wire extend      = game_view ? a_extend      : t_extend;
    wire extend_n    = game_view ? a_extend_n    : ~t_extend;
    // Pro board (pro/docs/SHEETS_B_C_D_PRO_LOGIC.md): sheet B's display timer
    // and selectors, and sheet D's new outputs. Vs/512 (H, pad E8 on B) is
    // sheet H's frame counter bit, which it also puts on PR-39's A1.
    wire b_display_n, b_d_extend, b_d_extend_n, b_d_game_n;
    wire d_time, d_slow, d_belt, d_c100;
    wire h_vs512 = pr39_addr[1];
    // D-EXTEND replaces EXTEND on sheets C, D and M of the Pro board
    wire cdm_extend   = pro ? b_d_extend   : extend;
    wire cdm_extend_n = pro ? b_d_extend_n : extend_n;
    wire [8:0] mh, pr133_addr, pr134_addr, pr135_addr, pr136_addr, pr137_addr;
    wire [7:0] m1v, m2v;
    wire [5:1] vdec_n;
    wire mhld_n, m1vld_n, m2vld_n, ex_gameover_n, coin_start_n;
    // Outputs of the two IC66 readings (see u_scenery_nand)
    wire and_pool_n, and_wall_n, and_gravel_n, and_tgg_n, nand_pool_n, nand_wall_n,
         nand_gravel_n, nand_tgg_n;

    // M1V and M2V start at D0 and 40, as in tests/tb_scenery.v, which puts the
    // road on screen; the board has no reset for them.
    jtmonacogp_motion #(.M1V_INIT(8'hd0),.M2V_INIT(8'h40)) u_motion(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.h(h),.hs(HS),.v(v),
        .sp(sp),.vs2(b_vs2),.vs4(b_vs4),.vs16(b_vs16),
        .coin_in_n(coin_in_n),.coin_in_e1_n(b_pad_e1),.ex_signal_n(ex_signal_n),
        .game_n(b_game_n),.in_reset_n(in_reset_n),.tunnel_bridge_n(tunnel_bridge_n),
        // Pro: /COIN IN for IC72 is coin_in_n, the PROM's A8 net (pad E1 on Pro)
        .pro(pro),.vs512(h_vs512),.extend(extend),.extend_n(extend_n),.d_time(d_time),.slow(d_slow),
        .display_n(b_display_n),.d_extend(b_d_extend),.d_extend_n(b_d_extend_n),.d_game_n(b_d_game_n),
        .pr133_addr(pr133_addr),.pr133_q(prom_q[8*8+:8]),
        .mh(mh),.mhld_n(mhld_n),.m1v(m1v),.m2v(m2v),.m1vld_n(m1vld_n),.m2vld_n(m2vld_n),
        .vdec_n(vdec_n),.ex_gameover_n(ex_gameover_n),.coin_start_n(coin_start_n),
        .q1(),.q2(),.q68(),.vsel(),.strobe_n(),.txt());
    jtmonacogp_scenery u_scenery(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.hs(HS),.v7(v[7]),.v8(v[8]),
        .mh(mh),.mhl_n(mhld_n),.m1v(m1v),.m2v(m2v),.m1vl_n(m1vld_n),.m2vl_n(m2vld_n),
        .v4dec_n(vdec_n[4]),.extend(cdm_extend),.coin_in_n(coin_in_n),.s100(s100),
        .pro(pro),.display_n(b_display_n),.d_game_n(b_d_game_n),
        .d_time(d_time),.slow(d_slow),.belt(d_belt),.slip_eh(),.c100(d_c100),.dbg_pro(),
        .pr134_addr(pr134_addr),.pr135_addr(pr135_addr),.pr136_addr(pr136_addr),
        .pr137_addr(pr137_addr),
        .pr134_q(prom_q[9*8+:8]),.pr135_q(prom_q[10*8+:8]),.pr136_q(prom_q[11*8+:8]),
        .pr137_q(prom_q[12*8+:8]),
        .side_line_n(side_line_n),.tree_grass_g_n(and_tgg_n),.tree_grass_bl_n(tree_grass_bl_n),
        .grass_area_n(grass_area_n),.grass_w_n(grass_w_n),.house_st_n(house_st_n),.house_n(house_n),
        .pool_n(and_pool_n),.wall_n(and_wall_n),.gravel_n(and_gravel_n),.slide_n(slide_n),.slip_n(slip_n),
        .green_belt_n(green_belt_n),.y_line_n(y_line_n),.tunnel_ap(tunnel_ap),.bridge_ap(bridge_ap),
        .road(road),.road_n(road_n),.tunnel_n(tunnel_n),.tunnel_bridge_n(tunnel_bridge_n),
        .ext500(ext500),.ext500_n(ext500_n),.car_no_cont_n(car_no_cont_n),
        .r_side_n(r_side_n),.l_side_n(l_side_n),.zero_area_n(zero_area_n),
        .dbg(scen_dbg),.busy(scen_busy));
    // The same logic with IC66 read as a NAND. IC66 drives /GRAVEL and, through
    // IC104 and IC89, the IC119 strobes; it changes no state and no PROM
    // address, so this copy reads the same PROM data. Only the four outputs
    // that depend on it are taken from here, in display 4 only.
    jtmonacogp_scenery #(.IC66_NAND(1)) u_scenery_nand(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.hs(HS),.v7(v[7]),.v8(v[8]),
        .mh(mh),.mhl_n(mhld_n),.m1v(m1v),.m2v(m2v),.m1vl_n(m1vld_n),.m2vl_n(m2vld_n),
        .v4dec_n(vdec_n[4]),.extend(cdm_extend),.coin_in_n(coin_in_n),.s100(s100),
        .pro(pro),.display_n(b_display_n),.d_game_n(b_d_game_n),
        .d_time(),.slow(),.belt(),.slip_eh(),.c100(),.dbg_pro(),
        .pr134_addr(),.pr135_addr(),.pr136_addr(),.pr137_addr(),
        .pr134_q(prom_q[9*8+:8]),.pr135_q(prom_q[10*8+:8]),.pr136_q(prom_q[11*8+:8]),
        .pr137_q(prom_q[12*8+:8]),
        .side_line_n(),.tree_grass_g_n(nand_tgg_n),.tree_grass_bl_n(),.grass_area_n(),
        .grass_w_n(),.house_st_n(),.house_n(),.pool_n(nand_pool_n),.wall_n(nand_wall_n),
        .gravel_n(nand_gravel_n),.slide_n(),.slip_n(),.green_belt_n(),.y_line_n(),
        .tunnel_ap(),.bridge_ap(),.road(),.road_n(),.tunnel_n(),.tunnel_bridge_n(),
        .ext500(),.ext500_n(),.car_no_cont_n(),.r_side_n(),.l_side_n(),.zero_area_n(),
        .dbg(),.busy());
    assign {pool_n, wall_n, gravel_n, tree_grass_g_n} = ic66_nand ?
        {nand_pool_n, nand_wall_n, nand_gravel_n, nand_tgg_n} :
        {and_pool_n, and_wall_n, and_gravel_n, and_tgg_n};
    // ---------------------------------------------------------------- sheet M
    // Its raster and sheet B inputs are for the pixel it captures; sheets D
    // and H give theirs two pixels later (docs/SHEET_M_LOGIC.md).
    wire m_plus200_n;                                     // Pro: /+200 (R) -> (C)
    jtmonacogp_rescue #(.IC18_PIXELS(143293/CS)) u_rescue(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.h(h),.v(v),.hs(HS),.vdec_n(vdec_n),.mh(mh[4:0]),
        .vs4(h_vs4),.vs16(h_vs16),.vs32(h_vs32),.vs64(h_vs64),
        // Pro: D-EXTEND and /D-EXTEND (B), and 100-C taken after sheet D's
        // new multiplexer
        .extend(pro ? b_d_extend : a_extend),.extend_n(pro ? b_d_extend_n : a_extend_n),
        .game_n(a_game_n),.coin_in_n(a_coin_in_n),
        .ex_signal_cp_n(a_ex_signal_cp_n),.s100c(pro ? d_c100 : g_s100[2]),.car_no_cont_n(car_no_cont_n),
        .ext500(ext500),.ext500_n(ext500_n),.zero_area_n(zero_area_n),.bridge_ap(bridge_ap),
        .other_car_n(h_other_car_n),.acce_d(f_acce[3]),.explo_sel_d(f_explo_sel[3]),
        // Pro board: BONUS CP (sheet N, active high) opens the +200 window
        .pro(pro),.bonus_cp(n_bonus_cp),.plus200_n(m_plus200_n),
        .pr138_addr(pr138_addr),.pr139_addr(pr139_addr),.pr140_addr(pr140_addr),
        .pr138_q(prom_q[13*8+:8]),.pr139_q(prom_q[14*8+:8]),.pr140_q(prom_q[15*8+:8]),
        .pr141_q(prom_q[16*8+:8]),
        .rescue_bl_n(rescue_bl_n),.rescue_r_n(rescue_r_n),.rescue_w_n(rescue_w_n),.rescue_y_n(rescue_n),
        .rl_side_n(rl_side_n),.ext_car_cont(ext_car_cont),.rescue_cp_n(rescue_cp_n),
        .sig_y_n(sig_y_n),.sig_bl_n(sig_bl_n),.dummy_area_n(dummy_area_n),.dummy_w_n(dummy_w_n),
        .dummy_r_n(dummy_r_n),.dummy_bl_n(dummy_bl_n),.game_over(game_over),
        .bridge_w_n(bridge_n),.bridge_dbu_n(bridge_dbu_n),.bridge_y_n(bridge_y_n),
        .bridge_r_n(bridge_r_n),.bridge_bu_n(bridge_bu_n),.l2_side_n(l2_side_n),.r2_side_n(r2_side_n),
        .dbg(m_dbg),.busy(m_busy));

    // ---------------------------------------------------------------- sheet N (Pro)
    // The bonus circuit (pro/docs/SHEET_N_LOGIC.md), inputs as in
    // pro/docs/trace/BONUS_INPUTS_TRACE.md and SHEET_N_TRACE.md's interface
    // table. With pro = 0 it still runs, but PLAYER ST is low and sheets A
    // and F ignore its outputs. Like sheet F it captures at edge 3, so
    // PLAYER ST (sheet G, current pixel) is held one pixel, as PLAYER is
    // for F, to meet /OTHER CAR (H) and /BRIDGE AP (D) on the same raster
    // position. /BRIDGE AP is Pro sheet D's IC59 = NOT(BRIDGE AP); PR-38-7
    // and PR-38-9 are PR-38's D6 and D7 on sheet H.
    reg g_player_st_l;
    always @(posedge clk) if (edge3) g_player_st_l <= g_player_st;
    jtmonacogp_bonus #(
        .IC100A_PIXELS(315245/CS),.IC100B_PIXELS(95529/CS),
        .IC107A_PIXELS(2101633/CS),.IC107B_PIXELS(315245/CS)) u_bonus(
        .clk(clk),.rst(rst),.pxl_cen(pxl_cen),
        .v2(v[2]),.v4(v[4]),.v5(v[5]),
        .coin_test_n(a_coin_test_n),.ini_reset_n(a_ini_reset_n),
        .bridge_ap_n(~bridge_ap),.player_st(g_player_st_l),.other_car_n(h_other_car_n),
        .game(a_game),.game_n(a_game_n),.score_st_n(score_st_n),
        .pr38_7(prom_q[17*8+6]),.pr38_9(prom_q[17*8+7]),.acc1_n(f_acc1_n),
        .bonus_sound(n_bonus_sound),.bonus_point_n(n_bonus_point_n),.game_end_n(n_game_end_n),
        .bonus(n_bonus),.bonus_cp(n_bonus_cp),.bonus_cp_n(n_bonus_cp_n),
        .dbg(n_dbg),.busy(n_busy));

    jtmonacogp_sview u_sview(
        .x(x),.y(y),.active(LHBL && LVBL),.loaded(loaded),.load_error(load_error),
        .s100(s100),.sp(sp),.in_reset_n(in_reset_n),
        .ex_gameover_n(ex_gameover_n),.coin_start_n(coin_start_n),
        .road(road),.green_belt_n(green_belt_n),.grass_area_n(grass_area_n),.grass_w_n(grass_w_n),
        .tree_grass_bl_n(tree_grass_bl_n),.tree_grass_g_n(tree_grass_g_n),.gravel_n(gravel_n),
        .pool_n(pool_n),.wall_n(wall_n),.house_n(house_n),.slip_n(slip_n),.y_line_n(y_line_n),
        .side_line_n(side_line_n),.red(sview_r),.green(sview_g),.blue(sview_b));

    // ---------------------------------------------------------------- connected view
    // Sheet B's text and V-(4) and sheet G give the current pixel; they are
    // held one pixel to sit with sheets D, H and M.
    reg g_body_n, g_tire_n, g_bl_n, g_player_n, b_exgo_n, b_coinst_n, b_v4d;
    reg g_light_n, g_explo_r_n, g_explo_y_n, g_explo_area_n, g_splay_n;
    always @(posedge clk) if (pxl_cen) begin
        {g_body_n, g_tire_n, g_bl_n, g_player_n, b_exgo_n, b_coinst_n, b_v4d} <=
            {player_body_n, tire_n, player_bl_n, player_n, ex_gameover_n, coin_start_n, vdec_n[4]};
        {g_light_n, g_explo_r_n, g_explo_y_n, g_explo_area_n, g_splay_n} <=
            {light_n, explo_r_n, explo_y_n, explo_area_n, splay_n};
    end
    // Sheet C. IC79 registers AREA on the 7 MHz edge at which sheet H
    // registers the next pixel's AREA, so it holds the pixel before, as on the
    // board.
    wire [3:0] c_red, c_green, c_blue;
    jtmonacogp_colour u_colour(
        .clk(clk),.rst(rst),.cen7(cen_sr[1]),
        .area(h_area),.other_body_n(h_other_body_n),.other_tiar_n(h_other_tiar_n),.other_car_n(h_other_car_n),
        .road_n(road_n),.road(road),.tg_g_n(tree_grass_g_n),.tg_bl_n(tree_grass_bl_n),.house_st_n(house_st_n),
        .grass_area_n(grass_area_n),.grass_w_n(grass_w_n),.house_n(house_n),.tunnel_ap(tunnel_ap),
        .bridge_ap(bridge_ap),.green_belt_n(green_belt_n),.y_line_n(y_line_n),.gravel_n(gravel_n),
        .pool_n(pool_n),.slip_n(slip_n),.wall_n(wall_n),.side_line_n(side_line_n),
        // Pro: D-EXTEND and /D-EXTEND (B)
        .extend(pro ? b_d_extend : a_extend),.extend_n(pro ? b_d_extend_n : a_extend_n),
        .coin_start_n(b_coinst_n),.ex_gameover_n(b_exgo_n),.v4d(b_v4d),
        .light_n(g_light_n),.splay_n(g_splay_n),.explo_y_n(g_explo_y_n),.explo_r_n(g_explo_r_n),
        .explo_area_n(g_explo_area_n),
        .player_n(g_player_n),.player_body_n(g_body_n),.player_tiar_n(g_tire_n),.player_bl_n(g_bl_n),
        .sig_bl_n(sig_bl_n),.sig_y_n(sig_y_n),.dummy_area_n(dummy_area_n),.dummy_bl_n(dummy_bl_n),
        .dummy_w_n(dummy_w_n),.dummy_r_n(dummy_r_n),.rescue_bl_n(rescue_bl_n),.rescue_w_n(rescue_w_n),
        .rescue_y_n(rescue_n),.rescue_r_n(rescue_r_n),.bridge_dbu_n(bridge_dbu_n),.bridge_bu_n(bridge_bu_n),
        .bridge_y_n(bridge_y_n),.bridge_w_n(bridge_n),.bridge_r_n(bridge_r_n),
        .pro(pro),.plus200_n(m_plus200_n),.belt(d_belt),.bdim_hi(),.bdim_lo(),
        .grb_hi(),.grb_lo(),.code_hi(),.code_lo(),.red(c_red),.green(c_green),.blue(c_blue));
    jtmonacogp_gview u_gview(
        .x(x),.y(y),.active(LHBL && LVBL),.loaded(loaded),.load_error(load_error),
        .t_tens(a_t2),.t_units(a_t1),.game(a_game),.coin_in(a_coin_in),.extend(a_extend),
        .credit_lamp(a_credit_lamp),.acce(f_acce),.high_gear(high_gear),.s100(g_s100),
        .ex_gameover_n(b_exgo_n),.coin_start_n(b_coinst_n),
        .road(road),.green_belt_n(green_belt_n),.grass_area_n(grass_area_n),.grass_w_n(grass_w_n),
        .tree_grass_bl_n(tree_grass_bl_n),.tree_grass_g_n(tree_grass_g_n),.gravel_n(gravel_n),
        .pool_n(pool_n),.wall_n(wall_n),.house_n(house_n),.slip_n(slip_n),.y_line_n(y_line_n),
        .side_line_n(side_line_n),
        .other_car_n(h_other_car_n),.other_body_n(h_other_body_n),.other_tiar_n(h_other_tiar_n),
        .rescue_bl_n(rescue_bl_n),.rescue_r_n(rescue_r_n),.rescue_w_n(rescue_w_n),.rescue_y_n(rescue_n),
        .sig_y_n(sig_y_n),.sig_bl_n(sig_bl_n),.dummy_w_n(dummy_w_n),.dummy_r_n(dummy_r_n),
        .dummy_bl_n(dummy_bl_n),.bridge_w_n(bridge_n),.bridge_dbu_n(bridge_dbu_n),
        .bridge_y_n(bridge_y_n),.bridge_r_n(bridge_r_n),.bridge_bu_n(bridge_bu_n),
        .player_body_n(g_body_n),.tire_n(g_tire_n),.player_bl_n(g_bl_n),
        .real_colour(!false_colour),.c_red(c_red),.c_green(c_green),.c_blue(c_blue),
`ifdef MONACOGP_DEVVIEWS
        .dev_text(1'b1),
`else
        .dev_text(1'b0),
`endif
        .red(gview_r),.green(gview_g),.blue(gview_b));

    // PROM banks 2..5 (PR127..PR130) follow the player-car address pins,
    // banks 0, 1 and 6 (PR125, PR126, PR131) the headlight, explosion and
    // splash paths in the connected view,
    // banks 8..12 (PR133..PR137) those of sheets B and D while the road view
    // is displayed, and in the connected view banks 7, 17 and 18 (PR132, PR38,
    // PR39) follow sheet H and banks 13..16 (PR138..PR141) sheet M as well;
    // the PROM diagnostic addresses every bank. PR-140 and PR-141 share their
    // address pins.
    assign prom_addr = diag_view ? diag_addr :
        game_view ? {diag_addr[179:171], 4'd0, pr39_addr, 4'd0, pr38_addr,
                     pr140_addr, pr140_addr, pr139_addr, pr138_addr,
                     pr137_addr, pr136_addr, pr135_addr, pr134_addr, pr133_addr, pr132_addr,
                     pr131_addr, pr130_addr, pr129_addr, pr128_addr, pr127_addr,
                     pr126_addr, pr125_addr} :
        scen_view ? {diag_addr[179:117], pr137_addr, pr136_addr, pr135_addr, pr134_addr,
                     pr133_addr, diag_addr[71:0]} :
        {diag_addr[179:54], pr130_addr, pr129_addr, pr128_addr, pr127_addr,
         diag_addr[17:0]};

    jtmonacogp_diag u_diag(
        .clk(clk),.rst(rst),.x(x),.y(y),.active(LHBL && LVBL),
        .grid(grid),.next_n(~diag_view | joystick1[4]),.prev_n(~diag_view | joystick1[5]),
        .loaded(loaded),.load_error(load_error),.selected(selected),
        .prom_addr(diag_addr),.prom_q(prom_q),.red(diag_r),.green(diag_g),.blue(diag_b));
    wire [3:0] mux_r = diag_view ? diag_r : scen_view ? sview_r : game_view ? gview_r : pview_r;
    wire [3:0] mux_g = diag_view ? diag_g : scen_view ? sview_g : game_view ? gview_g : pview_g;
    wire [3:0] mux_b = diag_view ? diag_b : scen_view ? sview_b : game_view ? gview_b : pview_b;
    // OSD Flip screen (JTFRAME_OSD_FLIP): the picture turned by 180 degrees
    // through a frame buffer, for monitors turned the other way from the
    // cabinet's (clockwise). JTFRAME's dip_flip is ~status[1], high while the
    // OSD reads Off, so the picture is flipped while it is low. JTFRAME turns
    // MiSTer's frame buffer counter-clockwise when dip_flip ^ core_mod[2] is
    // high; with core_mod[2] set (MRA) it turns clockwise while Off, and the
    // other way while On, so the HDMI picture stays upright either way.
    // Builds without the macro drive dip_flip high (not flipped).
`ifdef JTFRAME_OSD_FLIP
    wire flip = ~dip_flip;
`else
    wire flip = 1'b0;
    assign dip_flip = 1'b1;
`endif
    // ---------------------------------------------------------------- sheets I, K, J
    // Sheet I's high-score memory and ranking (docs/SHEET_I_LOGIC.md), the
    // rank latches (sheet K) and the score display's scan (sheet J).
    // i_rank_ck (1ST..5TH, the rank latch clocks), i_latch_cl, i_n, i_r and
    // i_flash are the board's lines to J and K; i_searching is high while
    // the search after a game runs. The sound board's HI SCORE tune is
    // started by sheet A (u_coin hiscore_n, pad AF), not by these.
    wire [15:0] i_d;
    wire [4:0]  i_rank_ck;
    wire        i_latch_cl, i_searching;
    wire [11:0] i_n, i_r;
    wire [5:1]  i_flash;
    wire [79:0] k_ranks;
    // Pro board (pro = 1): 56's 10,000-point lamp, T.R.S, SUPER RACER SCORE
    wire        i_tenk, i_trs, k_srs_flag;
    wire [15:0] k_srs;
    wire [2:0]  j_scan;
    wire [7:0]  j_row_on;
    wire [27:0] j_seg;
    // The high-score memory, in mem.yaml with its NVRAM file
    wire        score_ram_we;
    assign score_we = {2{score_ram_we}};
    assign scoreptr_addr = 1'b0;
    generate if (RANK != 0) begin : g_rank
        jtmonacogp_rank #(.KEEP(1)) u_rank(
            .clk(clk),.rst(rst),.cen14(board_cen),.h5(h[5]),.v2(v[2]),.vs16(h_vs16),
            .game(a_game),.coin_test_n(a_coin_test_n),.ini_reset_n(a_ini_reset_n),
            .p(score),
            // Pro board: /GAME END (N, active low: low once the game is over
            // and the payout done) starts the sequencer (72.6) and fires
            // T.R.S (65) to K. Ignored with pro = 0.
            .pro(pro),.game_end_n(n_game_end_n),.ram_reset_n(ram_reset_n),.tenk(i_tenk),.trs(i_trs),
            .d(i_d),.rank_ck(i_rank_ck),.latch_cl(i_latch_cl),
            .n(i_n),.r(i_r),.flash(i_flash),.searching(i_searching),
            .ram_addr(score_addr),.ram_din(score_din),.ram_we(score_ram_we),.ram_dout(score_dout),
            .ptr_din(scoreptr_din),.ptr_we(scoreptr_we),.ptr_dout(scoreptr_dout));
        jtmonacogp_ranks u_ranks(
            .clk(clk),.rst(rst),.d(i_d),.ck(i_rank_ck),.latch_cl(i_latch_cl),
            .pro(pro),.p(score),.trs(i_trs),.q(k_ranks),.srs(k_srs),.srs_flag(k_srs_flag));
        jtmonacogp_leds u_leds(
            .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.v2(v[2]),.ranks(k_ranks),.p(score),
            .n(i_n),.r(i_r),.t1(a_t1),.t2(a_t2),.flash(i_flash),
            .scan(j_scan),.row_on(j_row_on),.seg(j_seg));
    end else begin : g_norank
        assign i_d = 16'd0, i_rank_ck = 5'd0, i_latch_cl = 1'b0, i_searching = 1'b0;
        assign i_n = 12'd0, i_r = 12'd0, i_flash = 5'd0, k_ranks = 80'd0;
        assign i_tenk = 1'b0, i_trs = 1'b0, k_srs = 16'd0, k_srs_flag = 1'b0;
        assign j_scan = 3'd0, j_row_on = 8'd0, j_seg = 28'd0;
        assign score_addr = 8'd0, score_din = 16'd0, score_ram_we = 1'b0;
        assign scoreptr_din = 8'd0, scoreptr_we = 1'b0;
    end endgenerate

    // Score, time and gear overlay (not original circuitry)
    wire [11:0] hud_rgb;
    jtmonacogp_hud u_hud(
        .x(x),.y(y),.show_score(show_score && game_view),.show_gear(show_gear && game_view),
        .t_tens(a_t2),.t_units(a_t1),.score(score),.high_gear(high_gear),
        .rgb_in({mux_r, mux_g, mux_b}),.rgb_out(hud_rgb));
    // Pro sheet I: the bonus lamp PROMs PR-01/PR-02 on BONUS A-D and V2.
    // Sheet N registers BONUS A-D one pixel after it captures V2, so V2 is
    // delayed by the same pixel here; on the board both are the same V2.
    // The car count (V2 low) lights common G26 and the stored bonuses
    // (V2 high) Gd with the reconstructed contents; which common is which
    // panel section is the reconstruction's assumption
    // (pro/reconstruction/LAMP_PROMS.md, assumption 3).
    reg  [1:0]  n_v2_l;
    wire [14:0] lamp_g26, lamp_gd;
    always @(posedge clk) if (edge3) n_v2_l <= {n_v2_l[0], v[2]};
    jtmonacogp_lamps u_lamps(
        .clk       ( clk         ),
        .rst       ( rst         ),
        .cen       ( edge3       ),
        .v2        ( n_v2_l[1]   ),
        .bonus     ( n_bonus     ),
        .prom_addr ( lamp_addr   ),
        .q01       ( lamp01_data ),
        .q02       ( lamp02_data ),
        .g26       ( lamp_g26    ),
        .gd        ( lamp_gd     )
    );
    // The LED score panel (not original circuitry), while button 3 is held
    wire [11:0] panel_rgb;
    generate if (RANK != 0) begin : g_panel
        jtmonacogp_panel u_panel(
            .clk(clk),.rst(rst),.pxl_cen(pxl_cen),.scan(j_scan),.row_on(j_row_on),.seg(j_seg),
            .x(x),.y(y),.show(show_panel && game_view),
            .pro(pro),.tenk(i_tenk),.srs(k_srs),.srs_flag(k_srs_flag),
            .cars_lamps(lamp_g26),.bonus_lamps(lamp_gd),
            .rgb_in(hud_rgb),.rgb_out(panel_rgb));
    end else begin : g_nopanel
        assign panel_rgb = hud_rgb;
    end endgenerate
    jtmonacogp_flip u_flip(
        .clk         ( clk                 ),
        .rst         ( rst                 ),
        .pxl_cen     ( pxl_cen             ),
        .flip        ( flip                ),
        .active      ( LHBL && LVBL        ),
        .x           ( x                   ),
        .y           ( y                   ),
        .vb          ( vb                  ),
        .rgb_in      ( panel_rgb           ),
        .rgb_out     ( {red, green, blue}  ),
        .ram_wr_addr ( flip_wr_addr        ),
        .ram_rd_addr ( flip_rd_addr        ),
        .ram_data    ( {flipbuf2_din, flipbuf1_din, flipbuf0_din} ),
        .ram_we      ( flip_wr_we          ),
        .ram_q       ( {flipread2_data, flipread1_data, flipread0_data} )
    );

    // Builds without JTFRAME_RELEASE draw a non-zero debug_view over the
    // picture (jtframe_debug, rows 224-231), across the load bar at y=228-231.
    // The load state is on screen already, so nothing is sent there.
    assign debug_view=0;
    // ---------------------------------------------------------------- sound
    // Board 96598-P as far as it is built (docs/SOUND_LOGIC.md): the D-4
    // gates, MY CAR SOUND (D-3), the D-4 sources, the other cars (D-6/D-7),
    // the rescue siren and back sound (D-2), the slip-zone sound (D-1), the
    // hi-score tune and fanfare (D-5), the mixer and SOUND OUT. Driven
    // by the connected sheets; silent in the development displays.
    // The board's switches come from the MRA's DIP menu, each 0 by default:
    // dipsw[8] set opens DIP SW. 2's back-sound contact (R424: the back
    // sound leaves the front speaker's mix), dipsw[9] set closes its contact
    // 2-15 (R423, a louder explosion).
    // With JTFRAME_STEREO (the MiSTer build) both channels carry SOUND OUT;
    // OSD "Back speaker" (status bit 18) puts BACK SOUND OUT (pad R, the
    // cabinet's second speaker) on the right channel instead.
    wire signed [15:0] snd_out, snd_back;
    wire snd_sample;
    generate if (SOUND != 0) begin : g_sound
        jtmonacogp_sound u_sound(
            // pad A28: sheet A's copy of /COIN IN for the sound board
            .clk(clk),.rst(rst),.acce(f_acce),.s_acc1_n(f_s_acc1_n),.coin_in_n(a_snd_coin_in_n),
            .game_n(a_game_n),.shift(f_shift),.nonroad_slip_n(f_nonroad_slip_n),
            // pad J (SLIP ZONE, D-1) takes /SLIPZONE by its name (sheet F
            // pad AX); the connector between them is not drawn
            .slip_n(f_slipzone_n),
            .excp(a_ex_cp),.explo_loud(dipsw[9]),.back_mix(~dipsw[8]),
            // pad P takes /RESCUE CP (sheet M IC18)
            .rescue_cp_n(rescue_cp_n),
            // pad C takes /F-SOUND by its name (sheet H pad A19, through
            // IC29 7407); the connector between them is not drawn
            .f_sound_n(h_f_sound_n),
            // D-5: pad 3 takes /HISCORE (sheet A pad AF), IC35 pin 6 takes
            // MUTE (sheet A pad A26); its PROM (prm40.ic21) is copied from
            // the ROM download at offset 8768 (rom_manifest.json)
            .hiscore_n(a_hiscore_n),.mute_in(a_mute),
            .prom_addr_d5(d5_addr),.prom_data_d5(rom19_data),
            .snd(snd_out),.snd_b(snd_back),.sample(snd_sample),
            .my_car_on(),.shift_a(),.mute(),.explo_t(),.skid_on(),.alarm());
    end else begin : g_nosound
        assign snd_out = 16'sd0;
        assign snd_back = 16'sd0;
        assign snd_sample = 1'b0;
    end endgenerate
    wire back_speaker = status[18];
`ifdef JTFRAME_STEREO
    assign snd_left  = game_view ? snd_out : 16'sd0;
    assign snd_right = game_view ? (back_speaker ? snd_back : snd_out) : 16'sd0;
`else
    assign snd=game_view ? snd_out : 16'sd0;
`endif
    assign sample=snd_sample;
    // The generated memory wrapper owns download and SDRAM signals.
`ifdef JTFRAME_STATUS
    assign st_dout=st_addr==0 ? {loaded,load_error,1'b0,selected} :
                   st_addr==1 ? bytes_loaded[7:0] : {2'b0,bytes_loaded[13:8]};
`endif
`ifdef JTFRAME_IOCTL_RD
    assign ioctl_din=0;
`endif
endmodule
