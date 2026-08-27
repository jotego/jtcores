/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-3-2025 */

// blends two colors by adding the RGB signals, with saturation
module jtgaiden_blender(
    input          clk,
    input          latch,

    input   [11:0] main, other,
    input          enable,

    output reg [11:0] blended
);

reg [11:0] mix;

function [3:0] sat(input [3:0]a,b); begin
    reg [4:0] sum;
    sum = {1'b0,a}+{1'b0,b};
    sat = sum[4] ? 4'hf : sum[3:0];
end endfunction

always @* begin
    mix = {sat(main[8+:4],other[8+:4]),
           sat(main[4+:4],other[4+:4]),
           sat(main[0+:4],other[0+:4])};
end

always @(posedge clk) if(latch) blended <= enable ? mix : main;

endmodule