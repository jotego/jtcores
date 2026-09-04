/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtframe_okdly #(parameter W=1)(
    input           rst,
    input           clk,
    input  [W-1:0]  cs,
    input  [W-1:0]  ok,
    output reg      ok_dly
);

always @(posedge clk) begin
    if( rst ) begin
        ok_dly <= 0;
    end else begin
        ok_dly <= |(cs & ok);
    end
end

endmodule
