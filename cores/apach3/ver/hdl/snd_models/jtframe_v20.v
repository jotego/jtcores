/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jtframe_v20(
    input rst, clk, cen, cenb, ready, int_n, nmi_n, poll_n,
    output reg [19:0] A=0,
    input [7:0] din,
    output reg [7:0] dout=0,
    output reg [2:0] bs=7,
    output [1:0] qs,
    output reg req=0, rd_n=1, wr_n=1,
    output buslock_n
);
reg check_phase=0, half_seen=1;
integer phase_failures=0;
always @(posedge clk) begin
    if (rst) half_seen <= 1;
    else if (check_phase) begin
        if ((cen && cenb) || (cen && !half_seen)) phase_failures <= phase_failures+1;
        if (cenb) half_seen <= 1;
        else if (cen) half_seen <= 0;
    end
end
assign qs=0;
assign buslock_n=1;
endmodule
