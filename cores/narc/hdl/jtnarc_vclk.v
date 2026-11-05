/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-10-2026 */

module jtnarc_vclk(
    input      rst,
    input      clk,
    output     vclk_cen
);

reg [1:0] cnt;
reg       vclk;

assign vclk_cen = cnt==2 && !vclk;

always @(posedge clk) begin
    if( rst ) begin
        cnt  <= 0;
        vclk <= 0;
    end else begin
        cnt <= cnt==2 ? 2'd0 : cnt+2'd1;
        if( cnt==2 ) vclk <= ~vclk;
    end
end

endmodule
