/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_oram_cpu(
    input  [13:1] main_addr,
    input   [1:0] dsn_n,
    input         cpu_we,
    input         bus_active,
    input         objram_cs,
    output [13:1] oram_addr,
    output  [1:0] oram_we
);

assign oram_addr = main_addr;
assign oram_we   = {2{objram_cs && cpu_we && bus_active}} & ~dsn_n;

endmodule
