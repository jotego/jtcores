/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-7-2026 */

module jtgals_calc(
    input              rst,
    input              clk,
    input              cs,
    input              rnw,
    input       [ 1:0] dsn,
    input       [ 3:0] addr,
    input       [15:0] din,
    output reg  [15:0] dout
);

reg  [15:0] x1p, x1s, y1p, y1s, x2p, x2s, y2p, y2s;
reg  [15:0] mult_a, mult_b, lfsr;
wire [31:0] mult;
wire signed [16:0] x12, y12, x21, y21;
wire        write, overlap;
wire [15:0] coll, din_masked;

assign write   = cs && !rnw && dsn != 2'b11;
assign din_masked = { dsn[1] ? 8'd0 : din[15:8], dsn[0] ? 8'd0 : din[7:0] };
assign mult    = mult_a * mult_b;
assign x12     = { 1'b0, x1p } - ({ 1'b0, x2p } + { 1'b0, x2s });
assign y12     = { 1'b0, y1p } - ({ 1'b0, y2p } + { 1'b0, y2s });
assign x21     = ({ 1'b0, x1p } + { 1'b0, x1s }) - { 1'b0, x2p };
assign y21     = ({ 1'b0, y1p } + { 1'b0, y1s }) - { 1'b0, y2p };
assign overlap = x12 < 0 && y12 < 0 && x21 >= 0 && y21 >= 0;
assign coll    = {
    y1p < y2p, y1p == y2p, y1p > y2p, 1'b0,
    x1p < x2p, x1p == x2p, x1p > x2p, 8'd0,
    overlap
};

always @(posedge clk) begin
    if (rst) begin
        x1p    <= 16'd0;
        x1s    <= 16'd0;
        y1p    <= 16'd0;
        y1s    <= 16'd0;
        x2p    <= 16'd0;
        x2s    <= 16'd0;
        y2p    <= 16'd0;
        y2s    <= 16'd0;
        mult_a <= 16'd0;
        mult_b <= 16'd0;
        lfsr   <= 16'hace1;
    end else begin
        lfsr <= { lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10] };
        if (write) begin
            case (addr)
                4'h0: x1p    <= din_masked;
                4'h1: x1s    <= din_masked;
                4'h2: y1p    <= din_masked;
                4'h3: y1s    <= din_masked;
                4'h4: x2p    <= din_masked;
                4'h5: x2s    <= din_masked;
                4'h6: y2p    <= din_masked;
                4'h7: y2s    <= din_masked;
                4'h8: mult_a <= din_masked;
                4'h9: mult_b <= din_masked;
                default:;
            endcase
        end
    end
end

always @(posedge clk) begin
    case (addr)
        4'h0: dout <= 16'd0;
        4'h1: dout <= 16'd0;
        4'h2: dout <= coll;
        4'h8: dout <= mult[31:16];
        4'h9: dout <= mult[15:0];
        4'ha: dout <= lfsr;
        default: dout <= 16'd0;
    endcase
end

endmodule
