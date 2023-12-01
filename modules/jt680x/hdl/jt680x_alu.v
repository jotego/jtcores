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
    input          cin,
    input   [15:0] op0, op1,


    output reg     ho,
    output  [15:0] rslt,
    output   [3:0] rslt_cc
);

`include "jt680x.vh"

reg  c8, c16, cx,
     v8, v16;
wire n8, n16,
     z8, z16;

reg [7:0] daa;
reg       valid_hi, valid_lo;

assign rslt_cc  = alu16 ? { n16,z16,v16,c16} : { n8, z8, v8, c8 };

assign z8  = rslt[7:0]==0;
       z16 = rslt[7:0]==0;
       n8  = rslt[7];
       n16 = rslt[15];

always @* begin
    case( carry_ctrl )
        CIN_CARRY:  cx = cin;
        OP0L_CARRY: cx = op0[0];
        OP0M_CARRY: cx = op0[7];
        HI_CARRY:   cx = 1;
        default:    cx = 0;
    endcase

    case( alu_ctrl )
        ADD_ALU: begin
            {ho,  rslt[ 3:0]} = {1'b0, op0[ 3:0]}+{1'b0, op1[ 3:0]}+{4'd0,cx};
            {c8,  rslt[ 7:4]} = {1'b0, op0[ 7:4]}+{1'b0, op1[ 7:4]}+{4'd0,ho};
            {c16, rslt[15:8]} = {1'b0, op0[15:8]}+{1'b0, op1[15:8]}+{8'd0,c8};
            v8  = ^{op0[ 7],op1[ 7],~rslt[ 7]};
            v16 = ^{op0[15],op1[15],~rslt[15]};
        end
        DAA_ALU: begin
            rslt = {op0[15:8],op[7:0]+daa}; // output daa so the ucode can use it as an operand
            v8  = ^{op0[ 7],op1[ 7],~rslt[ 7]}; // manual defines it as undefined, so leaving it as ADD_ALU makes sense
            c8   = c || rslt[7:4]>9; // 6801 reference manual, page 103
        end
        AND_ALU: rslt = op0 & op1;
         OR_ALU: rslt = op0 | op1;
        EOR_ALU: rslt = op0 ^ op1;
        MUL_ALU: rslt = op0[7:0]*op1[7:0];  // Use a hardware multiplier
        ASR_ALU, LSR_ALU: begin
            rslt[15:8] = {alu_ctrl==ASR_ALU ? op0[7] : 1'b0, op0[7:1]};
            rslt[ 7:0] = {cx,op1[7:1]};
            c8  = op1[0];
            c16 = op1[0];
            v8  = op1[7] ^ op1[0];
            v16 = op0[7] ^ op1[0];
        end
        LSL_ALU: begin
            rslt[15:8] = {op0[6:0],cx};
            rslt[ 7:0] = {op1[6:0],1'b0};
            c8  = op0[7];
            c16 = op0[7];
            v8  = op0[7] ^ op0[6];
            v16 = op0[7] ^ op0[6];
        end
        ROL_ALU: begin
            {c8,rslt[7:0]} = {op0,cin};
            v8  = op0[7] ^ op0[6];
        end
        ROR_ALU: begin
            {rslt[7:0],c8} = {cin,op0};
            v8  = op0[7] ^ cin;
        end
        SUB_ALU: begin
            {c8,  rslt[ 7:0]} = {1'b0, op0[ 7:0]}-{1'b0,op1[ 7:0]}-{8'b0,cx};
            {c16, rslt[15:8]} = {1'b0, op0[15:8]}-{1'b0,op1[15:8]}-{8'b0,c8};
            v8  = &{op0[ 7],~op1[ 7],~rslt[ 7]}|&{~op0[ 7],op1[ 7],rslt[ 7]};
            v16 = &{op0[15],~op1[15],~rslt[15]}|&{~op0[15],op1[15],rslt[15]};
        end
        default: rslt = op0;
    endcase
end

always @* begin
    valid_lo = (op0[3:0] <= 9);
    valid_hi = (op0[7:4] <= 9);

    daa = c ? ( h?8'h66 :  valid_lo ? 8'h60 : 8'h66) :
          h             ? (valid_hi ? 8'h06 : 8'h66) :
          valid_lo      ? (valid_hi ? 8'h00 : 8'h60) :
          op0[7:4] <= 8 ? 8'h06 : 8'h66;
end

endmodule