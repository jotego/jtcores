/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-8-2025 */

module jtrungun_dim(
    input             rst,   clk, pxl_cen,
                      lhbl, lvbl,

    output     [11:1] pal_addr,
    input      [15:0] pal_dout,

    input      [15:0] pxl,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue
);

reg  [23:0] bgr;
wire [ 7:0] r8, b8, g8;
wire        shad;

assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;
assign pal_addr = pxl[11:1];

function [7:0] conv58(input [4:0] cin );
begin
    conv58 = {cin, cin[4-:3]};
end
endfunction

assign { b8, g8, r8 } = {conv58(pal_dout[10+:5]),conv58(pal_dout[5+:5]),conv58(pal_dout[0+:5])};
assign shad = pxl[0];

always @(posedge clk) begin
    if( rst ) begin
        bgr   <= 0;
    end else begin
        if( pxl_cen ) bgr <= ~shad ? { b8, g8, r8 } : { b8>>1, g8>>1, r8>>1 };
    end
end

endmodule