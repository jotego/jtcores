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

module jt680x_alu_sel(
    input             rst,
    input             clk,
    input      [ 7:0] op,
    input             ix_set,
    output reg [ 4:0] sel
);

`include "jt680x.vh"

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sel <= ALU_NOP;
    end else begin
        casez( op )
            // Hi 0
            8'b0000_0100: sel <= ALU_LSR16;
            8'b0000_0101: sel <= ALU_LSL16;
            8'b0000_0110: sel <= ALU_TAP;
            8'b0000_0111: sel <= ALU_TPA;
            8'b0000_1000: sel <= ALU_INX;
            8'b0000_1001: sel <= ALU_DEX;

            8'b0000_1010: sel <= ALU_CLV;
            8'b0000_1011: sel <= ALU_SEV;
            8'b0000_1100: sel <= ALU_CLC;
            8'b0000_1101: sel <= ALU_SEC;
            8'b0000_1110: sel <= ALU_CLI;
            8'b0000_1111: sel <= ALU_SEI;
            // Hi 1
            8'b0001_1001: sel <= ALU_DAA;
            // Hi 2
            8'b0010_????: sel <= ALU_ADD16; // branch
            // Hi 3
            8'b0011_1101: sel <= ALU_MUL;  // modifies carry bit
            // Hi 4-7
            8'b01??_0000: sel <= ALU_NEG;
            8'b01??_0011: sel <= ALU_COM;
            8'b01??_0100: sel <= ALU_LSR8;
            8'b01??_0110: sel <= ALU_ROR8;
            8'b01??_0111: sel <= ALU_ASR8;
            8'b01??_1000: sel <= ALU_ASL8;
            8'b01??_1001: sel <= ALU_ROL8;
            8'b01??_1010: sel <= ALU_DEC;
            8'b01??_1100: sel <= ALU_INC;
            8'b01??_1101: sel <= ALU_AND;
            8'b01??_1111: sel <= ALU_CLR;
            // Hi 6-7, not arithmetic from 6301
            8'b011?_0001: sel <= ALU_AND; // AIM
            8'b011?_0010: sel <= ALU_ORA; // OIM
            8'b011?_0101: sel <= ALU_EOR; // EIM
            8'b011?_1011: sel <= ALU_AND; // TIM
            // Hi 8~F
            8'b0001_000?, // SBA, CBA
            8'b1???_00??: sel <= ALU_SUB8; // SUBA, SUBB, CMPA, CMPB, SBCA, SBCB
            8'b1000_1100: // CPX
            8'b10??_0011: sel <= ALU_SUB16; // SUBD
            8'b0001_1011, // ABA
            8'b1010_0011, // ABX - flags kept
            8'b11??_0011: sel <= ALU_ADD16; // ADDD
            8'b1???_010?: sel <= ALU_AND;   // AND, BIT
            8'b1???_0101: sel <= ALU_AND;
            8'b1???_0110: sel <= ALU_LD8;   // LDAA, LDAB
            8'b1???_0111: sel <= ALU_ST8;
            8'b1???_1000: sel <= ALU_EOR;
            8'b1???_10?1: sel <= ALU_ADD8;
            8'b1???_1010: sel <= ALU_ORA;
            8'b11??_11?0: sel <= ALU_LD16;
            8'b11??_11?1: sel <= ALU_ST16;
            default:      sel <= ALU_NOP;
        endcase
        if( ix_set ) sel <= ALU_ADD16;
    end
end

endmodule