/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_pr_latch(
    input       m6_n,
    input       mr_n,
    input [4:0] opri,
    input [1:0] shd,
    output reg [4:0] pr,
    output reg [1:0] shdr,
    output reg       q7_unused
);

always @(posedge m6_n or negedge mr_n) begin
    if (!mr_n) begin
        pr        <= 5'b0;
        shdr      <= 2'b0;
        q7_unused <= 1'b0;
    end else begin
        pr        <= opri;
        shdr      <= shd;
        q7_unused <= 1'b0;
    end
end

endmodule
