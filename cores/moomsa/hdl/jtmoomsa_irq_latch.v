/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_irq_latch(
    input  clk,
    input  rst,
    input  objdma_n,
    input  irq_set,
    output reg irq_n
);

reg objdma_q;

always @(posedge clk or posedge rst) begin
    if (rst) objdma_q <= 1'b1;
    else     objdma_q <= objdma_n;
end

always @(posedge clk or posedge rst or negedge irq_set) begin
    if (rst || !irq_set) irq_n <= 1'b1;
    else if (objdma_n && !objdma_q) irq_n <= 1'b0;
end

endmodule
