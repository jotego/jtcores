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
    Date: 24-8-2021 */

module jt007232_gain(
    input                    clk,
    input                    swap_gains,   // makes ^ with REG12A below
    input             [ 7:0] reg12,
    input      signed [ 6:0] rawa, rawb,
    output reg signed [10:0] snda, sndb
);

parameter REG12A=1;

wire signed [ 4:0] cha_gain = {1'b0,  (REG12A[0]^swap_gains) ? reg12[7:4] : reg12[3:0] };
wire signed [ 4:0] chb_gain = {1'b0, ~(REG12A[0]^swap_gains) ? reg12[7:4] : reg12[3:0] };
reg  signed [11:0] mula, mulb;

always @(posedge clk) begin
    snda <= rawa * cha_gain;
    sndb <= rawb * chb_gain;
end

endmodule