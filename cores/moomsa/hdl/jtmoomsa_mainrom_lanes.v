/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_mainrom_lanes(
    input        bank_t,
    input  [7:0] q_lo,
    input  [7:0] q_hi,
    input  [7:0] t_lo,
    input  [7:0] t_hi,
    output [15:0] data
);

assign data = bank_t ? {t_hi,t_lo} : {q_hi,q_lo};

endmodule
