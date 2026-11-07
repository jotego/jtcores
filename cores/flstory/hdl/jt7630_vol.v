/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-12-2024 */

// two outputs are calculated with a single LUT/multipler
module jt7630_vol #( parameter
    SW=16        // signal bit width
)(
    input           clk,
    input     [3:0] vol0,  vol1,
    input  [SW-1:0] sin0,  sin1,
    output [SW-1:0] sout0, sout1  // unsigned!
);

reg sel;
reg [SW+9:0] mul0, mul1;
reg [9:0] gain;

assign sout0 = mul0[SW+9-:SW];
assign sout1 = mul1[SW+9-:SW];

always @(posedge clk) begin
    sel <= ~sel;
    if(sel) mul1<=gain*sin1; else mul0<=gain*sin0;
    case(sel?vol0:vol1)
        15: gain <= 10'd1023;
        14: gain <= 10'd901; 
        13: gain <= 10'd776;
        12: gain <= 10'd645;
        11: gain <= 10'd525;
        10: gain <= 10'd417;
         9: gain <= 10'd324;
         8: gain <= 10'd229;
         7: gain <= 10'd162;
         6: gain <= 10'd102;
         5: gain <= 10'd65;
         4: gain <= 10'd36;
         3: gain <= 10'd18;
         2: gain <= 10'd9;
         1: gain <= 10'd3;
         0: gain <= 10'd1;
    endcase
end

endmodule    