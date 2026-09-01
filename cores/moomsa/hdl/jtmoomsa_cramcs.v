/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_cramcs(
    input        mclk2,
    input  [3:0] ci,
    output reg   cramcs
);

always @(posedge mclk2)
    cramcs <= |ci;

endmodule
