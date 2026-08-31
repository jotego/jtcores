/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_ci_latch(
    input       clk,
    input       mr_n,
    input [7:0] ci,
    output reg [7:0] l7p
);

always @(posedge clk or negedge mr_n) begin
    if (!mr_n)
        l7p <= 8'h00;
    else
        l7p <= ci;
end

endmodule
