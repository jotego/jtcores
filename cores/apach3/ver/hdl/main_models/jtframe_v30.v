/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jtframe_v30(
    input rst, clk, cen, cenb, ready, int_n, nmi_n, poll_n,
    output [19:0] A,
    input [15:0] din,
    output [15:0] dout,
    output [2:0] bs,
    output [1:0] qs,
    output rd_n, wr_n, ube_n, buslock_n
);
assign A=0;
assign dout=0;
assign bs=7;
assign qs=0;
assign rd_n=1;
assign wr_n=1;
assign ube_n=1;
assign buslock_n=1;
endmodule
