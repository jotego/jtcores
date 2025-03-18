/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 14-03-2025 */

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

always @(posedge clk) begin
    strobe <= joyana != joya_l;
    joya_l <= joyana;

    x_scaled <= x_corr[7:0] * W[8:0];
    y_scaled <= y_corr[7:0] * H[8:0];

    // if (~x_next[9] & joyana[7])
        // x <= 0;
    // else if (x_next[8:0] > W[8:0])
        // x <= W[8:0];
    // else
        x <= x_next[8:0];

    // if (~y_next[9] & joyana[15])
        // y <= 0;
    // else if (y_next[8:0] > H[8:0])
        // y <= H[8:0];
    // else
        y <= y_next[8:0];
end

endmodule