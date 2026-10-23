/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtseicro_wait(
    input             rst, clk,
    input      [1:0]  mode,
    input      [8:0]  h,
    input             vblank_n,
    input      [15:0] addr,
    input             mreq_n, rfsh_n,
    output            wait_n
);

// PAL provenance, decoder aliases and latch timing: ../doc/hardware_verification.md.
wire mem = addr[15] && !mreq_n && rfsh_n;
wire [3:1] mq;
wire [19:1] pin;
wire [16:15] pal_q;
reg [16:15] pal_l;
reg pending;

assign mq[1] = mem && addr[13:11]==3'd1;
assign mq[2] = mem && addr[13:11]==3'd2;
assign mq[3] = mem && addr[13:11]==3'd3;
assign pin = {vblank_n,9'd0,h[7:2],~mq};
assign wait_n = !pending;

jtseicro_pal u_pal(
    .mode ( mode  ),
    .pin  ( pin   ),
    .q    ( pal_q )
);

always @(posedge clk) begin
    pal_l <= pal_q;
    if(rst) pending <= 0;
    else if(pal_q[15] && !pal_l[15]) pending <= 0;
    else if(pal_q[16] && !pal_l[16]) pending <= 1;
end

endmodule
