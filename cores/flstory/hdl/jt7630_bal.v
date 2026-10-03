/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-12-2024 */

module jt7630_bal #( parameter
    SW=16        // signal bit width
)(
    input               clk,
    input         [3:0] bal,
    input      [SW-1:0] sin1, sin2,
    output reg [SW  :0] sout   // unsigned!
);

reg  [SW+9:0] mul1, mul2;
reg     [9:0] g1,g2;
wire [SW-1:0] sout1, sout2;

assign sout1 = mul1[SW+9-:SW];
assign sout2 = mul2[SW+9-:SW];

always @(posedge clk) begin
    sout <= {1'b0,sout1}+{1'b0,sout2};
    mul1<=g1*sin1;
    mul2<=g2*sin2;
    case(bal)
        15: {g1,g2} <= {10'd013,10'd602};
        14: {g1,g2} <= {10'd128,10'd609};
        13: {g1,g2} <= {10'd229,10'd602};
        12: {g1,g2} <= {10'd305,10'd595};
        11: {g1,g2} <= {10'd362,10'd588};
        10: {g1,g2} <= {10'd406,10'd574};
         9: {g1,g2} <= {10'd446,10'd561};
         8: {g1,g2} <= {10'd472,10'd542};
         7: {g1,g2} <= {10'd512,10'd512};
         6: {g1,g2} <= {10'd524,10'd495};
         5: {g1,g2} <= {10'd530,10'd456};
         4: {g1,g2} <= {10'd536,10'd406};
         3: {g1,g2} <= {10'd542,10'd323};
         2: {g1,g2} <= {10'd548,10'd128};
         1: {g1,g2} <= {10'd555,10'd006};
         0: {g1,g2} <= {10'd555,10'd001};
    endcase
end

endmodule
