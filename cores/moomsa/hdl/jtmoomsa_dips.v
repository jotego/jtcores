/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_dips(
    input  [3:0] sw,
    output       stereo,
    output       independent_coin,
    output [2:0] players,
    output       players_valid
);

assign stereo = sw[0];
assign independent_coin = sw[1];
assign players = sw[3:2] == 2'b00 ? 3'd2 :
                 sw[3:2] == 2'b01 ? 3'd3 : 3'd4;
assign players_valid = sw[3:2] != 2'b11;

endmodule
