/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_mcolb_mux(
    input [2:0] col,
    input       ncol,
    input       brit,
    input [1:0] sdo,
    input       cram_cs_n,
    input       strobe_g_n,
    output [7:0] mcolb
);

wire [3:0] h9_i0 = {1'b0,col};
wire [3:0] h9_i1 = 4'b0111;
wire [3:0] h8_i0 = {sdo[1],sdo[0],brit,ncol};
wire [3:0] h8_i1 = 4'b0001;

assign mcolb = strobe_g_n ? 8'h00 :
               (cram_cs_n ? {h8_i1,h9_i1} : {h8_i0,h9_i0});

endmodule
