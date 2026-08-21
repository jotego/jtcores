/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-3-2025 */

// blends two colors by simply averaging the RGB signals
module jtgaiden_blender(
    input          clk,
    input          latch,

    input   [11:0] main, other,
    input          enable,

    output reg [11:0] blended
);

reg [11:0] mix;

function [3:0] avg(input [3:0]a,b); begin
    reg [4:0] sum;
    sum = {1'b0,a}+{1'b0,b};
    avg = sum[4:1];
end endfunction

always @* begin
    mix = {avg(main[8+:4],other[8+:4]),
           avg(main[4+:4],other[4+:4]),
           avg(main[0+:4],other[0+:4])};
end

always @(posedge clk) if(latch) blended <= enable ? mix : main;

endmodule