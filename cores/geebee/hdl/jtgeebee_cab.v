/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 07-11-2026 */

module jtgeebee_cab(
    input            clk,
    input            rst,
    input      [4:0] joystick1,
    input      [15:0] joyana_l1,
    input      [15:0] joyana_l2,
    input      [1:0] dial_x,
    input      [1:0] dial_y,
    input            flip,
    input      [1:0] cab_1p,
    input      [1:0] coin,
    input            service,
    input      [7:0] dipsw,
    input      [7:0] v,
    output     [7:0] sw0,
    output     [7:0] sw1,
    output     [7:0] dsw,
    output reg [7:0] paddle
);

reg [7:0] paddle_pos_1p, paddle_pos_2p;
reg [1:0] dial_x_last, dial_y_last;
wire signed [8:0] analog_1p = {joyana_l1[7], joyana_l1[7:0]};
wire signed [8:0] analog_2p = {joyana_l2[7], joyana_l2[7:0]};
wire [7:0] analog_pos_1p = 9'sd88 - (analog_1p >>> 1) - (analog_1p >>> 4);
wire [7:0] analog_pos_2p = 9'sd88 - (analog_2p >>> 1) - (analog_2p >>> 4);
wire [7:0] active_pos_1p = |joyana_l1[7:0] ? analog_pos_1p : paddle_pos_1p;
wire [7:0] active_pos_2p = |joyana_l2[7:0] ? analog_pos_2p : paddle_pos_2p;
wire [7:0] paddle_pos = flip ? active_pos_2p : active_pos_1p;

assign sw0 = {2'b11, service, joystick1[4], cab_1p, coin};
assign sw1 = 8'hff;
assign dsw = dipsw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        paddle_pos_1p <= 8'h58;
        paddle_pos_2p <= 8'h58;
        dial_x_last <= 2'b00;
        dial_y_last <= 2'b00;
        paddle <= 8'h58;
    end else begin
        dial_x_last <= dial_x;
        dial_y_last <= dial_y;
        if (|joyana_l1[7:0]) paddle_pos_1p <= 8'h58;
        else if (dial_x == {dial_x_last[0], ~dial_x_last[1]} && paddle_pos_1p > 8'h10)
            paddle_pos_1p <= paddle_pos_1p - 1'b1;
        else if (dial_x == {~dial_x_last[0], dial_x_last[1]} && paddle_pos_1p < 8'ha0)
            paddle_pos_1p <= paddle_pos_1p + 1'b1;
        if (|joyana_l2[7:0]) paddle_pos_2p <= 8'h58;
        else if (dial_y == {dial_y_last[0], ~dial_y_last[1]} && paddle_pos_2p > 8'h10)
            paddle_pos_2p <= paddle_pos_2p - 1'b1;
        else if (dial_y == {~dial_y_last[0], dial_y_last[1]} && paddle_pos_2p < 8'ha0)
            paddle_pos_2p <= paddle_pos_2p + 1'b1;
        if (v == paddle_pos) paddle <= v;
    end
end

endmodule
