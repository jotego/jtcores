/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_objram_lanes(
    input         clk,
    input  [4:0]  ea,
    input  [7:0]  en,
    input  [15:0] lutd_in,
    input         we_n,
    input         oe_n,
    output [15:0] lutd_out
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram_lo [0:8191];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram_hi [0:8191];
wire [12:0] addr = {en,ea[3:0],ea[4]};

always @(posedge clk)
    if (!we_n) begin
        ram_lo[addr] <= lutd_in[7:0];
        ram_hi[addr] <= lutd_in[15:8];
    end

assign lutd_out = oe_n ? 16'hffff : {ram_hi[addr],ram_lo[addr]};

endmodule
