/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jtframe_68kdtack_cen #(parameter W=5, RECOVERY=1)(
    input rst, clk,
    output cpu_cen, cpu_cenb,
    input bus_cs, bus_busy, bus_legit, bus_ack, ASn,
    input [1:0] DSn,
    input [W-2:0] num,
    input [W-1:0] den,
    input wait2, wait3,
    output DTACKn,
    output [15:0] fave, fworst
);
assign cpu_cen=0;
assign cpu_cenb=0;
assign DTACKn=0;
assign fave=0;
assign fworst=0;
endmodule
