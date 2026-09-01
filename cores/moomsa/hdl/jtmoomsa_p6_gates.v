/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_p6_gates(
    input  pre_dtack_n,
    output scrcs,
    output dtack_pre
);

assign scrcs     = ~pre_dtack_n;
assign dtack_pre = ~pre_dtack_n;

endmodule
