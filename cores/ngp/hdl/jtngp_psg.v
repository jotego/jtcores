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
    Date: 23-5-2023 */

module jtngp_psg(
    input                rst,
    input                clk,
    input                cen,

    input                r_wn,
    input                cs,
    input         [ 7:0] din,
    output reg           ready,
    output signed [11:0] snd_l,
    output signed [11:0] snd_r
);

reg         [10:0] tone, noise;
// wire        [9:0] att0, att1, att2;
// assign   att0 = att1 = att2 = tone;

always @(posedge clk, posedge rst) begin
    snd_l <= { {1{tone[10]}}, tone } + { {1{noise[10]}}, noise };
    snd_r <= { {1{tone[10]}}, tone } + { {1{noise[10]}}, noise };
end

/*always @(posedge clk, posedge rst) begin
        snd_l <= { {2{att0[9]}}, att0 } + { {2{att1[9]}}, att1 } + { {2{att2[9]}}, att2 } + { {2{noise[9]}}, noise };
        snd_r <= { {2{att0[9]}}, att0 } + { {2{att1[9]}}, att1 } + { {2{att2[9]}}, att2 } + { {2{noise[9]}}, noise };
    end
end*/


jt89 u_jt89right(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs        ),
    .din    ( din       ),
    .sound  ( noise     ),
    .ready  ( ready     )
);

jt89 u_jt89left(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs        ),
    .din    ( din       ),
    .sound  ( tone      ),
    .ready  ( ready     )
);

endmodule