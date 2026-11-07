/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-8-2026 */

// F22, the video bus mutex: one 74LS74 with its halves clocked on opposite
// phases of the 24 MHz clock, each Q asynchronously presetting the other.
// Active low: req_n=0 requests, grant_n=0 is granted. Idle grants nobody.
// The a side is clocked on the earlier phase, so it wins under sustained
// contention.

module jtgrad3_arbiter(
    input       rst,
    input       clk,
    input       cen24,
    input       a_req_n,
    input       b_req_n,
    output reg  a_grant_n,
    output reg  b_grant_n
);

reg cen24b;

always @(posedge clk) cen24b <= cen24;

always @(posedge clk) begin
    if( rst ) begin
        a_grant_n <= 1;
        b_grant_n <= 1;
    end else begin
        if( !b_grant_n ) a_grant_n <= 1; else if( cen24  ) a_grant_n <= a_req_n;
        if( !a_grant_n ) b_grant_n <= 1; else if( cen24b ) b_grant_n <= b_req_n;
    end
end

endmodule
