/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_palette_lanes(
    input         clk,
    input  [10:0] rab,
    input  [23:0] db_in,
    input         ce_n,
    input  [2:0]  oe_n,
    input  [2:0]  we_n,
    output [23:0] db_out
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram_r [0:2047];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram_g [0:2047];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram_b [0:2047];

always @(posedge clk) begin
    if (!ce_n && !we_n[0]) ram_r[rab] <= db_in[7:0];
    if (!ce_n && !we_n[1]) ram_g[rab] <= db_in[15:8];
    if (!ce_n && !we_n[2]) ram_b[rab] <= db_in[23:16];
end

assign db_out[7:0]   = (ce_n || oe_n[0]) ? 8'hff : ram_r[rab];
assign db_out[15:8]  = (ce_n || oe_n[1]) ? 8'hff : ram_g[rab];
assign db_out[23:16] = (ce_n || oe_n[2]) ? 8'hff : ram_b[rab];

endmodule
