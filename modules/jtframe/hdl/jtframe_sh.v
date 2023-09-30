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
    Date: 27-10-2017 */

module jtframe_sh #(parameter W=5, L=24 )
(
    input                           clk,
    input                           clk_en,
    input       [W-1:0]         din,
    output      [W-1:0]         drop
);

reg [L-1:0] bits[W-1:0];

// This makes the argument L=1 valid:
localparam WM = L>1 ? L-2 : 0;

// The tool Verilator is troubled when L==1
/* verilator lint_off WIDTH */
generate
    genvar i;
    for (i=0; i < W; i=i+1) begin: bit_shifter
        always @(posedge clk) if(clk_en) begin
                bits[i] <= {bits[i][WM:0], din[i]};
            end
        assign drop[i] = bits[i][L-1];
    end
endgenerate
/* verilator lint_on WIDTH */

endmodule
