/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-6-2025 */

module jtlgtnfght_com(
    input                clk,
    input                cs,
    input          [1:0] dsn,
    input                rnw,
    input         [15:0] din,
    output reg    [ 2:0] cl,        // brightness
    output reg           sndon, vromrd
);

always @(posedge clk) begin
    if(!dsn[0] && !rnw && cs) begin
        {cl,vromrd,sndon} <= din[6:2];
    end
end

endmodule
