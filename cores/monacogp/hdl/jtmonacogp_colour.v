// SPDX-License-Identifier: GPL-3.0-or-later
// 96578-P sheet C (manual 420-0358, PDF page 30): the AREA register, the
// colour-plane collectors, the 74147 priority encoder IC2 and the RGB output
// stage. Pin-level transcription: docs/trace/SHEET_C_TRACE.md. Behaviour:
// docs/SHEET_C_LOGIC.md.
//
// The sheet is gates except IC79 (74174), which registers the AREA lines on
// 7M; it steps when cen7 is high (the 7 MHz edge that ends a pixel). The
// colour is combinational on the inputs and IC79. 7M itself enters IC14
// (pins 1, 2, 4, 5 -> 6), so a pixel can change colour half way: the module
// gives the colour of both halves (7M high, then low) and their average.
// Levels per channel (open-collector IC7 off, R1/R3/R5 470 ohm up, R13..R15
// 10 kohm down; IC1 adds 470 ohm down while IC3.12 is low): 0, dim 0.51 and
// full; as 4 bits 0, 8 and 15. The monitor's input load is not drawn.
// /TV-BLANKING (TR1 clamp) and /SYNCRO are left to the video timing.
//
// Pro Monaco GP (manual 420-0525, sheet C, PDF page 14), selected by pro = 1:
// pro/docs/trace/SHEET_M_C_PLUS200_TRACE.md. /+200 (R) from sheet M is one
// more input of the red collector, the 8-input NAND that is IC74 (7430) on
// Pro and IC33 here, beside EX & GAME OVER; with pro = 0 it is ignored. The
// collector's inverter (IC2 13 -> 12 on Pro, IC3 11 -> 10 here) drives the
// 74147's input 9, the highest priority, and the brightness logic, so a +200
// pixel is pure red at full brightness over whatever is underneath, as the
// trace reads for Pro.
// The other Pro changes (pro/docs/trace/SHEET_C_COMPARE.md D1-D3,
// pro/docs/SHEETS_B_C_D_PRO_LOGIC.md): EXTEND and /EXTEND are D-EXTEND and
// /D-EXTEND from sheet B (the game connects them); the blue term (Pro 57,
// IC14 1, 2, 4, 5 -> 6 here) takes D-EXTEND in place of 7M and, in place of
// IC15 (4, 5 -> 6), NOR 51 of NOT IC15 (inverter 92), BELT (D) and the
// splash term IC14 pin 8; and while that term is low a fourth 7417 section
// pulls BLUE down through R8 470 ohm on its own (bdim): blue is then 8 at
// full brightness and 0.34 of full, 5, with the common pull-down too.
module jtmonacogp_colour(
    input            clk, rst,
    input            cen7,              // IC79 clock: the 7 MHz edge
    // Sheet H
    input      [5:1] area,              // AREA 1..5, pads FL, FK, F9, F10, F11
    input            other_body_n,      // pad ER: IC86 enables
    input            other_tiar_n, other_car_n,
    // Sheet D
    input            road_n, tg_g_n, tg_bl_n, house_st_n, grass_area_n, grass_w_n,
    input            road,              // ROAD (no overbar): IC5 pins 2, 5
    input      [3:0] house_n,           // /HOUSE (W), (St), (Mu), (R)
    input            tunnel_ap, bridge_ap, green_belt_n, y_line_n, gravel_n,
    input            pool_n, slip_n, wall_n, side_line_n,
    // Sheet A (on Pro: D-EXTEND and /D-EXTEND from sheet B)
    input            extend, extend_n,
    // Sheet B
    input            coin_start_n, ex_gameover_n,
    input            v4d,               // V-(4), IC54 output
    // Sheet G (/LIGHT, /SPLAY and the explosion lines come from untraced paths)
    input            light_n, splay_n, explo_y_n, explo_r_n, explo_area_n,
    input            player_n, player_body_n, player_tiar_n, player_bl_n,
    // Sheet M
    input            sig_bl_n, sig_y_n, dummy_area_n, dummy_bl_n, dummy_w_n, dummy_r_n,
    input            rescue_bl_n, rescue_w_n, rescue_y_n, rescue_r_n,
    input            bridge_dbu_n, bridge_bu_n, bridge_y_n, bridge_w_n, bridge_r_n,
    // Pro board (sheets M and D); ignored while pro = 0
    input            pro,               // 1: Pro Monaco GP board
    input            plus200_n,         // /+200 (R), IC129 pin 6: one more red collector input
    input            belt,              // BELT (D) -> Pro 51 pin 3
    // Colour: {GREEN, BLUE, RED, IC3.12 (full brightness)} for 7M high and
    // low, and the 4-bit average
    output     [3:0] grb_hi, grb_lo,
    output     [3:0] code_hi, code_lo,  // IC2's input number (0 = none)
    output           bdim_hi, bdim_lo,  // Pro: R8 pulls BLUE down (0 with pro = 0)
    output     [3:0] red, green, blue
);
    // IC86 (74368, enabled while /OTHER BODY is low; its outputs float high
    // otherwise) and IC79: Q = NOT AREA of the pixel before.
    reg [5:1] q79;
    always @(posedge clk) begin
        if (rst) q79 <= 5'h1f;
        else if (cen7) q79 <= other_body_n ? 5'h1f : ~area;
    end

    wire [8:0] mh, ml;
    jtmonacogp_colour_mix u_hi(.m7(1'b1),.q79(q79),.mix(mh),
        .other_body_n(other_body_n),.other_tiar_n(other_tiar_n),.other_car_n(other_car_n),
        .road_n(road_n),.road(road),.tg_g_n(tg_g_n),.tg_bl_n(tg_bl_n),.house_st_n(house_st_n),
        .grass_area_n(grass_area_n),.grass_w_n(grass_w_n),.house_n(house_n),.tunnel_ap(tunnel_ap),
        .bridge_ap(bridge_ap),.green_belt_n(green_belt_n),.y_line_n(y_line_n),.gravel_n(gravel_n),
        .pool_n(pool_n),.slip_n(slip_n),.wall_n(wall_n),.side_line_n(side_line_n),.extend(extend),
        .extend_n(extend_n),.coin_start_n(coin_start_n),.ex_gameover_n(ex_gameover_n),.v4d(v4d),
        .light_n(light_n),.splay_n(splay_n),.explo_y_n(explo_y_n),.explo_r_n(explo_r_n),
        .explo_area_n(explo_area_n),.player_n(player_n),.player_body_n(player_body_n),
        .player_tiar_n(player_tiar_n),.player_bl_n(player_bl_n),.sig_bl_n(sig_bl_n),
        .sig_y_n(sig_y_n),.dummy_area_n(dummy_area_n),.dummy_bl_n(dummy_bl_n),
        .dummy_w_n(dummy_w_n),.dummy_r_n(dummy_r_n),.rescue_bl_n(rescue_bl_n),
        .rescue_w_n(rescue_w_n),.rescue_y_n(rescue_y_n),.rescue_r_n(rescue_r_n),
        .bridge_dbu_n(bridge_dbu_n),.bridge_bu_n(bridge_bu_n),.bridge_y_n(bridge_y_n),
        .bridge_w_n(bridge_w_n),.bridge_r_n(bridge_r_n),.pro(pro),.plus200_n(plus200_n),.belt(belt));
    jtmonacogp_colour_mix u_lo(.m7(1'b0),.q79(q79),.mix(ml),
        .other_body_n(other_body_n),.other_tiar_n(other_tiar_n),.other_car_n(other_car_n),
        .road_n(road_n),.road(road),.tg_g_n(tg_g_n),.tg_bl_n(tg_bl_n),.house_st_n(house_st_n),
        .grass_area_n(grass_area_n),.grass_w_n(grass_w_n),.house_n(house_n),.tunnel_ap(tunnel_ap),
        .bridge_ap(bridge_ap),.green_belt_n(green_belt_n),.y_line_n(y_line_n),.gravel_n(gravel_n),
        .pool_n(pool_n),.slip_n(slip_n),.wall_n(wall_n),.side_line_n(side_line_n),.extend(extend),
        .extend_n(extend_n),.coin_start_n(coin_start_n),.ex_gameover_n(ex_gameover_n),.v4d(v4d),
        .light_n(light_n),.splay_n(splay_n),.explo_y_n(explo_y_n),.explo_r_n(explo_r_n),
        .explo_area_n(explo_area_n),.player_n(player_n),.player_body_n(player_body_n),
        .player_tiar_n(player_tiar_n),.player_bl_n(player_bl_n),.sig_bl_n(sig_bl_n),
        .sig_y_n(sig_y_n),.dummy_area_n(dummy_area_n),.dummy_bl_n(dummy_bl_n),
        .dummy_w_n(dummy_w_n),.dummy_r_n(dummy_r_n),.rescue_bl_n(rescue_bl_n),
        .rescue_w_n(rescue_w_n),.rescue_y_n(rescue_y_n),.rescue_r_n(rescue_r_n),
        .bridge_dbu_n(bridge_dbu_n),.bridge_bu_n(bridge_bu_n),.bridge_y_n(bridge_y_n),
        .bridge_w_n(bridge_w_n),.bridge_r_n(bridge_r_n),.pro(pro),.plus200_n(plus200_n),.belt(belt));
    assign {bdim_hi, code_hi, grb_hi} = mh;
    assign {bdim_lo, code_lo, grb_lo} = ml;
    function [3:0] lvl(input on, input full);
        lvl = !on ? 4'd0 : full ? 4'd15 : 4'd8;
    endfunction
    // Blue with Pro's R8 as well: one 470 ohm pull-down gives 8, two give
    // 10k || 235 against 470 up, 0.344 of full: 5.
    function [3:0] lvlb(input on, input full, input dim);
        lvlb = !dim ? lvl(on, full) : !on ? 4'd0 : full ? 4'd8 : 4'd5;
    endfunction
    wire [4:0] r2 = lvl(grb_hi[1], grb_hi[0]) + lvl(grb_lo[1], grb_lo[0]);
    wire [4:0] b2 = lvlb(grb_hi[2], grb_hi[0], bdim_hi) + lvlb(grb_lo[2], grb_lo[0], bdim_lo);
    wire [4:0] g2 = lvl(grb_hi[3], grb_hi[0]) + lvl(grb_lo[3], grb_lo[0]);
    assign red   = r2[4:1];
    assign green = g2[4:1];
    assign blue  = b2[4:1];
endmodule

// One evaluation of the sheet's gates for a given level of 7M
module jtmonacogp_colour_mix(
    input            m7,
    input      [5:1] q79,               // IC79 Q1..Q5
    // Sheet H
    input            other_body_n,      // pad ER: IC86 enables
    input            other_tiar_n, other_car_n,
    // Sheet D
    input            road_n, tg_g_n, tg_bl_n, house_st_n, grass_area_n, grass_w_n,
    input            road,              // ROAD (no overbar): IC5 pins 2, 5
    input      [3:0] house_n,           // /HOUSE (W), (St), (Mu), (R)
    input            tunnel_ap, bridge_ap, green_belt_n, y_line_n, gravel_n,
    input            pool_n, slip_n, wall_n, side_line_n,
    // Sheet A
    input            extend, extend_n,
    // Sheet B
    input            coin_start_n, ex_gameover_n,
    input            v4d,               // V-(4), IC54 output
    // Sheet G (/LIGHT, /SPLAY and the explosion lines come from untraced paths)
    input            light_n, splay_n, explo_y_n, explo_r_n, explo_area_n,
    input            player_n, player_body_n, player_tiar_n, player_bl_n,
    // Sheet M
    input            sig_bl_n, sig_y_n, dummy_area_n, dummy_bl_n, dummy_w_n, dummy_r_n,
    input            rescue_bl_n, rescue_w_n, rescue_y_n, rescue_r_n,
    input            bridge_dbu_n, bridge_bu_n, bridge_y_n, bridge_w_n, bridge_r_n,
    // Pro board (sheets M and D); ignored while pro = 0
    input            pro,               // 1: Pro Monaco GP board
    input            plus200_n,         // /+200 (R), IC129 pin 6: one more red collector input
    input            belt,              // BELT (D)
    output reg [8:0] mix                // {R8 dim, IC2 code, GREEN, BLUE, RED, IC3.12}
);
    reg n21_6, n19b_8, n15a_3, n13_8, n10a_3, n3_12, n19c_6, n66_12, n26_6;
    reg n15b_6, n8c_12, n9b_6, s5_1, s5_2, s5_3, s5_4, n14a_6, n14b_8, n9a_8, n10b_8;
    reg s20_1, s20_2, s20_3, s20_4, n44_12, n45_11, n51_6;
    reg p_bu, p_mu, p_g, p_y, p_c, p_w, p_bl, p_r;     // planes, active low
    reg [3:0] n;
    always @* begin
            n21_6  = tg_g_n & house_st_n & grass_area_n;               // IC21 (7411)
            n19b_8 = ~(road_n & n21_6 & tg_bl_n);                      // IC19 9, 10, 11
            n15a_3 = road_n & light_n;                                 // IC15 1, 2
            n66_12 = player_n & dummy_area_n & explo_area_n;           // IC66 (7411)
            n19c_6 = ~(light_n & tunnel_ap & n66_12);                  // IC19 3, 4, 5
            n26_6  = ~(n19c_6 & sig_bl_n & dummy_bl_n & player_bl_n);  // IC26 (7420)
            n15b_6 = rescue_bl_n & gravel_n;                           // IC15 4, 5
            n8c_12 = rescue_bl_n & other_car_n & n66_12;               // IC8 1, 2, 13
            n9b_6  = ~(v4d & bridge_dbu_n);                            // IC9 4, 5
            // IC5 (74157), S = BRIDGE AP
            s5_1 = bridge_ap ? n9b_6       : road;
            s5_2 = bridge_ap ? bridge_bu_n : road;
            s5_3 = bridge_ap ? bridge_y_n  : y_line_n;
            s5_4 = bridge_ap ? bridge_w_n  : side_line_n;
            n14b_8 = ~(splay_n & pool_n & slip_n & house_n[2]);        // IC14 9, 10, 12, 13
            // Pro: 51 (4, 3, 5 -> 6) NOR(92 (1 -> 2) NOT IC15 pin 6, BELT,
            // the splash term); 57 (5, 1, 2, 4 -> 6) takes D-EXTEND for 7M
            n51_6  = ~(~n15b_6 | belt | n14b_8);
            n14a_6 = pro ? ~(extend & n51_6 & n8c_12 & s5_1)
                         : ~(m7 & n15b_6 & n8c_12 & s5_1);              // IC14 1, 2, 4, 5
            n9a_8  = ~(n14b_8 & n8c_12);                               // IC9 9, 10
            n10b_8 = extend_n | s5_2;                                  // IC10 9, 10
            // IC3.10 (the red plane) feeds IC13 as well
            n44_12 = ~(house_n[0] & wall_n & bridge_r_n);              // IC44
            n45_11 = ~(n44_12 & n66_12);                               // IC45
            p_r    = ~(~(rescue_r_n & dummy_r_n & explo_r_n & player_body_n &
                         n45_11 & ex_gameover_n &
                         (plus200_n | ~pro)));                         // IC33 (T.P. open), IC3; Pro: IC74, IC2
            p_c    = q79[5] & coin_start_n & n9a_8;                    // IC8 9, 10, 11
            n13_8  = ~(tg_bl_n & n8c_12 & y_line_n & p_r & p_c & green_belt_n & n21_6);  // IC13
            n10a_3 = n13_8 | n15a_3;                                   // IC10 1, 2
            n3_12  = ~(~(n10a_3 | extend));                            // IC34, IC3 13 -> 12
            // IC20 (74157), S = EXTEND; 1B not drawn (high)
            s20_1 = extend ? 1'b1   : tg_g_n;
            s20_2 = extend ? tg_g_n : n10a_3;
            s20_3 = extend ? n14a_6 : grass_w_n;
            s20_4 = extend ? tg_bl_n : n19b_8;
            p_g   = q79[3] & s20_1;                                    // IC8 3, 4, 5 (4 open)
            p_bu  = ~(~(q79[1] & s20_3 & n10b_8));                     // IC19 1, 2, 13, IC3 9 -> 8
            p_mu  = q79[2] & house_n[1];                               // IC58
            p_y   = ~(~(rescue_y_n & s20_4 & explo_y_n & q79[4] & s5_3 & sig_y_n));          // IC4, IC3
            p_w   = ~(~(dummy_w_n & rescue_w_n & s5_4 & player_tiar_n & s20_2 &
                        other_tiar_n & house_n[3]));                   // IC27, IC3
            p_bl  = ~n26_6;                                            // IC3 1 -> 2
            // IC2 (74147): the highest active input wins
            n = !p_r ? 4'd9 : !p_bl ? 4'd8 : !p_w ? 4'd7 : !p_c ? 4'd6 : !p_y ? 4'd5 :
                !p_g ? 4'd4 : !p_mu ? 4'd3 : !p_bu ? 4'd2 : 4'd0;
            // IC7 inverts A, B, C: RED = bit 0, BLUE = bit 1, GREEN = bit 2
            // Pro: 7417 (11 -> 10) and R8 on BLUE while 57 pin 6 is low
            mix = {pro & ~n14a_6, n, n[2], n[1], n[0], n3_12};
    end

endmodule
