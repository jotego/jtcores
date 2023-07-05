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
    Date: 31-10-2021 */

// SEGA 315-5248 model based on MAME driver

module jts16b_mul(
    input              rst,
    input              clk,

    input      [23:1]  A,
    input      [ 1:0]  dsn,
    input              rnw,
    input              cs,
    input      [15:0]  din,

    output reg [15:0]  dout
);

reg signed [15:0] factors[0:1];
reg signed [31:0] mul;

always @(posedge clk or posedge rst) begin 
    if(rst) begin
        factors[0] <= 0;
        factors[1] <= 0;
    end else if(cs) begin
        mul <= factors[0] * factors[1];
        if( !rnw ) begin
            if( !dsn[0] ) factors[A[1]][ 7:0] <=  din[ 7:0];
            if( !dsn[1] ) factors[A[1]][15:8] <=  din[15:8];
        end
        case(A[2:1])
            0: dout <= factors[0];
            1: dout <= factors[1];
            2: dout <= mul[31:16];
            3: dout <= mul[15: 0];
        endcase
    end
end

endmodule