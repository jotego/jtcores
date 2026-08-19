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

    Author: meathax
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_field_ram
(
	input clk,
	input [15:0] rd_addr,
	output reg [8:0] rd_data,
	input [15:0] wr_addr,
	input [8:0] wr_data,
	input wr_en
);
reg [8:0] mem [0:65535];
always @(posedge clk) begin
	rd_data <= mem[rd_addr];
	if (wr_en) mem[wr_addr] <= wr_data;
end
endmodule
