/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_colmix_n6(
    input       clk,
    input       uds_n,
    input       reg_write,
    input       srst_n,
    input  [3:0] main_d,
    output      crkb,
    output      k051550_clk
);

reg [3:0] q;
reg j7_clk_d;
wire j7_clk = uds_n | ~reg_write;
/* The board boundary exposes only CRKB and K051550_CLK from this latch. */
/* verilator lint_off UNUSEDSIGNAL */
wire [1:0] q_unused_diag = {q[3],q[1]};
/* verilator lint_on UNUSEDSIGNAL */

always @(posedge clk or negedge srst_n)
    if (!srst_n) begin
        q <= 4'b0;
        j7_clk_d <= 1'b1;
    end else begin
        j7_clk_d <= j7_clk;
        if (j7_clk && !j7_clk_d)
            q <= main_d;
    end

assign crkb         = ~q[0];
assign k051550_clk  = ~q[2];

endmodule
