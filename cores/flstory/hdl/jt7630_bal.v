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
    Date: 8-12-2024 */

module jt7630_bal #( parameter
    SW=16        // signal bit width
)(
    input               clk,
    input         [3:0] bal,
    input      [SW-1:0] sin1, sin2,
    output reg [SW-1:0] sout   // unsigned!
);

reg  [SW+9:0] mul1, mul2;
reg     [9:0] g1,g2;
wire [SW-1:0] sout1, sout2;

assign sout1 = mul1[SW+9-:SW];
assign sout2 = mul2[SW+9-:SW];

always @(posedge clk) begin
    sout <= sout1+sout2;
    mul1<=g1*sin1;
    mul2<=g2*sin2;
    case(bal)
        15: {g1,g2} <= {10'd513,10'd091};
        14: {g1,g2} <= {10'd457,10'd102};
        13: {g1,g2} <= {10'd407,10'd115};
        12: {g1,g2} <= {10'd363,10'd129};
        11: {g1,g2} <= {10'd324,10'd145};
        10: {g1,g2} <= {10'd288,10'd162};
         9: {g1,g2} <= {10'd257,10'd182};
         8: {g1,g2} <= {10'd229,10'd204}; // forced to have 8 as mid point
         7: {g1,g2} <= {10'd204,10'd229};
         6: {g1,g2} <= {10'd182,10'd257};
         5: {g1,g2} <= {10'd162,10'd288};
         4: {g1,g2} <= {10'd145,10'd324};
         3: {g1,g2} <= {10'd129,10'd363};
         2: {g1,g2} <= {10'd115,10'd407};
         1: {g1,g2} <= {10'd102,10'd457};
         0: {g1,g2} <= {10'd091,10'd513};
        // 15: {g1,g2} <= {10'd363,10'd001};
        // 14: {g1,g2} <= {10'd324,10'd004};
        // 13: {g1,g2} <= {10'd288,10'd013};
        // 12: {g1,g2} <= {10'd257,10'd026};
        // 11: {g1,g2} <= {10'd229,10'd046};
        // 10: {g1,g2} <= {10'd204,10'd072};
        //  9: {g1,g2} <= {10'd182,10'd102};
        //  8: {g1,g2} <= {10'd153,10'd129}; // forced to have 8 as mid point
        //  7: {g1,g2} <= {10'd129,10'd153};
        //  6: {g1,g2} <= {10'd102,10'd182};
        //  5: {g1,g2} <= {10'd072,10'd204};
        //  4: {g1,g2} <= {10'd046,10'd229};
        //  3: {g1,g2} <= {10'd026,10'd257};
        //  2: {g1,g2} <= {10'd013,10'd288};
        //  1: {g1,g2} <= {10'd004,10'd324};
        //  0: {g1,g2} <= {10'd001,10'd363};
    endcase
end

endmodule    