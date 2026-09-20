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

// instruction class decoder. Formats:
// CTRL 08-1f: [31:24] op, [23:0] displacement (bits 1:0 included, as in MAME)
// COBR 20-3e: [31:24] op, [23:19] src1, [18:14] src2, [13] m1, [12:0] disp
// REG  58-79: [31:24] op, [23:19] src/dst, [18:14] src2, [13] m3, [12] m2,
//             [11] m1, [10:7] op low, [4:0] src1
// MEMA xy (bit12=0): [23:19] src/dst, [18:14] abase, [13] mode, [11:0] offset
// MEMB xy (bit12=1): [13:10] mode, [9:7] scale, [4:0] index, +1 disp word

module jt960_dec(
    input      [31:0] ir,
    output reg [ 4:0] opclass,
    output reg        need_disp,
    output reg [ 1:0] msz,      // 0 byte, 1 short, 2 word
    output reg [ 2:0] mcnt,     // word count for multi-word ld/st/mov
    output reg        msig,     // sign-extend load
    output reg [ 4:0] mreg,     // masked src/dst base register
    output reg [ 2:0] mdop,
    output reg        mdpair
);

`include "i960/jt960.vh"

wire [7:0] mj = ir[31:24];
wire [3:0] sb = ir[10: 7];

always @* begin
    opclass   = OC_BAD;
    need_disp = 0;
    msz       = 2'd2;
    mcnt      = 3'd1;
    msig      = 0;
    mreg      = ir[23:19];
    mdop      = MD_MUL;
    mdpair    = 0;
    case( mj )
    8'h08: opclass = OC_B;
    8'h09: opclass = OC_CALL;
    8'h0a: opclass = OC_RET;
    8'h0b: opclass = OC_BAL;
    8'h10,8'h11,8'h12,8'h13,8'h14,8'h15,8'h16,8'h17: opclass = OC_BCC;
    8'h18,8'h19,8'h1a,8'h1b,8'h1c,8'h1d,8'h1e,8'h1f: opclass = OC_FAULT;
    8'h20,8'h21,8'h22,8'h23,8'h24,8'h25,8'h26,8'h27: opclass = OC_TEST;
    8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
    8'h39,8'h3a,8'h3b,8'h3c,8'h3d,8'h3e:             opclass = OC_COBR;
    8'h58: if( sb!=4'h5 ) opclass = OC_ALU;
    8'h59: case( sb )
        4'h0,4'h1,4'h2,4'h3,4'h8,4'ha,4'hb,4'hc,4'hd,4'he: opclass = OC_ALU;
        default: ;
        endcase
    8'h5a: case( sb )
        4'h0,4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7,4'hc,4'he: opclass = OC_ALU;
        default: ;
        endcase
    8'h5b: if( sb==4'h0 || sb==4'h2 ) opclass = OC_ALU;   // addc, subc
    8'h5c: if( sb==4'hc ) opclass = OC_MOVM;              // mov
    8'h5d: if( sb==4'hc ) begin                           // movl
        opclass = OC_MOVM; mcnt = 3'd2; mreg = ir[23:19] & 5'h1e;
    end
    8'h5e: if( sb==4'hc ) begin                           // movt
        opclass = OC_MOVM; mcnt = 3'd3; mreg = ir[23:19] & 5'h1c;
    end
    8'h5f: if( sb==4'hc ) begin                           // movq
        opclass = OC_MOVM; mcnt = 3'd4; mreg = ir[23:19] & 5'h1c;
    end
    8'h60: case( sb )
        4'h0: opclass = OC_SYNMOV;
        4'h2: opclass = OC_SYNMOVQ;
        default: ;
        endcase
    8'h61: case( sb )
        4'h0: opclass = OC_ATMOD;
        4'h2: opclass = OC_ATADD;
        default: ;
        endcase
    8'h64: case( sb )
        4'h0,4'h1,4'h4,4'h5: opclass = OC_ALU;  // spanbit, scanbit, dmovt, modac
        default: ;
        endcase
    8'h65: case( sb )
        4'h0,4'h1: opclass = OC_ALU;            // modify, extract
        4'h5:      opclass = OC_MODPC;
        default: ;
        endcase
    8'h66: case( sb )
        4'h0: opclass = OC_CALLS;
        4'hd: opclass = OC_FLUSH;
        4'hf: opclass = OC_NOP;                 // syncf
        default: ;
        endcase
    8'h67: case( sb )
        4'h0: begin opclass=OC_MD; mdop=MD_EMUL; mdpair=1; end
        4'h1: begin opclass=OC_MD; mdop=MD_EDIV; mdpair=1; end
        default: ; // cvtir/cvtilr/scaler(l): KB floating point, not on the KA
        endcase
    8'h70: case( sb )
        4'h1: begin opclass=OC_MD; mdop=MD_MUL;  end
        4'h8: begin opclass=OC_MD; mdop=MD_REMO; end
        4'hb: begin opclass=OC_MD; mdop=MD_DIVO; end
        default: ;
        endcase
    8'h74: case( sb )
        4'h1: begin opclass=OC_MD; mdop=MD_MUL;  end
        4'h8: begin opclass=OC_MD; mdop=MD_REMI; end
        4'h9: begin opclass=OC_MD; mdop=MD_MODI; end
        4'hb: begin opclass=OC_MD; mdop=MD_DIVI; end
        default: ;
        endcase
    // MEM format
    8'h80: begin opclass=OC_LD; msz=2'd0; end            // ldob
    8'h82: begin opclass=OC_ST; msz=2'd0; end            // stob
    8'h84: opclass = OC_BX;
    8'h85: opclass = OC_BALX;
    8'h86: opclass = OC_CALLX;
    8'h88: begin opclass=OC_LD; msz=2'd1; end            // ldos
    8'h8a: begin opclass=OC_ST; msz=2'd1; end            // stos
    8'h8c: opclass = OC_LDA;
    8'h90: opclass = OC_LD;                              // ld
    8'h92: opclass = OC_ST;                              // st
    8'h98: begin opclass=OC_LD; mcnt=3'd2; mreg=ir[23:19]&5'h1e; end // ldl
    8'h9a: begin opclass=OC_ST; mcnt=3'd2; mreg=ir[23:19]&5'h1e; end // stl
    8'ha0: begin opclass=OC_LD; mcnt=3'd3; mreg=ir[23:19]&5'h1c; end // ldt
    8'ha2: begin opclass=OC_ST; mcnt=3'd3; mreg=ir[23:19]&5'h1c; end // stt
    8'hb0: begin opclass=OC_LD; mcnt=3'd4; mreg=ir[23:19]&5'h1c; end // ldq
    8'hb2: begin opclass=OC_ST; mcnt=3'd4; mreg=ir[23:19]&5'h1c; end // stq
    8'hc0: begin opclass=OC_LD; msz=2'd0; msig=1; end    // ldib
    8'hc2: begin opclass=OC_ST; msz=2'd0; end            // stib
    8'hc8: begin opclass=OC_LD; msz=2'd1; msig=1; end    // ldis
    8'hca: begin opclass=OC_ST; msz=2'd1; end            // stis
    default: ; // 68/69/6c/6d/6e/78/79 KB floating point -> OC_BAD
    endcase
    // MEMB needs an extra displacement word, some modes are unsupported
    if( mj[7] && opclass!=OC_BAD && ir[12] ) begin
        case( ir[13:10] )
        4'h5,4'hc,4'hd,4'he,4'hf: need_disp = 1;
        4'h4,4'h7: ;
        default: opclass = OC_BAD;
        endcase
    end
end

endmodule
