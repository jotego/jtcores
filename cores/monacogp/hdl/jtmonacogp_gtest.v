// SPDX-License-Identifier: GPL-3.0-or-later
// Stand-ins for the connected game. NOT original circuitry. Every value here
// is a test choice: MiSTer buttons on the cabinet's coin, test, credit and
// tilt switches, the accelerator unit's two lines and the shift lever; the
// changeover switch (1 COIN 1 PLAY or 2 PLAY) comes from the DIP menu. Sheet
// I's score lines come from jtmonacogp_score.v and the handle pulses from
// jtmonacogp_handle.v (fed by JTFRAME's dial) since 31 October.
module jtmonacogp_gtest(
    input            clk, rst,
    input            enable,            // the connected game is on screen
    input      [5:0] joy_n,             // {B2, B1, up, down, left, right}, active low
    input      [7:0] pedal_y,           // right analog stick, up negative
    input      [7:0] pedal_t,           // right analog trigger, 0 released .. 255 full
    input            coin_n, start_n, service_n, tilt_in_n,
    input            dip_two_play,      // DIP menu: the changeover switch at 1 COIN 2 PLAY
    // Cabinet
    output           coin_sw, test_sw, credit_sw, two_play, tilt_n,
    output     [1:0] acce_ab,           // {ACCE. CONT. A, ACCE. CONT. B}
    output           shift_no, shift_nc,
    output           high_gear,         // the lever position, for the view
    // Undrawn inputs (IC27 pin 3, IC51 pin 3) float high
    output           ic27_3, ic51_3
);
    reg  [5:0] joy_l;
    reg        gear;
    wire [5:0] on = ~joy_n & {6{enable}};
    wire [5:0] press = joy_l & ~joy_n & {6{enable}};

    assign coin_sw   = enable & ~coin_n;
    assign test_sw   = enable & ~service_n;
    assign credit_sw = enable & ~start_n;
    assign two_play  = dip_two_play;    // the changeover switch (sheet A), from the DIP menu
    assign tilt_n    = ~enable | tilt_in_n;
    // Pedal positions in sheet F's order: released 11, then 01, 00, and
    // floored 10. Button 1 floors it; the right stick pushed up or the right
    // trigger pulled presses it part way or fully (a quarter, half, three
    // quarters of the travel), whichever of the two is further.
    // Like the real pedal it passes every position on the way, one about
    // every 1.4 ms, so the two lines change one at a time.
    wire [7:0] push_y = pedal_y[7] ? -pedal_y : 8'd0;  // 0..128 upwards
    wire [7:0] push_t = {1'b0, pedal_t[7:1]};          // 0..127
    wire [7:0] push = push_y > push_t ? push_y : push_t;
    wire [1:0] target = on[4] || push >= 8'd96 ? 2'd3 : push >= 8'd64 ? 2'd2 :
                        push >= 8'd32 ? 2'd1 : 2'd0;
    reg  [1:0] level;
    reg [15:0] step_cnt;
    assign acce_ab   = level == 2'd3 ? 2'b10 : level == 2'd2 ? 2'b00 : level == 2'd1 ? 2'b01 : 2'b11;
    // High gear closes NC, low gear closes NO (tests/tb_control.v).
    assign {shift_no, shift_nc} = gear ? 2'b10 : 2'b01;
    assign high_gear = gear;
    assign {ic27_3, ic51_3} = 2'b11;

    always @(posedge clk) begin
        if (rst) begin
            joy_l <= 6'h3f;
            gear <= 0;
            level <= 0;
            step_cnt <= 0;
        end else begin
            joy_l <= joy_n;
            step_cnt <= step_cnt + 16'd1;
            if (step_cnt == 0 && level != target) level <= level < target ? level + 2'd1 : level - 2'd1;
            // B2 changes over (up and down are left alone: in play they
            // would change gear by accident).
            if (press[5]) gear <= ~gear;
        end
    end
endmodule
