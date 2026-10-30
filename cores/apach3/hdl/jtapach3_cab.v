/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */

module jtapach3_cab(
    input             rst,
    input             clk,
    input             LVBL,
    input       [6:0] joystick,
    input      [15:0] joyana_l,
    input      [15:0] joyana_r,
    input             digital,
    input             invert_y,
    input             throttle_y,
    input             test_n,
    input             service_n,
    input       [1:0] coin_n,
    input             start_n,
    output      [7:0] in0,
    output      [7:0] stick_x,
    output      [7:0] stick_y,
    output      [7:0] throttle
);

reg lvbl_l;
reg [7:0] digital_x, digital_y;
wire [7:0] selected_y = digital ? digital_y : joyana_l[15:8] ^ 8'h80;

assign in0 = {joystick[5],start_n,service_n,coin_n,joystick[6],joystick[4],test_n};
assign stick_x = digital ? digital_x : joyana_l[7:0] ^ 8'h80;
assign stick_y = invert_y ? ~selected_y : selected_y;
assign throttle = (throttle_y ? joyana_r[15:8] : joyana_r[7:0]) ^ 8'h80;

function [7:0] step_axis;
    input [7:0] position;
    input negative_n, positive_n;
    begin
        if (!negative_n && positive_n)
            step_axis = position < 15 ? 8'd0 : position-8'd15;
        else if (negative_n && !positive_n)
            step_axis = position > 240 ? 8'd255 : position+8'd15;
        else if (position < 127)
            step_axis = position > 112 ? 8'd127 : position+8'd15;
        else
            step_axis = position < 142 ? 8'd127 : position-8'd15;
    end
endfunction

always @(posedge clk) begin
    lvbl_l <= LVBL;
    if (rst || !digital) begin
        digital_x <= 8'h7f;
        digital_y <= 8'h7f;
    end else if (lvbl_l && !LVBL) begin
        digital_x <= step_axis(digital_x,joystick[1],joystick[0]);
        digital_y <= step_axis(digital_y,joystick[3],joystick[2]);
    end
end

endmodule
