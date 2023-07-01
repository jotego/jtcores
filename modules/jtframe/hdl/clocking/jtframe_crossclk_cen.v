/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-11-2021 */

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