/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_soundram(
    input         clk,
    input  [14:0] addr,
    input  [7:0]  data_in,
    input         ram_ce_n,
    input         ram_oe_n,
    input         ram_we_n,
    output [7:0]  data_out
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] mem [0:32767];

always @(posedge clk)
    if (!ram_ce_n && !ram_we_n)
        mem[addr] <= data_in;

assign data_out = (ram_ce_n || ram_oe_n) ? 8'hff : mem[addr];

endmodule
