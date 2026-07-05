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
    Date: 2-7-2026 */

module jtgae1_vram_decrypt(
    input  [ 5:0] key,
    input  [15:0] prev_ciph,
    input  [15:0] prev_plain,
    input  [15:0] din,
    output [15:0] dout
);

localparam [15:0] BASE_XOR = 16'h4228;

wire [ 1:0] bit_order = {prev_plain[8], prev_plain[7]};
wire [ 1:0] tap_sel   = {prev_plain[12], prev_plain[2]};

reg  [15:0] perm;
reg  [ 5:0] low_key;
reg  [ 4:0] page_key;

always @(*) begin
    case (bit_order)
        2'd0: perm = {
            din[ 1], din[ 2], din[ 0], din[14], din[12], din[15], din[ 4], din[ 8],
            din[13], din[ 7], din[ 3], din[ 6], din[11], din[ 5], din[10], din[ 9]
        };
        2'd1: perm = {
            din[14], din[10], din[ 4], din[15], din[ 1], din[ 6], din[12], din[11],
            din[ 8], din[ 0], din[ 9], din[13], din[ 7], din[ 3], din[ 5], din[ 2]
        };
        2'd2: perm = {
            din[ 2], din[13], din[15], din[ 1], din[12], din[ 8], din[14], din[ 4],
            din[ 6], din[ 0], din[ 9], din[ 5], din[10], din[ 7], din[ 3], din[11]
        };
        2'd3: perm = {
            din[ 3], din[ 8], din[ 1], din[13], din[14], din[ 4], din[15], din[ 0],
            din[10], din[ 2], din[ 7], din[12], din[ 6], din[11], din[ 9], din[ 5]
        };
    endcase

    case (tap_sel)
        2'd0: low_key = 6'b111010;
        2'd1: low_key = {prev_ciph[15], prev_ciph[8], prev_ciph[3], prev_plain[1], prev_plain[1], prev_plain[0]};
        2'd2: low_key = {prev_ciph[14], prev_ciph[13], prev_ciph[3], prev_ciph[7], prev_plain[5], prev_ciph[5]};
        2'd3: low_key = {prev_plain[11], prev_ciph[2], prev_plain[4], prev_ciph[6], prev_ciph[9], prev_ciph[0]};
    endcase
end

wire [15:0] unmasked = perm ^ BASE_XOR;
wire [ 5:0] low_step = low_key ^ key;
wire [ 5:0] low_sum  = unmasked[5:0] + low_step;
wire [15:0] low_mix  = {unmasked[15:6], low_sum} ^ {10'd0, key};

always @(*) begin
    case (tap_sel)
        2'd0: page_key = {low_mix[4], low_mix[5], din[5], low_mix[2], din[9]};
        2'd1: page_key = {prev_plain[12], low_mix[1], prev_plain[14], prev_ciph[4], prev_plain[2]};
        2'd2: page_key = {prev_plain[7], low_mix[0], prev_plain[15], prev_plain[6], prev_ciph[6]};
        2'd3: page_key = {prev_ciph[10], prev_plain[1], prev_ciph[5], prev_plain[9], prev_plain[2]};
    endcase
end

wire [ 4:0] page_step = page_key ^ key[4:0];
wire [ 4:0] mid_sum   = low_mix[10:6] + page_step;
wire [ 4:0] high_sum  = low_mix[15:11] + page_step;
wire [15:0] page_mix  = {high_sum, mid_sum, low_mix[5:0]};
wire [15:0] page_mask = {4'b0, key, 6'b0} | {key[4:0], 11'b0};
wire [15:0] plain     = page_mix ^ page_mask;

assign dout = {
    plain[ 2], plain[ 6], plain[ 0], plain[11], plain[14], plain[12], plain[ 7], plain[10],
    plain[ 5], plain[ 4], plain[ 8], plain[ 3], plain[ 9], plain[ 1], plain[13], plain[15]
};
endmodule
