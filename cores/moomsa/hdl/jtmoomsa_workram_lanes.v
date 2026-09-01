/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_workram_lanes(
    input         clk,
    input  [14:0] addr,
    input  [15:0] din,
    input         cs_n,
    input         oe_n,
    input         we_lo_n,
    input         we_hi_n,
    output [15:0] dout,
    output        read_valid
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] lo [0:32767];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] hi [0:32767];

always @(posedge clk) begin
    if (!cs_n) begin
        if (!we_lo_n) lo[addr] <= din[7:0];
        if (!we_hi_n) hi[addr] <= din[15:8];
    end
end

assign read_valid = !cs_n && !oe_n && we_lo_n && we_hi_n;
assign dout       = (!cs_n && !oe_n) ? {hi[addr],lo[addr]} : 16'hffff;

endmodule
