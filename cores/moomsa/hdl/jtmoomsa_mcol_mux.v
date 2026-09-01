/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_mcol_mux(
    input [7:0] col,
    input [7:0] l7p,
    input       cram_cs_n,
    input       strobe_g_n,
    output [7:0] mcol
);

assign mcol = strobe_g_n ? 8'h00 :
              (cram_cs_n ? l7p : col);

endmodule
