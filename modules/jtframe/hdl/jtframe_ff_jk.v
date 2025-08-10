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
    Date: 20-7-2025 */

module jtframe_ff_jk #(parameter RST=0) (
    input rst, clk, cen,
          j, k,
    output reg q,q_n
);

always @(posedge clk) begin
    if(rst) begin
        q   <= RST[0];
        q_n <=~RST[0];
    end else if(cen) begin
        case({j,k})
            2'b01: {q,q_n}<=2'b01;
            2'b10: {q,q_n}<=2'b10;
            2'b11: {q,q_n}<=~{q,q_n};
            default:;
        endcase
    end
end

endmodule
