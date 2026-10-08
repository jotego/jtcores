/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtframe_mouse_abspos(
    input            clk,
    input      [7:0] dx,
    input      [7:0] dy,
    input            strobe,
    output reg [8:0] x,
    output reg [8:0] y
);

parameter W = 384, H = 224;

wire [9:0] x_next, y_next;

assign x_next = {1'b0, x} + {{2{dx[7]}}, dx};
assign y_next = {1'b0, y} - {{2{dy[7]}}, dy};

always @(posedge clk) begin
    if (strobe) begin
        if (x_next[9] && dx[7])
            x <= 0;
        else if (x_next[8:0] > W[8:0])
            x <= W[8:0];
        else
            x <= x_next[8:0];

        if (y_next[9] && !dy[7])
            y <= 0;
        else if (y_next[8:0] > H[8:0])
            y <= H[8:0];
        else
            y <= y_next[8:0];
    end
end

endmodule
