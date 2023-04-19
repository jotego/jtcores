/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-1-2021 */

module jtcps2_keyload(
    input             clk,
    input             rst,
    input      [ 7:0] din,
    input             din_we,

    output     [15:0] addr_rng,
    output     [63:0] key,
    output            dec_en
);

reg          last_din_we;
wire [159:0] cfg;
reg  [159:0] raw;

reg          dec_en_reg;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        last_din_we <= 0;
        raw <= 160'd0;
        dec_en_reg <= 0;
    end else begin
        last_din_we <= din_we;
        if( din_we && !last_din_we ) begin
            raw <= { din, raw[159:8] };
        end

        dec_en_reg <= (addr_rng[15:0] != ~16'h0);
    end
end

assign dec_en   = dec_en_reg;

assign key      = cfg[63:0];
assign addr_rng = cfg[159:144];

assign cfg={
raw[ 10], raw[ 11], raw[ 12], raw[ 13], raw[ 14], raw[ 15], raw[  0], raw[  1],
raw[  2], raw[  3], raw[  4], raw[  5], raw[  6], raw[  7], raw[152], raw[153],
raw[ 26], raw[ 27], raw[ 28], raw[ 29], raw[ 30], raw[ 31], raw[ 16], raw[ 17],
raw[ 18], raw[ 19], raw[ 20], raw[ 21], raw[ 22], raw[ 23], raw[  8], raw[  9],
raw[ 42], raw[ 43], raw[ 44], raw[ 45], raw[ 46], raw[ 47], raw[ 32], raw[ 33],
raw[ 34], raw[ 35], raw[ 36], raw[ 37], raw[ 38], raw[ 39], raw[ 24], raw[ 25],
raw[ 58], raw[ 59], raw[ 60], raw[ 61], raw[ 62], raw[ 63], raw[ 48], raw[ 49],
raw[ 50], raw[ 51], raw[ 52], raw[ 53], raw[ 54], raw[ 55], raw[ 40], raw[ 41],
raw[ 74], raw[ 75], raw[ 76], raw[ 77], raw[ 78], raw[ 79], raw[ 64], raw[ 65],
raw[ 66], raw[ 67], raw[ 68], raw[ 69], raw[ 70], raw[ 71], raw[ 56], raw[ 57],
raw[ 90], raw[ 91], raw[ 92], raw[ 93], raw[ 94], raw[ 95], raw[ 80], raw[ 81],
raw[ 82], raw[ 83], raw[ 84], raw[ 85], raw[ 86], raw[ 87], raw[ 72], raw[ 73],

// Keys 1
raw[122], raw[123], raw[124], raw[125], raw[126], raw[127], raw[112], raw[113],
raw[114], raw[115], raw[116], raw[117], raw[118], raw[119], raw[104], raw[105],
raw[106], raw[107], raw[108], raw[109], raw[110], raw[111], raw[ 96], raw[ 97],
raw[ 98], raw[ 99], raw[100], raw[101], raw[102], raw[103], raw[ 88], raw[ 89],

// Key 0
raw[154], raw[155], raw[156], raw[157], raw[158], raw[159], raw[144], raw[145],
raw[146], raw[147], raw[148], raw[149], raw[150], raw[151], raw[136], raw[137],
raw[138], raw[139], raw[140], raw[141], raw[142], raw[143], raw[128], raw[129],
raw[130], raw[131], raw[132], raw[133], raw[134], raw[135], raw[120], raw[121]
};


endmodule