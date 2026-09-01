/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_ocol_latch(
    input       m6_n,
    input [7:0] ocol,
    output reg [7:0] pr_latched
);

always @(posedge m6_n)
    pr_latched <= ocol;

endmodule
