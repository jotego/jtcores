/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jtframe_z80(
    input rst_n, clk, cen, wait_n, int_n, nmi_n, busrq_n,
    output m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n,
    output [15:0] A,
    input [7:0] din,
    output [7:0] dout
);
assign {m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n}=8'hff;
assign A=0;
assign dout=0;
endmodule
