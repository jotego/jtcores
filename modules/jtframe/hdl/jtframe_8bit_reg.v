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
    Date: 8-7-2025 */

module jtframe_8bit_reg(
    // do not change port order
    // as this module is intended for direct instantiation
    input             rst,
    input             clk,
    input             wr_n,
    input      [ 7:0] din,
    input             cs,
    output reg [ 7:0] dout
);

always @(posedge clk) begin
    if(rst) begin
        dout <= 0;
    end else begin
        if( cs && !wr_n ) begin
            dout[ 7:0] <= din[ 7:0];
        end
    end
end

endmodule
