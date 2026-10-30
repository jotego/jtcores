/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jt51(
    input rst, clk, cen, cen_p1, cs_n, wr_n, a0,
    input [7:0] din,
    output [7:0] dout,
    output ct1, ct2, irq_n, sample,
    output [15:0] left, right,
    output signed [15:0] xleft, xright
);
integer writes=0;
always @(posedge clk) if (!rst && cen_p1 && !cs_n && !wr_n) writes <= writes+1;
assign dout=8'h51;
assign {ct1,ct2,sample}=0;
assign irq_n=1;
assign left=0;
assign right=0;
assign xleft=0;
assign xright=0;
endmodule
