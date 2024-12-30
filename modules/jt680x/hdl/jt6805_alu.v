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
    Date: 4-12-2023 */
/* verilator coverage_off */
module jt6805_alu(
    input          rst,
    input          clk,
    input          cen,
    input   [ 1:0] carry_sel,
    input   [ 3:0] alu_sel,
    input          cin,
    input          hin,
    input   [12:0] op0, op1,

    output reg        ho,
    output reg [12:0] rslt,
    output     [ 2:0] rslt_cc
);

`include "6805_param.vh"

wire [3:0] bsel;
reg  c8, cx, n8, z8;

assign rslt_cc = {n8,z8,c8};
assign bsel    = {1'b0,op1[3:1]};

always @* begin
    case( carry_sel )
        CIN_CARRY: cx = cin;
        MSB_CARRY: cx = op0[7];
        default:   cx = 0;
    endcase

    rslt = op0;
    c8   = 0;
    ho   = 0;
    case( alu_sel )
        ADD_ALU: begin
            {ho,  rslt[ 3:0]} = {1'b0, op0[ 3:0]}+{1'b0, op1[ 3:0]}+{4'd0,cx};
            {c8,  rslt[ 7:4]} = {1'b0, op0[ 7:4]}+{1'b0, op1[ 7:4]}+{4'd0,ho};
            rslt[12:8] = op0[12:8]+op1[12:8]+{4'd0,c8};
        end
        SUB_ALU: {c8,rslt[7:0]} = {1'b0, op0[7:0]}-{1'b0,op1[7:0]}-{8'b0,cx};
        AND_ALU: rslt[7:0] = op0[7:0] & op1[7:0];
         OR_ALU: rslt[7:0] = op0[7:0] | op1[7:0];
        EOR_ALU: rslt[7:0] = op0[7:0] ^ op1[7:0];
        LSR_ALU: {rslt[7:0],c8} = {cx,op0[7:0]};
        LSL_ALU: {c8,rslt[7:0]} = {op0[7:0],cx};
        BSET_ALU: begin
            rslt[7:0] = op0[7:0];
            rslt[bsel]=1;
            c8=op0[bsel];
        end
        BCLR_ALU: begin
            rslt[7:0] = op0[7:0];
            rslt[bsel]=0;
            c8=op0[bsel];
        end
        default: rslt = op0;
    endcase

    z8 = rslt[7:0]==0;
    n8 = rslt[7];
end

endmodule