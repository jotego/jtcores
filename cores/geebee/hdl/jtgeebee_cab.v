/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 07-11-2026 */

module jtgeebee_cab(
    input            clk,
    input            rst,
    input      [6:0] joystick1,
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

reg [7:0] paddle_pos;
reg [12:0] paddle_div;

assign sw0 = {2'b11, service, joystick1[4], cab_1p, coin};
assign sw1 = 8'hff;
assign dsw = dipsw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        paddle_pos <= 8'h58;
        paddle     <= 8'h58;
        paddle_div <= 0;
    end else if (paddle_div == 13'd4095) begin
        paddle_div <= 0;
        if (!joystick1[0] && joystick1[1]) paddle_pos <= paddle_pos - 1'b1;
        if (!joystick1[1] && joystick1[0]) paddle_pos <= paddle_pos + 1'b1;
    end else begin
        paddle_div <= paddle_div + 1'b1;
    end
    if (!rst && v == paddle_pos) paddle <= v;
end

endmodule
