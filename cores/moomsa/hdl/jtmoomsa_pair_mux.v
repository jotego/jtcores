/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_pair_mux(
    input       pair_cs,
    input       lower_lane,
    input       [7:0] pair_dout,
    output      [15:0] dout
);

assign dout = pair_cs && lower_lane ? {8'h00,pair_dout} : 16'hffff;

endmodule
