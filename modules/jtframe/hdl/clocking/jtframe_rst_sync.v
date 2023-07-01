/*  This file is part of JT_FRAME.
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
    Date: 6-9-2021 */

// Reference:
// https://www.intel.com/content/www/us/en/programmable/quartushelp/15.1/index.htm#verify/da/comp_file_rules_reset_synch.htm

module jtframe_rst_sync(
    input   rst,
    input   clk,
    output  rst_sync
);

reg [1:0] s;

assign rst_sync = s[1];

always @(posedge clk) begin
    s <= { s[0], rst };
end

endmodule