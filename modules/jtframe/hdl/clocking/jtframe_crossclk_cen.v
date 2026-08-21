/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-11-2021 */

// Converts a clock enable (cen) signal in the fast domain
// to a cen in the slow domain
// The effective cen frequency cannot be greater than 0.5*clk_out

module jtframe_crossclk_cen(
    input       clk_in,     // fast clock
    input       cen_in,
    input       clk_out,    // slow clock
    output reg  cen_out
);

reg flag;

initial begin
    flag    = 0;
    cen_out = 0;
end

always @(posedge clk_in) begin
    if( cen_in  ) flag <= 1;
    if( cen_out ) flag <= 0;
end

reg flag_l;

always @(posedge clk_out) begin
    flag_l  <= flag;
    cen_out <= flag && !flag_l;
end

endmodule