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
    Date: 15-4-2021 */

// Divides a clock enable signal frequency by two

module jtframe_cendiv(
    input      clk,
    input      cen_in,
    output reg cen_div, // Divided but not alligned with the original
    output     cen_da   // Divided and alligned
);

reg d = 0;

assign cen_da = cen_in & d;

always @(posedge clk) begin
    if( cen_in ) d<=~d;
    cen_div <= cen_da;
end


endmodule