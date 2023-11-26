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

localparam SBIT = 7,
           XBIT = 6,
           HBIT = 5,
           IBIT = 4,
           NBIT = 3,
           ZBIT = 2,
           VBIT = 1,
           CBIT = 0;

localparam [4:0]
    ALU_ADC     = 0,
    ALU_ADD16   = 0,
    ALU_ADD8    = 0,
    ALU_AND     = 0,
    ALU_ASL8    = 0,
    ALU_ASR8    = 0,
    ALU_CLC     = 0,
    ALU_CLI     = 0,
    ALU_CLR     = 0,
    ALU_CLV     = 0,
    ALU_COM     = 0,
    ALU_DAA     = 0,
    ALU_DEC     = 0,
    ALU_DEX     = 0,
    ALU_EOR     = 0,
    ALU_INC     = 0,
    ALU_INX     = 0,
    ALU_LD16    = 0,
    ALU_LD8     = 0,
    ALU_LSL16   = 0,
    ALU_LSR16   = 0,
    ALU_LSR8    = 0,
    ALU_MUL     = 0,
    ALU_NEG     = 0,
    ALU_ORA     = 0,
    ALU_ROL8    = 0,
    ALU_ROR8    = 0,
    ALU_SBC     = 0,
    ALU_SEC     = 0,
    ALU_SEI     = 0,
    ALU_SEV     = 0,
    ALU_ST16    = 0,
    ALU_ST8     = 0,
    ALU_SUB16   = 0,
    ALU_SUB8    = 0,
    ALU_TAP     = 0,
    ALU_TPA     = 0,
    ALU_TST     = 0;
