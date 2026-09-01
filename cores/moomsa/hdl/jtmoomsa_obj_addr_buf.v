/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_obj_addr_buf(
    input  [15:1] main_a,
    input         mrd,
    input         objdma_n,
    output [4:0]  ea,
    output        g5p11,
    output        g5p13,
    output [7:0]  en,
    output        f6_b7_nc
);

assign ea       = objdma_n ? 5'bz : main_a[5:1];
assign g5p11    = objdma_n ? 1'bz : main_a[6];
assign g5p13    = objdma_n ? 1'bz : main_a[7];
assign en[0]    = objdma_n ? 1'bz : main_a[8];
assign en[7:1]  = objdma_n ? 7'bz : main_a[15:9];
assign f6_b7_nc = objdma_n ? 1'bz : mrd;

endmodule
