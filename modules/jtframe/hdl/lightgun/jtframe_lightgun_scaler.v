/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-03-2025 */

module jtframe_lightgun_scaler(
    input             clk,
    input      [15:0] joyana,
    output reg        strobe,
    output reg [ 8:0] x,
    output reg [ 8:0] y
);

parameter W = 384, H = 224;

reg  [15:0] joya_l;
wire [ 9:0] x_next, y_next;
wire [ 7:0] x_corr, y_corr;
reg  [17:0] x_scaled, y_scaled;

assign x_corr = joyana[ 7:0] + 8'h80;
assign y_corr = joyana[15:8] + 8'h80;
assign x_next = x_scaled[17:8];
assign y_next = y_scaled[17:8];

always @(*) begin
    x_scaled  = x_corr[7:0] * W[8:0];
    y_scaled  = y_corr[7:0] * H[8:0];
end

always @(posedge clk) begin
    x      <= x_next[8:0];
    y      <= y_next[8:0];
    strobe <= |joyana;
    if(strobe) strobe <= 0;
end

endmodule
