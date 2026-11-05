/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtnarc_cab(
    input             clk,
    input      [ 8:0] joystick1, joystick2,
    input      [ 3:0] coin,
    input      [ 3:0] cab_1p,
    input             dip_test,
    input             tilt,
    input      [ 7:0] tb_data,
    input             tb_ack_n,
    output reg [15:0] in0,
    output reg [15:0] in1,
    output reg [15:0] in2
);

wire [7:0] p1 = { joystick1[6], joystick1[5], joystick1[4], joystick1[7],
                  joystick1[0], joystick1[1], joystick1[2], joystick1[3] };
wire       advance = dip_test & joystick1[8] & joystick2[8];
wire [7:0] p2 = { joystick2[6], joystick2[5], joystick2[4], joystick2[7],
                  joystick2[0], joystick2[1], joystick2[2], joystick2[3] };

always @(posedge clk) begin
    in0 <= { p2, p1 };
    in1 <= { 2'b11, 2'b11, 1'b1, tb_ack_n, cab_1p[1:0], coin[3], 1'b1, 1'b1, advance, tilt, coin[2:0] };
    in2 <= { 8'hff, tb_data };
end

endmodule
