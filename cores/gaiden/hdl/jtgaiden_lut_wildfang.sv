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
    Date: 1-1-2025 */

module jtgaiden_wildfang_lut(
    input                clk,
    input          [4:0] addr,
    output reg    [15:0] jump
);

reg [15:0] jump_lut[0:16];

initial begin
    jump_lut = '{
    16'h0c0c,16'h0cac,16'h0d42,16'h0da2,16'h0eea,16'h112e,16'h1300,16'h13fa,
    16'h159a,16'h1630,16'h109a,16'h1700,16'h1750,16'h1806,16'h18d6,16'h1a44,
    16'h1b52 };
end

always @(posedge clk) begin
    jump <= jump_lut[addr];
end

endmodule    