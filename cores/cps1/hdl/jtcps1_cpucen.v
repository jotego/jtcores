/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-3-2020 */

module jtcps1_cpucen(
    input       clk,
    input       cen12,
    input       cpu_speed,
    output reg  cpu_cen,
    output reg  cpu_cenb
);


wire nc0, cen10;

// Fractional cen cannot provide an uniformly spaced cenb
jtframe_frac_cen #(.W(2))u_cen10(
    .clk        ( clk           ),
    .n          ( 10'd5         ),
    .m          ( 10'd24        ),
    .cen        ( {nc0, cen10  }),
    .cenb       (               ) // 180 shifted
);

reg cenx;

always @(posedge clk) begin
    cpu_cen  <= cpu_speed ? cen12 : cen10;
    cenx     <= cpu_cen;
    cpu_cenb <= cenx;
end

endmodule