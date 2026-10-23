/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

`timescale 1ns/1ps

module jt7474(
    input      d,
    input      pr_b,
    input      cl_b,
    input      clk,
    output     q,
    output     q_b
);
    reg qq;

    initial qq = 1'b0;

    assign #25 q   =  qq;
    assign #25 q_b = ~qq;

    always @( posedge clk or negedge cl_b or negedge pr_b )
        if( !pr_b ) qq <= 1'b1;
        else if( !cl_b ) qq <= 1'b0;
        else qq <= d;
endmodule
