/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_color_latches(
    input       m16b,
    input       mr_n,
    input [7:0] mcol,
    input [7:0] mcolb,
    output reg [7:0] mcolr,
    output reg [7:0] mcolrb
);

always @(posedge m16b or negedge mr_n) begin
    if (!mr_n) begin
        mcolr  <= 8'h00;
        mcolrb <= 8'h00;
    end else begin
        mcolr  <= mcol;
        mcolrb <= mcolb;
    end
end

endmodule
