/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtrungun_timer_rst(
    input  clk, rst,
    output timer_rst
);

reg rst_l = 0;

assign timer_rst = rst & ~rst_l;

always @(posedge clk) begin
    rst_l <= rst;
end

endmodule
