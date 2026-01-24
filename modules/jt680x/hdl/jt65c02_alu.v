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
    Date: 28-11-2025 */
/* verilator coverage_off */
module jt65c02_alu(
    input          rst,
    input          clk,
    input          cen,
    input   [ 1:0] carry_sel,
    input   [ 3:0] alu_sel,
    input          cin, calt,
    input   [ 7:0] op0, op1, ir,

    output reg [ 7:0] rslt,
    output     [ 3:0] rslt_cc
);

`include "65c02_param.vh"

wire [2:0] bsel;
wire [7:0] anded;
reg        v8, c8, cx, n8, z8, cinv;
wire       tsb_trb;
reg  [7:0] daa, das;
reg  [3:0] addlow;
reg        valid_hi, valid_lo;
reg        h;

assign rslt_cc = {n8,v8,z8,c8};
assign bsel    = ir[6:4];
assign anded   = op0 & op1;
assign tsb_trb = alu_sel==TSB_ALU || alu_sel==TRB_ALU;

always @* begin
    {h, addlow} = {1'b0, op0[3:0]}+{1'b0, op1[3:0]}+{4'd0,cx};
end

always @* begin
    case( carry_sel )
        CIN_CARRY: cx = cin;
        // MSB_CARRY: cx = op0[7];
        ALT_CARRY: cx = calt;
        ONE_CARRY: cx = 1;
        default:   cx = 0;
    endcase
end

always @* begin
    rslt = op0;
    c8   = 0;
    v8   = 0;
    cinv = 0;
    case( alu_sel )
        ADD_ALU: begin
            rslt[3:0] = addlow;
            {c8, rslt[7:4]} = {1'b0, op0[7:4]}+{1'b0, op1[7:4]}+{4'd0,h};
            v8 = &{op0[7],op1[7],~rslt[7]}|&{~op0[7],~op1[7],rslt[7]};
        end
        SUB_ALU: begin
            {cinv,rslt} = {1'b0,op0}-{1'b0,op1}-{8'b0,~cx};
            c8 = ~cinv;
            v8 = &{op0[7],~op1[7],~rslt[7]}|&{~op0[7],op1[7],rslt[7]};
        end
        DAA_ALU: rslt = op0[7:0]+daa;
        DAS_ALU: rslt = op0[7:0]-das;
        AND_ALU: rslt = anded;
        TRB_ALU: rslt =~op0 & op1; // op0 must be A register
OR_ALU, TSB_ALU: rslt = op0 | op1;
        EOR_ALU: rslt = op0 ^ op1;
        LSR_ALU: {rslt,c8} = {cx,op0};
        LSL_ALU: {c8,rslt} = {op0,cx};
        BINV_ALU: c8=~op0[bsel];
        BSET_ALU: begin
            rslt = op0;
            rslt[bsel]=1;
            c8=op0[bsel];
        end
        BCLR_ALU: begin
            rslt = op0;
            rslt[bsel]=0;
            c8=op0[bsel];
        end
        default: rslt = op0;
    endcase

    z8 = tsb_trb ? anded==0 : rslt==0;
    n8 = rslt[7];
end

always @* begin
    valid_lo = (op0[3:0] <= 9);
    valid_hi = (op0[7:4] <= 9);

    daa = cin?(h?8'h66:  valid_lo ? 8'h60 : 8'h66) :
          h           ? (valid_hi ? 8'h06 : 8'h66) :
          valid_lo      ? (valid_hi ? 8'h00 : 8'h60) :
          op0[7:4] <= 8 ? 8'h06 : 8'h66;
    // das: only the carry sign is different
    das =~cin?(h?8'h66:  valid_lo ? 8'h60 : 8'h66) :
          h           ? (valid_hi ? 8'h06 : 8'h66) :
          valid_lo      ? (valid_hi ? 8'h00 : 8'h60) :
          op0[7:4] <= 8 ? 8'h06 : 8'h66;
end

endmodule