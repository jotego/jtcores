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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// shared codes between jt960 modules

// operation classes (decoder output)
localparam [4:0]
    OC_BAD    = 5'd0,  OC_ALU    = 5'd1,  OC_MOVM   = 5'd2,  OC_MD     = 5'd3,
    OC_B      = 5'd4,  OC_BCC    = 5'd5,  OC_CALL   = 5'd6,  OC_RET    = 5'd7,
    OC_BAL    = 5'd8,  OC_FAULT  = 5'd9,  OC_TEST   = 5'd10, OC_COBR   = 5'd11,
    OC_LD     = 5'd12, OC_ST     = 5'd13, OC_LDA    = 5'd14, OC_BX     = 5'd15,
    OC_BALX   = 5'd16, OC_CALLX  = 5'd17, OC_CALLS  = 5'd18, OC_FLUSH  = 5'd19,
    OC_MODPC  = 5'd20, OC_SYNMOV = 5'd21, OC_SYNMOVQ= 5'd22, OC_ATADD  = 5'd23,
    OC_ATMOD  = 5'd24, OC_NOP    = 5'd25;

// multiply/divide unit operations
localparam [2:0]
    MD_MUL = 3'd0, MD_EMUL = 3'd1, MD_DIVO = 3'd2, MD_REMO = 3'd3,
    MD_DIVI= 3'd4, MD_REMI = 3'd5, MD_MODI = 3'd6, MD_EDIV = 3'd7;
