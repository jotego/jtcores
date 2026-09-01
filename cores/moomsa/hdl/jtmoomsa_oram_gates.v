/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_oram_gates(
    input  rw,
    input  uds,
    input  lds,
    input  oram_we,
    output bds,
    output oram_u,
    output oram_l,
    output oram_weh,
    output oram_wel,
    output mrd
);

assign bds = uds & lds;
assign oram_u = rw | uds;
assign oram_l = rw | lds;
assign oram_weh = oram_we | oram_u;
assign oram_wel = oram_we | oram_l;
assign mrd = ~lds;

endmodule
