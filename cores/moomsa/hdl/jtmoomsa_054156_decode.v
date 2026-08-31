/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module jtmoomsa_054156_decode(
    input             nrcs,
    input       [7:4] ab,
    input             rw,
    input             uds_n,
    input             lds_n,
    output            reg_cs,
    output            reg_rd,
    output            reg_wr,
    output            reg_wr_hi,
    output            reg_wr_lo
);

wire reg_page = ab[7:4] <= 4'h3;

assign reg_cs    = !nrcs && reg_page;
assign reg_rd    = reg_cs && rw;
assign reg_wr    = reg_cs && !rw;
assign reg_wr_hi = reg_wr && !uds_n;
assign reg_wr_lo = reg_wr && !lds_n;

endmodule
