/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-10-2026 */

module jtnarc_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 3:0] gfx_en,
    input      [12:0] pxl,
    input             blank,
    output     [13:1] colvid_addr,
    input      [15:0] colvid_dout,
    output reg [ 4:0] red,
    output reg [ 4:0] green,
    output reg [ 4:0] blue
);

assign colvid_addr = pxl;

always @(posedge clk) begin
    if( rst ) begin
        { red, green, blue } <= 0;
    end else if( pxl_cen ) begin
        { red, green, blue } <= blank || !gfx_en[0] ? 15'd0 : colvid_dout[14:0];
    end
end

endmodule
