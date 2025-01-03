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

// makes consequitive requests and 
// converts 16 bit data to 32 bits
module jtframe_bram_burst(
    input             clk,

    output reg        sel,
    input      [15:0] din16,
    output reg [31:0] dout32
);

reg [15:0] hihalf;

always @(posedge clk) begin
    sel <= ~sel;
    if(!sel)
        hihalf <= din16;
    else
        dout32 <= {hihalf,din16};
end

endmodule    