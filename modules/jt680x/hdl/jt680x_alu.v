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
    Date: 22-11-2023 */

// 6800 has an 8-bit ALU
// 6801 might have used an 8-bit ALU
// 6301 seems to have a 16-bit ALU
module jt680x_alu(
    input          rst,
    input          clk,
    input          cen,
    input   [ 4:0] sel,
    input          op0_inv,
    input   [15:0] op0, op1,
    output  [15:0] rslt,

    input          cin,
    output reg     ho,
    output   [3:0] cc8,
    output   [3:0] cc16
);

`include "jt680x.vh"

reg  c8, c16, cx,
     v8, v16;
wire n8, n16,
     z8, z16;

assign cc8  = { n8, z8, v8, c8 };
assign cc16 = { n16,z16,v16,c16};

wire [15:0] op0_mx = {op0[15:8], op0_inv ? ~op0mx[7:0] : op0mx[7:0]};

assign z8  = rslt[7:0]==0;
       z16 = rslt[7:0]==0;
       n8  = rslt[7];
       n16 = rslt[15];

always @* begin
    case( carry_ctrl )
        CIN_CARRY:  cx = cin;
        OP0L_CARRY: cx = op0mx[0];
        OP0M_CARRY: cx = op0mx[7];
        HI_CARRY:   cx = 1;
        default:    cx = 0;
    endcase
    case( alu_ctrl )
        ADD_ALU: begin
            {ho,  rslt[ 3:0]} = {1'b0, op0mx[ 3:0]}+{1'b0, op1[ 3:0]}+{4'd0,cx};
            {c8,  rslt[ 7:4]} = {1'b0, op0mx[ 7:4]}+{1'b0, op1[ 7:4]}+{4'd0,ho};
            {c16, rslt[15:8]} = {1'b0, op0mx[15:8]}+{1'b0, op1[15:8]}+{8'd0,c8};
            v8  = ^{op0mx[ 7],op1[ 7],~rslt[ 7]};
            v16 = ^{op0mx[15],op1[15],~rslt[15]};
        end
        AND_ALU: rslt = op0mx & op1;
         OR_ALU: rslt = op0mx | op1;
        EOR_ALU: rslt = op0mx ^ op1;
        MUL_ALU: rslt = op0mx[7:0]*op1[7:0];  // Use a hardware multiplier
        ASR_ALU, LSR_ALU: begin
            rslt[15:8] = {alu_ctrl==ASR_ALU ? op0mx[7] : 1'b0, op0mx[7:1]};
            rslt[ 7:0] = {cx,op1[7:1]};
            c8  = op1[0];
            c16 = op1[0];
            v8  = op1[7] ^ op1[0];
            v16 = op0mx[7] ^ op1[0];
        end
        LSL_ALU: begin
            rslt[15:8] = {op0mx[6:0],cx};
            rslt[ 7:0] = {op1[6:0],1'b0};
            c8  = op0mx[7];
            c16 = op0mx[7];
            v8  = op0mx[7] ^ op0mx[6];
            v16 = op0mx[7] ^ op0mx[6];
        end
        ROL_ALU: begin
            {c8,rslt[7:0]} = {op0mx,cin};
            v8  = op0mx[7] ^ op0mx[6];
        end
        ROR_ALU: begin
            {rslt[7:0],c8} = {cin,op0mx};
            v8  = op0mx[7] ^ cin;
        end
        SUB_ALU: begin
            {c8,  rslt[ 7:0]} = {1'b0, op0mx[ 7:0]}-{1'b0,op1[ 7:0]}-{8'b0,cx};
            {c16, rslt[15:8]} = {1'b0, op0mx[15:8]}-{1'b0,op1[15:8]}-{8'b0,c8};
            v8  = &{op0mx[ 7],~op1[ 7],~rslt[ 7]}|&{~op0mx[ 7],op1[ 7],rslt[ 7]};
            v16 = &{op0mx[15],~op1[15],~rslt[15]}|&{~op0mx[15],op1[15],rslt[15]};
        end
        default: rslt = op0mx;
    endcase

end

endmodule