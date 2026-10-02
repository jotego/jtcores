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
    Date: 19-9-2026
*/

// Mitsubishi M37702 (7700 series, 65C816 derived) execution engine
// behavior follows MAME m37710.cpp/m37710op.h opcode tables
// memory goes through a byte/word request port served by jt37702 (bus unit)
// see README.md for ISA coverage and deviations

module jt37702_cpu(
    input             rst,
    input             clk,
    input             cen,
    // bus unit handshake. breq level, transaction ends on cen & back
    output reg        breq,
    output reg [23:0] baddr,
    output reg        bw16,     // 0 byte, 1 word (bus unit splits misaligned)
    output reg        bwr,
    output reg [15:0] bdout,
    input      [15:0] bdin,
    input             back,
    // interrupts, resolved by the peripheral block
    input             irq_rq,
    input      [ 2:0] irq_lvl,
    input      [ 4:0] irq_ix,   // maskable index, vector = FFCE+2*ix
    output reg        irq_ack,
    output reg [ 4:0] irq_ackix,
    output reg        stp       // STP executed, only reset recovers
);

// processor state
reg  [15:0] a, b, x, y, s, dpr, pc;
reg  [ 7:0] pg, dt;
reg         fn, fv, fm, fx, fd, fi, fz, fc;
reg  [ 2:0] ipl;

// decoded instruction
reg  [ 7:0] ir;
reg  [ 1:0] pfx;      // 0 none, 1 = 42 (B acc), 2 = 89 (mul/div)
reg  [ 4:0] mode;
reg  [ 5:0] cls;
reg  [ 2:0] sub;
reg  [ 1:0] rgt;      // 0 A/B, 1 X, 2 Y
reg         useb, wide;

// working registers
reg  [23:0] ea, tmp;
reg  [15:0] opnd, imm;
reg  [ 7:0] ptrlo, mvsrc, mvdst;
reg  [23:0] sdat;     // pulled data (up to 3 bytes)
reg  [15:0] stk_dat;
reg  [ 1:0] stk_cnt, stk_ix;
reg  [ 5:0] st, ret_st;
reg  [ 3:0] pbit;     // PSH/PUL bit scan
reg  [15:0] vec;
reg         int_msk;  // interrupt entry updates ipl (hardware IRQ)
reg  [ 2:0] int_lvl;
// divider
reg  [31:0] dvd, quo;
reg  [16:0] rem;
reg  [15:0] dvs;
reg  [ 5:0] dcnt;

// addressing modes
localparam [4:0] M_IMP=0, M_IMM=1, M_D=2, M_DX=3, M_DY=4, M_A=5, M_AX=6,
    M_AY=7, M_AL=8, M_ALX=9, M_DI=10, M_DXI=11, M_DIY=12, M_DLI=13,
    M_DLIY=14, M_S=15, M_SIY=16, M_AI=17, M_AIL=18, M_AXI=19;
// instruction classes
localparam [5:0] C_ALU=0, C_ST=1, C_RMW=2, C_SEB=3, C_CLB=4, C_LDM=5,
    C_BBS=6, C_BBC=7, C_BCC=8, C_BRL=9, C_JMP=10, C_JML=11, C_JSR=12,
    C_JSL=13, C_RTS=14, C_RTL=15, C_RTI=16, C_PHR=17, C_PLR=18, C_PEA=19,
    C_PEI=20, C_PER=21, C_PSH=22, C_PUL=23, C_MVN=24, C_MVP=25, C_SEP=26,
    C_CLP=27, C_MPY=28, C_DIV=29, C_RLA=30, C_XAB=31, C_LDT=32, C_BRK=33,
    C_WAI=34, C_STP=35, C_NOP=36, C_IMP=37, C_UNIMP=38;
// ALU subops
localparam [2:0] A_ORA=0, A_AND=1, A_EOR=2, A_ADC=3, A_SBC=4, A_CMP=5, A_LD=6;
// RMW subops
localparam [2:0] R_ASL=0, R_ROL=1, R_LSR=2, R_ROR=3, R_INC=4, R_DEC=5;
// PHR/PLR subops
localparam [2:0] P_ACC=0, P_X=1, P_Y=2, P_DPR=3, P_DT=4, P_PG=5, P_PS=6;
// width select
localparam [1:0] WM=0, WX=1, W8=2, W16=3;
// states
localparam [5:0] RST0=0, FETCH=1, OP1=2, OP2=3, PTR0=4, PTR1=5, RD=6,
    EXEC=7, WR=8, FIMM=9, FREL=10, IMPL=11, STKW=12, STKR=13, PHR0=14,
    PLR0=15, PLR1=16, JSR1=17, JSL1=18, JSL2=19, JMPE=20, JMP24=21,
    RTSE=23, RTLE=25, RTI1=27, RTI2=28, RTI3=29,
    PSHS=30, PULS=31, PULE=32, INTR1=34, INTR2=35, INTR3=36,
    VECR=37, MVCK=38, MVRD=39, MVWR=40, MVUP=41, DIV0=42, DIVL=43, DIVE=44,
    WAIS=45, STPS=46;

// decode: {useb, wsel[1:0], rgt[1:0], sub[2:0], cls[5:0], mode[4:0]}
function [18:0] dec(input [1:0] p, input [7:0] op);
    reg [4:0]  m;
    reg [5:0]  c;
    reg [2:0]  sb;
    reg [1:0]  rg, ws;
    reg        ub, alu;
begin
    m=M_IMP; c=C_UNIMP; sb=0; rg=0; ws=WM; ub=0; alu=0;
    // shared ALU pattern column -> mode
    casez( op[4:0] )
        5'b0_0001: begin m=M_DXI;  alu=1; end
        5'b0_0011: begin m=M_S;    alu=1; end
        5'b0_0101: begin m=M_D;    alu=1; end
        5'b0_0111: begin m=M_DLI;  alu=1; end
        5'b0_1001: begin m=M_IMM;  alu=1; end
        5'b0_1101: begin m=M_A;    alu=1; end
        5'b0_1111: begin m=M_AL;   alu=1; end
        5'b1_0001: begin m=M_DIY;  alu=1; end
        5'b1_0010: begin m=M_DI;   alu=1; end
        5'b1_0011: begin m=M_SIY;  alu=1; end
        5'b1_0101: begin m=M_DX;   alu=1; end
        5'b1_0111: begin m=M_DLIY; alu=1; end
        5'b1_1001: begin m=M_AY;   alu=1; end
        5'b1_1101: begin m=M_AX;   alu=1; end
        5'b1_1111: begin m=M_ALX;  alu=1; end
        default:;
    endcase
    if( p==2'd2 ) begin // 89 prefix: MPY/DIV/RLA/XAB/LDT
        if( alu && op[7:5]==3'd0 ) c=C_MPY; // ORA slots
        if( alu && op[7:5]==3'd1 ) c=C_DIV; // AND slots
        case( op )
            8'h28: begin c=C_XAB; m=M_IMP; end
            8'h49: begin c=C_RLA; m=M_IMM; end
            8'hc2: begin c=C_LDT; m=M_IMM; ws=W8; end
            default:;
        endcase
        if( c==C_UNIMP ) m=M_IMP;
    end else if( p==2'd1 ) begin // 42 prefix: B accumulator versions
        ub=1;
        if( alu ) begin
            case( op[7:5] )
                3'd0: begin c=C_ALU; sb=A_ORA; end
                3'd1: begin c=C_ALU; sb=A_AND; end
                3'd2: begin c=C_ALU; sb=A_EOR; end
                3'd3: begin c=C_ALU; sb=A_ADC; end
                3'd4: begin c=C_ST;  rg=2'd0;  end
                3'd5: begin c=C_ALU; sb=A_LD;  end
                3'd6: begin c=C_ALU; sb=A_CMP; end
                3'd7: begin c=C_ALU; sb=A_SBC; end
            endcase
        end
        case( op ) // valid non-pattern entries of MAME TABLE_OPCODES2
            8'h0a,8'h2a,8'h4a,8'h6a,8'h1a,8'h3a,
            8'h1b,8'h3b,8'h5b,8'h7b,
            8'h8a,8'h98,8'ha8,8'haa: begin c=C_IMP; m=M_IMP; end
            8'h48: begin c=C_PHR; sb=P_ACC; m=M_IMP; end
            8'h68: begin c=C_PLR; sb=P_ACC; m=M_IMP; end
            8'h89,8'hc2,8'he2,8'h02,8'h22,8'h42,8'h62,8'h82,8'ha2:
                begin c=C_UNIMP; m=M_IMP; end
            default:;
        endcase
        if( c==C_UNIMP ) m=M_IMP;
    end else begin
        if( alu ) begin
            case( op[7:5] )
                3'd0: begin c=C_ALU; sb=A_ORA; end
                3'd1: begin c=C_ALU; sb=A_AND; end
                3'd2: begin c=C_ALU; sb=A_EOR; end
                3'd3: begin c=C_ALU; sb=A_ADC; end
                3'd4: begin c=C_ST;  rg=2'd0;  end
                3'd5: begin c=C_ALU; sb=A_LD;  end
                3'd6: begin c=C_ALU; sb=A_CMP; end
                3'd7: begin c=C_ALU; sb=A_SBC; end
            endcase
        end
        case( op )
            8'h00: begin c=C_BRK; m=M_IMP; end
            8'h02: begin c=C_NOP; m=M_IMP; end
            // 7700 bit/memory ops
            8'h04: begin c=C_SEB; m=M_D;  end
            8'h0c: begin c=C_SEB; m=M_A;  end
            8'h14: begin c=C_CLB; m=M_D;  end
            8'h1c: begin c=C_CLB; m=M_A;  end
            8'h24: begin c=C_BBS; m=M_D;  end
            8'h2c: begin c=C_BBS; m=M_A;  end
            8'h34: begin c=C_BBC; m=M_D;  end
            8'h3c: begin c=C_BBC; m=M_A;  end
            8'h64: begin c=C_LDM; m=M_D;  end
            8'h74: begin c=C_LDM; m=M_DX; end
            8'h9c: begin c=C_LDM; m=M_A;  end
            8'h9e: begin c=C_LDM; m=M_AX; end
            // memory RMW
            8'h06: begin c=C_RMW; sb=R_ASL; m=M_D;  end
            8'h16: begin c=C_RMW; sb=R_ASL; m=M_DX; end
            8'h0e: begin c=C_RMW; sb=R_ASL; m=M_A;  end
            8'h1e: begin c=C_RMW; sb=R_ASL; m=M_AX; end
            8'h26: begin c=C_RMW; sb=R_ROL; m=M_D;  end
            8'h36: begin c=C_RMW; sb=R_ROL; m=M_DX; end
            8'h2e: begin c=C_RMW; sb=R_ROL; m=M_A;  end
            8'h3e: begin c=C_RMW; sb=R_ROL; m=M_AX; end
            8'h46: begin c=C_RMW; sb=R_LSR; m=M_D;  end
            8'h56: begin c=C_RMW; sb=R_LSR; m=M_DX; end
            8'h4e: begin c=C_RMW; sb=R_LSR; m=M_A;  end
            8'h5e: begin c=C_RMW; sb=R_LSR; m=M_AX; end
            8'h66: begin c=C_RMW; sb=R_ROR; m=M_D;  end
            8'h76: begin c=C_RMW; sb=R_ROR; m=M_DX; end
            8'h6e: begin c=C_RMW; sb=R_ROR; m=M_A;  end
            8'h7e: begin c=C_RMW; sb=R_ROR; m=M_AX; end
            8'hc6: begin c=C_RMW; sb=R_DEC; m=M_D;  end
            8'hd6: begin c=C_RMW; sb=R_DEC; m=M_DX; end
            8'hce: begin c=C_RMW; sb=R_DEC; m=M_A;  end
            8'hde: begin c=C_RMW; sb=R_DEC; m=M_AX; end
            8'he6: begin c=C_RMW; sb=R_INC; m=M_D;  end
            8'hf6: begin c=C_RMW; sb=R_INC; m=M_DX; end
            8'hee: begin c=C_RMW; sb=R_INC; m=M_A;  end
            8'hfe: begin c=C_RMW; sb=R_INC; m=M_AX; end
            // stack singles
            8'h08: begin c=C_PHR; sb=P_PS;  m=M_IMP; end
            8'h28: begin c=C_PLR; sb=P_PS;  m=M_IMP; end
            8'h48: begin c=C_PHR; sb=P_ACC; m=M_IMP; end
            8'h68: begin c=C_PLR; sb=P_ACC; m=M_IMP; end
            8'h0b: begin c=C_PHR; sb=P_DPR; m=M_IMP; end
            8'h2b: begin c=C_PLR; sb=P_DPR; m=M_IMP; end
            8'h4b: begin c=C_PHR; sb=P_PG;  m=M_IMP; end
            8'h8b: begin c=C_PHR; sb=P_DT;  m=M_IMP; end
            8'hab: begin c=C_PLR; sb=P_DT;  m=M_IMP; end
            8'h5a: begin c=C_PHR; sb=P_Y;   m=M_IMP; end
            8'h7a: begin c=C_PLR; sb=P_Y;   m=M_IMP; end
            8'hda: begin c=C_PHR; sb=P_X;   m=M_IMP; end
            8'hfa: begin c=C_PLR; sb=P_X;   m=M_IMP; end
            // branches
            8'h10,8'h30,8'h50,8'h70,8'h90,8'hb0,8'hd0,8'hf0,8'h80:
                   begin c=C_BCC; m=M_IMM; ws=W8; end
            8'h82: begin c=C_BRL; m=M_IMM; ws=W16; end
            // jumps and subroutines
            8'h20: begin c=C_JSR; m=M_A;   end
            8'h22: begin c=C_JSL; m=M_AL;  end
            8'hfc: begin c=C_JSR; m=M_AXI; end
            8'h4c: begin c=C_JMP; m=M_A;   end
            8'h5c: begin c=C_JML; m=M_AL;  end
            8'h6c: begin c=C_JMP; m=M_AI;  end
            8'h7c: begin c=C_JMP; m=M_AXI; end
            8'hdc: begin c=C_JML; m=M_AIL; end
            8'h40: begin c=C_RTI; m=M_IMP; end
            8'h60: begin c=C_RTS; m=M_IMP; end
            8'h6b: begin c=C_RTL; m=M_IMP; end
            // stack push effective
            8'h62: begin c=C_PER; m=M_IMM; ws=W16; end
            8'hd4: begin c=C_PEI; m=M_D;   ws=W16; end
            8'hf4: begin c=C_PEA; m=M_IMM; ws=W16; end
            8'heb: begin c=C_PSH; m=M_IMM; ws=W8;  end
            8'hfb: begin c=C_PUL; m=M_IMM; ws=W8;  end
            // block moves
            8'h44: begin c=C_MVP; m=M_A;   end // 2 bank bytes
            8'h54: begin c=C_MVN; m=M_A;   end
            // flags via immediate
            8'hc2: begin c=C_CLP; m=M_IMM; ws=W8; end
            8'he2: begin c=C_SEP; m=M_IMM; ws=W8; end
            // index register ops
            8'ha0: begin c=C_ALU; sb=A_LD;  rg=2'd2; m=M_IMM; ws=WX; end
            8'ha4: begin c=C_ALU; sb=A_LD;  rg=2'd2; m=M_D;   ws=WX; end
            8'hb4: begin c=C_ALU; sb=A_LD;  rg=2'd2; m=M_DX;  ws=WX; end
            8'hac: begin c=C_ALU; sb=A_LD;  rg=2'd2; m=M_A;   ws=WX; end
            8'hbc: begin c=C_ALU; sb=A_LD;  rg=2'd2; m=M_AX;  ws=WX; end
            8'ha2: begin c=C_ALU; sb=A_LD;  rg=2'd1; m=M_IMM; ws=WX; end
            8'ha6: begin c=C_ALU; sb=A_LD;  rg=2'd1; m=M_D;   ws=WX; end
            8'hb6: begin c=C_ALU; sb=A_LD;  rg=2'd1; m=M_DY;  ws=WX; end
            8'hae: begin c=C_ALU; sb=A_LD;  rg=2'd1; m=M_A;   ws=WX; end
            8'hbe: begin c=C_ALU; sb=A_LD;  rg=2'd1; m=M_AY;  ws=WX; end
            8'hc0: begin c=C_ALU; sb=A_CMP; rg=2'd2; m=M_IMM; ws=WX; end
            8'hc4: begin c=C_ALU; sb=A_CMP; rg=2'd2; m=M_D;   ws=WX; end
            8'hcc: begin c=C_ALU; sb=A_CMP; rg=2'd2; m=M_A;   ws=WX; end
            8'he0: begin c=C_ALU; sb=A_CMP; rg=2'd1; m=M_IMM; ws=WX; end
            8'he4: begin c=C_ALU; sb=A_CMP; rg=2'd1; m=M_D;   ws=WX; end
            8'hec: begin c=C_ALU; sb=A_CMP; rg=2'd1; m=M_A;   ws=WX; end
            8'h84: begin c=C_ST; rg=2'd2; m=M_D;  ws=WX; end
            8'h94: begin c=C_ST; rg=2'd2; m=M_DX; ws=WX; end
            8'h8c: begin c=C_ST; rg=2'd2; m=M_A;  ws=WX; end
            8'h86: begin c=C_ST; rg=2'd1; m=M_D;  ws=WX; end
            8'h96: begin c=C_ST; rg=2'd1; m=M_DY; ws=WX; end
            8'h8e: begin c=C_ST; rg=2'd1; m=M_A;  ws=WX; end
            // implied group (transfers, acc shifts, flag ops, index inc/dec)
            8'h0a,8'h2a,8'h4a,8'h6a,8'h1a,8'h3a,
            8'h18,8'h38,8'h58,8'h78,8'hb8,8'hd8,8'hf8,
            8'h8a,8'h98,8'ha8,8'haa,8'h9a,8'hba,8'h9b,8'hbb,
            8'h1b,8'h3b,8'h5b,8'h7b,
            8'hca,8'h88,8'he8,8'hc8: begin c=C_IMP; m=M_IMP; end
            8'hea: begin c=C_NOP; m=M_IMP; end
            8'hcb: begin c=C_WAI; m=M_IMP; end
            8'hdb: begin c=C_STP; m=M_IMP; end
            default:;
        endcase
        if( c==C_UNIMP ) m=M_IMP;
    end
    dec = {ub, ws, rg, sb, c, m};
end
endfunction

// index registers masked by the x flag, accumulators by useb
wire [15:0] xv  = fx ? {8'd0,x[7:0]} : x;
wire [15:0] yv  = fx ? {8'd0,y[7:0]} : y;
wire [15:0] acc = useb ? b : a;
// width helpers on registered operands
wire [15:0] avm  = wide ? acc  : {8'd0,acc[7:0]};
wire [15:0] srcv = rgt==2'd1 ? (wide ? x:{8'd0,x[7:0]}) :
                   rgt==2'd2 ? (wide ? y:{8'd0,y[7:0]}) : avm;
wire [15:0] opm  = wide ? opnd : {8'd0,opnd[7:0]};
// adders for ADC/SBC/CMP
wire [16:0] adds = {1'b0,srcv} + {1'b0,opm} + {16'd0,fc};
wire [16:0] subs = {1'b0,srcv} - {1'b0,opm} - {16'd0,~fc};
wire [16:0] cmps = {1'b0,srcv} - {1'b0,opm};
wire        addc = wide ? adds[16] : adds[8];
wire        subb = wide ? subs[16] : subs[8]; // borrow
wire        cmpb = wide ? cmps[16] : cmps[8];
wire        addv = wide ? (~(srcv[15]^opm[15]) & (srcv[15]^adds[15]))
                        : (~(srcv[ 7]^opm[ 7]) & (srcv[ 7]^adds[ 7]));
wire        subv = wide ? ( (srcv[15]^opm[15]) & (srcv[15]^subs[15]))
                        : ( (srcv[ 7]^opm[ 7]) & (srcv[ 7]^subs[ 7]));
// interrupt take decision, evaluated at instruction boundaries
wire        take_irq = irq_rq && !fi && irq_lvl>ipl;
// direct page / stack sums use only the low byte of the fetched offset
wire [15:0] dsum   = dpr + {8'd0,bdin[7:0]};
wire [15:0] ssum   = s   + {8'd0,bdin[7:0]};
// multiplier
wire [31:0] mprod  = wide ? {16'd0,avm}*{16'd0,opm}
                          : {24'd0,avm[7:0]}*{24'd0,opm[7:0]};
// current PS byte
wire [ 7:0] ps   = {fn,fv,fm,fx,fd,fi,fz,fc};
// BBS/BBC mask, width-adjusted
wire [15:0] immm = wide ? imm : {8'd0,imm[7:0]};

// branch condition
function bcond(input [7:0] op);
    case( op[7:4] )
        4'h1: bcond = !fn;      // BPL
        4'h3: bcond =  fn;      // BMI
        4'h5: bcond = !fv;      // BVC
        4'h7: bcond =  fv;      // BVS
        4'h9: bcond = !fc;      // BCC
        4'hb: bcond =  fc;      // BCS
        4'hd: bcond = !fz;      // BNE
        4'hf: bcond =  fz;      // BEQ
        default: bcond = 1;     // BRA
    endcase
endfunction

// PSH/PUL entry byte count per mask bit
function [1:0] plen(input [3:0] bit_ix);
    case( bit_ix )
        4'd0,4'd1: plen = fm ? 2'd1 : 2'd2; // A, B
        4'd2,4'd3: plen = fx ? 2'd1 : 2'd2; // X, Y
        4'd4:      plen = 2'd2;             // DPR
        4'd5,4'd6: plen = 2'd1;             // DT, PG
        default:   plen = 2'd2;             // PS+IPL
    endcase
endfunction

// alu_res carries the value for WRACC/SETNZ, ps_nx for SETPS
`define WRACC if(useb) begin b[7:0]<=alu_res[7:0]; if(wide) b[15:8]<=alu_res[15:8]; end \
              else     begin a[7:0]<=alu_res[7:0]; if(wide) a[15:8]<=alu_res[15:8]; end
`define SETNZ begin fz <= (alu_res&(wide?16'hffff:16'h00ff))==16'd0; \
                    fn <= wide ? alu_res[15] : alu_res[7]; end
`define SETPS(v) begin ps_nx = (v); fn<=ps_nx[7]; fv<=ps_nx[6]; fm<=ps_nx[5]; \
                       fx<=ps_nx[4]; fd<=ps_nx[3]; fi<=ps_nx[2]; \
                       fz<=ps_nx[1]; fc<=ps_nx[0]; end

// operand fetch length in bytes for OP1
function [1:0] op1len(input [4:0] m, input w);
    case( m )
        M_A,M_AX,M_AY,M_AI,M_AIL,M_AXI,M_AL,M_ALX: op1len = 2'd2;
        M_IMM: op1len = w ? 2'd2 : 2'd1;
        default: op1len = 2'd1; // direct/stack offsets, MVN banks read 2
    endcase
endfunction

// state entered once the effective address is ready
function [5:0] nx_exec(input [5:0] c);
    case( c )
        C_ALU,C_MPY,C_DIV,C_RMW,C_SEB,C_CLB,C_BBS,C_BBC,C_PEI: nx_exec = RD;
        C_ST:  nx_exec = WR;
        C_LDM: nx_exec = FIMM;
        C_JMP: nx_exec = JMPE;
        C_JML: nx_exec = JMP24;
        C_JSR: nx_exec = JSR1;
        C_JSL: nx_exec = JSL1;
        default: nx_exec = FETCH;
    endcase
endfunction

// memory request helpers
task req(input [23:0] ad, input w16, input wr, input [15:0] d, input [5:0] nxt);
begin
    breq  <= 1;
    baddr <= ad;
    bw16  <= w16;
    bwr   <= wr;
    bdout <= d;
    st    <= nxt;
end
endtask

task push(input [15:0] d, input [1:0] n, input [5:0] after);
begin // pushes MSB first, as MAME m37710i_push_16
    stk_dat <= d;
    stk_cnt <= n;
    ret_st  <= after;
    req( {8'd0,s}, 1'b0, 1'b1, n==2'd2 ? {8'd0,d[15:8]} : {8'd0,d[7:0]}, STKW );
end
endtask

task pull(input [1:0] n, input [5:0] after);
begin // pulls LSB first into sdat
    stk_cnt <= n;
    stk_ix  <= 0;
    ret_st  <= after;
    req( {8'd0,s+16'd1}, 1'b0, 1'b0, 16'd0, STKR );
end
endtask

reg [15:0] alu_res;
reg [ 7:0] ps_nx;
reg [ 3:0] rotn;
reg [16:0] rem_nx;

always @(posedge clk) begin
    if( rst ) begin
        a<=0; b<=0; x<=0; y<=0; dpr<=0; pc<=0; pg<=0; dt<=0;
        s <= 16'h0100;
        {fn,fv,fd,fz,fc} <= 0;
        fm<=0; fx<=0; fi<=1; ipl<=0;
        pfx<=0; ir<=0; stp<=0;
        breq<=0; baddr<=0; bw16<=0; bwr<=0; bdout<=0;
        irq_ack<=0; irq_ackix<=0;
        mode<=0; cls<=0; sub<=0; rgt<=0; useb<=0; wide<=0;
        ea<=0; tmp<=0; opnd<=0; imm<=0; ptrlo<=0; sdat<=0;
        stk_dat<=0; stk_cnt<=0; stk_ix<=0; ret_st<=0; pbit<=0;
        vec<=0; int_msk<=0; int_lvl<=0; mvsrc<=0; mvdst<=0;
        dvd<=0; quo<=0; rem<=0; dvs<=0; dcnt<=0;
        st <= RST0;
        req( 24'h00fffe, 1'b1, 1'b0, 16'd0, RST0 );
    end else if( cen ) begin
        irq_ack <= 0;
        case( st )
        RST0: if( back ) begin
            breq <= 0;
            pc   <= bdin;
            st   <= FETCH;
        end
        //////////////////////////////////////////////////////////// fetch
        FETCH: if( !breq ) begin
            if( take_irq && pfx==2'd0 ) begin // never split a prefixed opcode
                irq_ack   <= 1;
                irq_ackix <= irq_ix;
                vec       <= 16'hffce + {10'd0,irq_ix,1'b0};
                int_msk   <= 1;
                int_lvl   <= irq_lvl;
                push( {8'd0,pg}, 2'd1, INTR1 );
                st <= STKW;
            end else begin
                req( {pg,pc}, 1'b0, 1'b0, 16'd0, FETCH );
            end
        end else if( back ) begin
            breq <= 0;
            pc   <= pc + 16'd1;
            if( pfx==0 && bdin[7:0]==8'h42 ) begin
                pfx <= 2'd1;
            end else if( pfx==0 && bdin[7:0]==8'h89 ) begin
                pfx <= 2'd2;
            end else begin
                ir   <= bdin[7:0];
                begin : do_decode
                    reg [18:0] d;
                    reg [ 1:0] ws;
                    d    = dec( pfx, bdin[7:0] );
                    mode <= d[4:0];
                    cls  <= d[10:5];
                    sub  <= d[13:11];
                    rgt  <= d[15:14];
                    ws   = d[17:16];
                    useb <= d[18];
                    wide <= ws==WM ? !fm : ws==WX ? !fx : ws==W16;
                    pfx  <= 0;
                    case( d[4:0] )
                        M_IMP:
                            case( d[10:5] )
                                C_RTS:   pull( 2'd2, RTSE );
                                C_RTL:   pull( 2'd3, RTLE );
                                C_RTI:   pull( 2'd2, RTI1 );
                                C_PHR:   st <= PHR0;
                                C_PLR:   st <= PLR0;
                                C_BRK: begin
                                    pc      <= pc + 16'd2; // skip signature
                                    vec     <= 16'hfffa;
                                    int_msk <= 0;
                                    push( {8'd0,pg}, 2'd1, INTR1 );
                                end
                                C_WAI:   st <= WAIS;
                                C_STP: begin stp<=1; st<=STPS; end
                                default: st <= IMPL; // C_IMP/C_XAB/C_NOP/C_UNIMP
                            endcase
                        default: begin
                            // MVN/MVP fetch two bank bytes like an A operand
                            req( {pg,pc+16'd1}, op1len(d[4:0], ws==WM ? !fm :
                                 ws==WX ? !fx : ws==W16)==2'd2, 1'b0, 16'd0, OP1 );
                        end
                    endcase
                end
            end
        end
        //////////////////////////////////////////////////////////// operand
        OP1: if( back ) begin
            breq <= 0;
            pc   <= pc + {14'd0, op1len(mode,wide)};
            case( mode )
                M_IMM: begin
                    opnd <= bdin;
                    case( cls )
                        C_PEA: push( bdin, 2'd2, FETCH );
                        C_PER: push( pc+16'd2+bdin, 2'd2, FETCH );
                        C_PSH: begin opnd<=bdin; pbit<=0; st<=PSHS; end
                        C_PUL: begin opnd<=bdin; pbit<=4'd7; st<=PULS; end
                        C_DIV: st <= DIV0;
                        default: st <= EXEC; // ALU/BCC/BRL/SEP/CLP/RLA/LDT/MPY
                    endcase
                end
                M_D:   begin ea <= {8'd0,dsum};      st <= nx_exec(cls); end
                M_DX:  begin ea <= {8'd0,dsum+xv};   st <= nx_exec(cls); end
                M_DY:  begin ea <= {8'd0,dsum+yv};   st <= nx_exec(cls); end
                M_S:   begin ea <= {8'd0,ssum};      st <= nx_exec(cls); end
                M_A: begin
                    if( cls==C_MVN || cls==C_MVP ) begin
                        mvdst <= bdin[ 7:0];
                        mvsrc <= bdin[15:8];
                        dt    <= bdin[ 7:0];
                        st    <= MVCK;
                    end else if( cls==C_JMP || cls==C_JSR ) begin
                        ea <= {8'd0,bdin};
                        st <= nx_exec(cls);
                    end else begin
                        ea <= {dt,bdin};
                        st <= nx_exec(cls);
                    end
                end
                M_AX:  begin ea <= {dt,bdin}+{8'd0,xv}; st <= nx_exec(cls); end
                M_AY:  begin ea <= {dt,bdin}+{8'd0,yv}; st <= nx_exec(cls); end
                M_AL,M_ALX: begin
                    tmp <= {8'd0,bdin};
                    req( {pg,pc+16'd2}, 1'b0, 1'b0, 16'd0, OP2 );
                end
                M_DI,M_DIY,M_DLI,M_DLIY: begin
                    tmp <= {8'd0,dsum};
                    req( {8'd0,dsum}, 1'b1, 1'b0, 16'd0, PTR0 );
                end
                M_DXI: begin
                    tmp <= {8'd0,dsum+xv};
                    req( {8'd0,dsum+xv}, 1'b1, 1'b0, 16'd0, PTR0 );
                end
                M_SIY: begin
                    tmp <= {8'd0,ssum};
                    req( {8'd0,ssum}, 1'b1, 1'b0, 16'd0, PTR0 );
                end
                M_AI,M_AIL: begin
                    tmp <= {8'd0,bdin};
                    req( {8'd0,bdin}, 1'b1, 1'b0, 16'd0, PTR0 );
                end
                M_AXI: begin
                    tmp <= {pg,bdin+xv};
                    req( {pg,bdin+xv}, 1'b1, 1'b0, 16'd0, PTR0 );
                end
                default: st <= FETCH;
            endcase
        end
        OP2: if( back ) begin // third byte of long addresses
            breq <= 0;
            pc   <= pc + 16'd1;
            ea   <= mode==M_ALX ? {bdin[7:0],tmp[15:0]}+{8'd0,xv}
                                : {bdin[7:0],tmp[15:0]};
            st   <= nx_exec(cls);
        end
        PTR0: if( back ) begin
            breq <= 0;
            case( mode )
                M_DI,M_DXI: begin ea <= {dt,bdin};           st <= nx_exec(cls); end
                M_DIY:      begin ea <= {dt,bdin}+{8'd0,yv}; st <= nx_exec(cls); end
                M_SIY:      begin ea <= {dt,bdin+yv};        st <= nx_exec(cls); end
                M_AXI, M_AI:
                    if( cls==C_JSR ) begin
                        ea <= {8'd0,bdin};
                        st <= JSR1;
                    end else begin // JMP
                        pc <= bdin;
                        st <= FETCH;
                    end
                M_DLI,M_DLIY,M_AIL: begin
                    ptrlo <= bdin[7:0];
                    tmp   <= {16'd0,bdin[15:8]}; // keep high pointer byte
                    req( baddr+24'd2, 1'b0, 1'b0, 16'd0, PTR1 );
                end
                default: st <= FETCH;
            endcase
        end
        PTR1: if( back ) begin // third pointer byte
            breq <= 0;
            case( mode )
                M_DLI:  begin ea <= {bdin[7:0],tmp[7:0],ptrlo}; st <= nx_exec(cls); end
                M_DLIY: begin
                    ea <= {bdin[7:0],tmp[7:0],ptrlo}+{8'd0,yv};
                    st <= nx_exec(cls);
                end
                default: begin // M_AIL: JML (a)
                    pg <= bdin[7:0];
                    pc <= {tmp[7:0],ptrlo};
                    st <= FETCH;
                end
            endcase
        end
        //////////////////////////////////////////////////////////// data
        RD: if( !breq ) begin
            req( ea, wide, 1'b0, 16'd0, RD );
        end else if( back ) begin
            breq <= 0;
            opnd <= bdin;
            case( cls )
                C_SEB,C_CLB,C_BBS,C_BBC:
                    req( {pg,pc}, wide, 1'b0, 16'd0, FIMM );
                C_PEI: begin
                    push( bdin, 2'd2, FETCH );
                end
                C_DIV: st <= DIV0;
                default: st <= EXEC; // C_ALU, C_RMW, C_MPY
            endcase
            if( cls==C_SEB || cls==C_CLB || cls==C_BBS || cls==C_BBC )
                pc <= pc + (wide?16'd2:16'd1);
        end
        FIMM: if( !breq ) begin // immediate after EA (LDM)
            req( {pg,pc}, wide, 1'b0, 16'd0, FIMM );
            pc <= pc + (wide?16'd2:16'd1);
        end else if( back ) begin
            breq <= 0;
            imm  <= bdin;
            case( cls )
                C_LDM: req( ea, wide, 1'b1, bdin, WR );
                C_SEB: req( ea, wide, 1'b1, opnd |  bdin, WR );
                C_CLB: req( ea, wide, 1'b1, opnd & ~bdin, WR );
                default: req( {pg,pc}, 1'b0, 1'b0, 16'd0, FREL ); // BBS/BBC
            endcase
        end
        FREL: if( back ) begin
            breq <= 0;
            if( (cls==C_BBS && (opm & immm)==immm ) ||
                (cls==C_BBC && (opm & immm)==16'd0) )
                pc <= pc + 16'd1 + {{8{bdin[7]}},bdin[7:0]};
            else
                pc <= pc + 16'd1;
            st <= FETCH;
        end
        WR: if( !breq ) begin // only C_ST enters with no request pending
            req( ea, wide, 1'b1, srcv, WR );
        end else if( back ) begin
            breq <= 0;
            st   <= FETCH;
        end
        //////////////////////////////////////////////////////////// execute
        EXEC: begin
            st <= FETCH;
            case( cls )
                C_ALU: case( sub )
                    A_ORA: begin alu_res = avm | opm;  `WRACC `SETNZ end
                    A_AND: begin alu_res = avm & opm;  `WRACC `SETNZ end
                    A_EOR: begin alu_res = avm ^ opm;  `WRACC `SETNZ end
                    A_ADC: begin // decimal mode pending, see README
                        alu_res = adds[15:0];
                        `WRACC `SETNZ
                        fc <= addc;
                        fv <= addv;
                    end
                    A_SBC: begin
                        alu_res = subs[15:0];
                        `WRACC `SETNZ
                        fc <= ~subb;
                        fv <= subv;
                    end
                    A_CMP: begin
                        alu_res = cmps[15:0];
                        `SETNZ
                        fc <= ~cmpb;
                    end
                    A_LD: begin
                        alu_res = opm;
                        `SETNZ
                        case( rgt )
                            2'd1: begin x[7:0]<=opm[7:0]; if(wide) x[15:8]<=opm[15:8]; end
                            2'd2: begin y[7:0]<=opm[7:0]; if(wide) y[15:8]<=opm[15:8]; end
                            default: `WRACC
                        endcase
                    end
                    default:;
                endcase
                C_RMW: begin
                    case( sub )
                        R_ASL: begin alu_res = {opm[14:0],1'b0}; fc <= wide?opm[15]:opm[7]; end
                        R_ROL: begin alu_res = {opm[14:0],fc};   fc <= wide?opm[15]:opm[7]; end
                        R_LSR: begin
                            alu_res = wide ? {1'b0,opm[15:1]} : {9'd0,opm[7:1]};
                            fc <= opm[0];
                        end
                        R_ROR: begin
                            alu_res = wide ? {fc,opm[15:1]} : {8'd0,fc,opm[7:1]};
                            fc <= opm[0];
                        end
                        R_INC: alu_res = opm + 16'd1;
                        default: alu_res = opm - 16'd1;
                    endcase
                    `SETNZ
                    req( ea, wide, 1'b1, alu_res, WR );
                end
                C_BCC: begin
                    if( bcond(ir) ) pc <= pc + {{8{opnd[7]}},opnd[7:0]};
                end
                C_BRL: pc <= pc + opnd;
                C_SEP: `SETPS(ps |  opnd[7:0])
                C_CLP: `SETPS(ps & ~opnd[7:0])
                C_RLA: begin // rotate left A by n, no flags
                    rotn = wide ? opnd[3:0] : {1'b0,opnd[2:0]};
                    if( wide ) a <= (a<<rotn)|(a>>(16-{12'd0,rotn}));
                    else a[7:0] <= (a[7:0]<<rotn[2:0])|(a[7:0]>>(8-{5'd0,rotn[2:0]}));
                end
                C_LDT: dt <= opnd[7:0];
                C_MPY: begin
                    a  <= mprod[15:0];
                    b  <= mprod[31:16];
                    if( !wide ) begin
                        a <= {a[15:8],mprod[ 7:0]};
                        b <= {b[15:8],mprod[15:8]};
                    end
                    fz <= mprod==0;
                    fn <= wide ? mprod[31] : mprod[15];
                    fc <= 0;
                end
                default:;
            endcase
        end
        IMPL: begin // single-cycle implied ops
            st <= FETCH;
            case( ir )
                8'h0a: begin // ASL acc
                    alu_res = {avm[14:0],1'b0};
                    fc <= wide?avm[15]:avm[7];
                    `WRACC `SETNZ
                end
                8'h2a: begin // ROL acc
                    alu_res = {avm[14:0],fc};
                    fc <= wide?avm[15]:avm[7];
                    `WRACC `SETNZ
                end
                8'h4a: begin // LSR acc
                    alu_res = wide ? {1'b0,avm[15:1]} : {9'd0,avm[7:1]};
                    fc <= avm[0];
                    `WRACC `SETNZ
                end
                8'h6a: begin // ROR acc
                    alu_res = wide ? {fc,avm[15:1]} : {8'd0,fc,avm[7:1]};
                    fc <= avm[0];
                    `WRACC `SETNZ
                end
                8'h1a: begin alu_res = avm-16'd1; `WRACC `SETNZ end
                8'h3a: begin alu_res = avm+16'd1; `WRACC `SETNZ end
                8'h18: fc <= 0;
                8'h38: fc <= 1;
                8'h58: fi <= 0;
                8'h78: fi <= 1;
                8'hb8: fv <= 0;
                8'hd8: fm <= 0;
                8'hf8: fm <= 1;
                8'h8a: begin // TXA / TXB
                    alu_res = xv; `WRACC `SETNZ
                end
                8'h98: begin // TYA / TYB
                    alu_res = yv; `WRACC `SETNZ
                end
                8'ha8: begin // TAY / TBY, width x
                    y[7:0] <= acc[7:0];
                    if( !fx ) y[15:8] <= acc[15:8];
                    fz <= (fx ? {8'd0,acc[7:0]} : acc)==0;
                    fn <= fx ? acc[7] : acc[15];
                end
                8'haa: begin // TAX / TBX
                    x[7:0] <= acc[7:0];
                    if( !fx ) x[15:8] <= acc[15:8];
                    fz <= (fx ? {8'd0,acc[7:0]} : acc)==0;
                    fn <= fx ? acc[7] : acc[15];
                end
                8'h9a: s <= xv; // TXS zero-extends in x8, like MAME
                8'hba: begin    // TSX
                    x[7:0] <= s[7:0];
                    if( !fx ) x[15:8] <= s[15:8];
                    fz <= (fx ? {8'd0,s[7:0]} : s)==0;
                    fn <= fx ? s[7] : s[15];
                end
                8'h9b: begin // TXY
                    y[7:0] <= x[7:0];
                    if( !fx ) y[15:8] <= x[15:8];
                    fz <= xv==0;
                    fn <= fx ? x[7] : x[15];
                end
                8'hbb: begin // TYX
                    x[7:0] <= y[7:0];
                    if( !fx ) x[15:8] <= y[15:8];
                    fz <= yv==0;
                    fn <= fx ? y[7] : y[15];
                end
                8'h1b: s <= useb ? b : a;   // TAS / TBS, always 16 bit
                8'h3b: begin                // TSA / TSB
                    if( useb ) b <= s; else a <= s;
                    fz <= s==0;
                    fn <= s[15];
                end
                8'h5b: dpr <= useb ? b : a; // TAD / TBD
                8'h7b: begin                // TDA / TDB
                    if( useb ) b <= dpr; else a <= dpr;
                    fz <= dpr==0;
                    fn <= dpr[15];
                end
                8'hca: begin // DEX
                    alu_res = xv - 16'd1;
                    x[7:0] <= alu_res[7:0];
                    if( !fx ) x[15:8] <= alu_res[15:8];
                    fz <= (fx ? {8'd0,alu_res[7:0]} : alu_res)==0;
                    fn <= fx ? alu_res[7] : alu_res[15];
                end
                8'he8: begin // INX
                    alu_res = xv + 16'd1;
                    x[7:0] <= alu_res[7:0];
                    if( !fx ) x[15:8] <= alu_res[15:8];
                    fz <= (fx ? {8'd0,alu_res[7:0]} : alu_res)==0;
                    fn <= fx ? alu_res[7] : alu_res[15];
                end
                8'h88: begin // DEY
                    alu_res = yv - 16'd1;
                    y[7:0] <= alu_res[7:0];
                    if( !fx ) y[15:8] <= alu_res[15:8];
                    fz <= (fx ? {8'd0,alu_res[7:0]} : alu_res)==0;
                    fn <= fx ? alu_res[7] : alu_res[15];
                end
                8'hc8: begin // INY
                    alu_res = yv + 16'd1;
                    y[7:0] <= alu_res[7:0];
                    if( !fx ) y[15:8] <= alu_res[15:8];
                    fz <= (fx ? {8'd0,alu_res[7:0]} : alu_res)==0;
                    fn <= fx ? alu_res[7] : alu_res[15];
                end
                8'h28: if( cls==C_XAB ) begin // 89 28
                    a <= b;
                    b <= a;
                    fz <= (wide ? b : {8'd0,b[7:0]})==0;
                    fn <= wide ? b[15] : b[7];
                end
                default: begin
`ifdef SIMULATION
                    if( cls==C_UNIMP )
                        $display("jt37702: unimplemented opcode %x (pfx %d) at PC=%x",
                                 ir, pfx, {pg,pc});
`endif
                end
            endcase
        end
        //////////////////////////////////////////////////////////// stack
        STKW: if( back ) begin
            breq <= 0;
            s    <= s - 16'd1;
            if( stk_cnt==2'd2 ) begin
                stk_cnt <= 2'd1;
                req( {8'd0,s-16'd1}, 1'b0, 1'b1, {8'd0,stk_dat[7:0]}, STKW );
            end else begin
                st <= ret_st;
            end
        end
        STKR: if( back ) begin
            breq <= 0;
            s    <= s + 16'd1;
            case( stk_ix )
                2'd0: sdat[ 7: 0] <= bdin[7:0];
                2'd1: sdat[15: 8] <= bdin[7:0];
                default: sdat[23:16] <= bdin[7:0];
            endcase
            stk_ix <= stk_ix + 2'd1;
            if( stk_cnt==2'd1 ) begin
                st <= ret_st;
            end else begin
                stk_cnt <= stk_cnt - 2'd1;
                req( {8'd0,s+16'd2}, 1'b0, 1'b0, 16'd0, STKR );
            end
        end
        PHR0: case( sub )
            P_ACC: push( acc, fm?2'd1:2'd2, FETCH );
            P_X:   push( x, fx?2'd1:2'd2, FETCH );
            P_Y:   push( y, fx?2'd1:2'd2, FETCH );
            P_DPR: push( dpr, 2'd2, FETCH );
            P_DT:  push( {8'd0,dt}, 2'd1, FETCH );
            P_PG:  push( {8'd0,pg}, 2'd1, FETCH );
            default: push( {5'd0,ipl,ps}, 2'd2, FETCH ); // PHP: ipl then ps
        endcase
        PLR0: case( sub )
            P_ACC: pull( fm?2'd1:2'd2, PLR1 );
            P_X,P_Y: pull( fx?2'd1:2'd2, PLR1 );
            P_DPR,P_PS: pull( 2'd2, PLR1 );
            default: pull( 2'd1, PLR1 ); // P_DT
        endcase
        PLR1: begin
            st <= FETCH;
            case( sub )
                P_ACC: begin
                    alu_res = fm ? {8'd0,sdat[7:0]} : sdat[15:0];
                    if(useb) begin b[7:0]<=sdat[7:0]; if(!fm) b[15:8]<=sdat[15:8]; end
                    else     begin a[7:0]<=sdat[7:0]; if(!fm) a[15:8]<=sdat[15:8]; end
                    fz <= alu_res==0;
                    fn <= fm ? sdat[7] : sdat[15];
                end
                P_X: begin
                    x[7:0] <= sdat[7:0];
                    if( !fx ) x[15:8] <= sdat[15:8];
                    fz <= (fx?{8'd0,sdat[7:0]}:sdat[15:0])==0;
                    fn <= fx ? sdat[7] : sdat[15];
                end
                P_Y: begin
                    y[7:0] <= sdat[7:0];
                    if( !fx ) y[15:8] <= sdat[15:8];
                    fz <= (fx?{8'd0,sdat[7:0]}:sdat[15:0])==0;
                    fn <= fx ? sdat[7] : sdat[15];
                end
                P_DPR: dpr <= sdat[15:0];
                P_DT: begin
                    dt <= sdat[7:0];
                    fz <= sdat[7:0]==0;
                    fn <= sdat[7];
                end
                default: begin // PLP: ps then ipl
                    `SETPS(sdat[7:0])
                    ipl <= sdat[10:8];
                end
            endcase
        end
        //////////////////////////////////////////////////////////// jumps
        JSR1: push( pc, 2'd2, JMPE );
        JSL1: push( {8'd0,pg}, 2'd1, JSL2 );
        JSL2: push( pc, 2'd2, JMP24 );
        JMPE: begin pc <= ea[15:0]; st <= FETCH; end
        JMP24: begin pg <= ea[23:16]; pc <= ea[15:0]; st <= FETCH; end
        RTSE: begin pc <= sdat[15:0]; st <= FETCH; end
        RTLE: begin pc <= sdat[15:0]; pg <= sdat[23:16]; st <= FETCH; end
        RTI1: begin // ps, ipl pulled; now pc
            `SETPS(sdat[7:0])
            ipl <= sdat[10:8];
            pull( 2'd2, RTI2 );
        end
        RTI2: begin
            pc <= sdat[15:0];
            pull( 2'd1, RTI3 );
        end
        RTI3: begin
            pg <= sdat[7:0];
            st <= FETCH;
        end
        //////////////////////////////////////////////////////////// PSH/PUL
        PSHS: begin // scan mask from bit 0 up (A,B,X,Y,DPR,DT,PG,PS)
            if( pbit==4'd8 ) st <= FETCH;
            else if( !opnd[pbit] ) pbit <= pbit + 4'd1;
            else begin
                pbit <= pbit + 4'd1;
                case( pbit[2:0] )
                    3'd0: push( a, plen(pbit), PSHS );
                    3'd1: push( b, plen(pbit), PSHS );
                    3'd2: push( x, plen(pbit), PSHS );
                    3'd3: push( y, plen(pbit), PSHS );
                    3'd4: push( dpr, 2'd2, PSHS );
                    3'd5: push( {8'd0,dt}, 2'd1, PSHS );
                    3'd6: push( {8'd0,pg}, 2'd1, PSHS );
                    default: push( {5'd0,ipl,ps}, 2'd2, PSHS );
                endcase
            end
        end
        PULS: begin // scan mask from bit 7 down, bit 6 has no effect
            if( pbit==4'hf ) st <= FETCH;
            else if( pbit==4'd6 || !opnd[pbit] ) pbit <= pbit - 4'd1;
            else begin
                pull( plen(pbit), PULE );
            end
        end
        PULE: begin
            st   <= PULS;
            pbit <= pbit - 4'd1;
            case( pbit[2:0] ) // no flag updates on PUL
                3'd7: begin `SETPS(sdat[7:0]) ipl <= sdat[10:8]; end
                3'd5: dt  <= sdat[7:0];
                3'd4: dpr <= sdat[15:0];
                3'd3: begin y[7:0]<=sdat[7:0]; if(!fx) y[15:8]<=sdat[15:8]; end
                3'd2: begin x[7:0]<=sdat[7:0]; if(!fx) x[15:8]<=sdat[15:8]; end
                3'd1: begin b[7:0]<=sdat[7:0]; if(!fm) b[15:8]<=sdat[15:8]; end
                default: begin a[7:0]<=sdat[7:0]; if(!fm) a[15:8]<=sdat[15:8]; end
            endcase
        end
        //////////////////////////////////////////////////////////// interrupts
        INTR1: push( pc, 2'd2, INTR2 );
        INTR2: push( {5'd0,ipl,ps}, 2'd2, INTR3 ); // ipl then ps
        INTR3: begin
            fi <= 1;
            if( int_msk ) ipl <= int_lvl;
            pg <= 0;
            req( {8'd0,vec}, 1'b1, 1'b0, 16'd0, VECR );
        end
        VECR: if( back ) begin
            breq <= 0;
            pc   <= bdin;
            st   <= FETCH;
        end
        WAIS: if( take_irq ) begin
            irq_ack   <= 1;
            irq_ackix <= irq_ix;
            vec       <= 16'hffce + {10'd0,irq_ix,1'b0};
            int_msk   <= 1;
            int_lvl   <= irq_lvl;
            push( {8'd0,pg}, 2'd1, INTR1 );
        end
        STPS:; // frozen until reset
        //////////////////////////////////////////////////////////// MVN/MVP
        MVCK: begin
            if( a==0 ) st <= FETCH;
            else req( {mvsrc,xv}, 1'b0, 1'b0, 16'd0, MVRD );
        end
        MVRD: if( back ) begin
            breq <= 0;
            req( {mvdst,yv}, 1'b0, 1'b1, {8'd0,bdin[7:0]}, MVWR );
        end
        MVWR: if( back ) begin
            breq <= 0;
            st   <= MVUP;
        end
        MVUP: begin
            if( cls==C_MVN ) begin
                x[7:0] <= x[7:0]+8'd1;
                y[7:0] <= y[7:0]+8'd1;
                if( !fx ) begin x <= x+16'd1; y <= y+16'd1; end
            end else begin
                x[7:0] <= x[7:0]-8'd1;
                y[7:0] <= y[7:0]-8'd1;
                if( !fx ) begin x <= x-16'd1; y <= y-16'd1; end
            end
            if( a==16'd1 ) begin
                a <= 16'hffff;
            end else begin
                a  <= a - 16'd1;
                pc <= pc - 16'd3; // re-execute, keeps IRQs serviceable
            end
            st <= FETCH;
        end
        //////////////////////////////////////////////////////////// divider
        DIV0: begin // {B,A} / opnd, restoring division
            dvd  <= wide ? {b,a} : {16'd0,b[7:0],a[7:0]};
            dvs  <= opm;
            quo  <= 0;
            rem  <= 0;
            dcnt <= 6'd32;
            st   <= opm==0 ? EXEC : DIVL; // trap below via DIVE path
            if( opm==0 ) begin
                vec     <= 16'hfffc;      // zero division vector
                int_msk <= 0;
                push( {8'd0,pg}, 2'd1, INTR1 );
            end
        end
        DIVL: begin
            rem_nx = {rem[15:0],dvd[31]};
            dvd    <= {dvd[30:0],1'b0};
            if( rem_nx >= {1'b0,dvs} ) begin
                rem <= rem_nx - {1'b0,dvs};
                quo <= {quo[30:0],1'b1};
            end else begin
                rem <= rem_nx;
                quo <= {quo[30:0],1'b0};
            end
            dcnt <= dcnt - 6'd1;
            if( dcnt==6'd1 ) st <= DIVE;
        end
        DIVE: begin
            st <= FETCH;
            fv <= wide ? |quo[31:16] : |quo[15:8];
            fc <= wide ? |quo[31:16] : |quo[15:8];
            if( !(wide ? |quo[31:16] : |quo[15:8]) )
                fn <= wide ? quo[15] : quo[7];
            fz <= (wide ? quo[15:0] : {8'd0,quo[7:0]})==0;
            a[7:0] <= quo[7:0];
            b[7:0] <= rem[7:0];
            if( wide ) begin
                a[15:8] <= quo[15:8];
                b[15:8] <= rem[15:8];
            end
        end
        default: st <= FETCH;
        endcase
    end
end

`ifdef SYSFL_COINDBG
reg  [95:0] ring[0:4095];
integer rix=0, rdone=0, k;
always @(posedge clk) if( !rst && cen && st==FETCH && breq && back && pfx==0 && rdone==0 ) begin
    ring[rix%4096] <= {dpr, pg, pc, bdin[7:0], a, x, s};
    rix <= rix+1;
    if( pg==0 && pc>=16'hef0f && pc<16'hffce ) begin
        rdone <= 1;
        $display("BRKTRACE first BRK at %h:%h after %0d instructions", pg, pc, rix);
        for( k=(rix>4000?rix-4000:0); k<rix; k=k+1 )
            $display("BRKTRACE %h:%h op %h A=%h X=%h S=%h D=%h", ring[k%4096][79:72], ring[k%4096][71:56],
                ring[k%4096][55:48], ring[k%4096][47:32], ring[k%4096][31:16], ring[k%4096][15:0], ring[k%4096][95:80]);
    end
end
integer dbgc_clk=0;
always @(posedge clk) begin
    dbgc_clk <= dbgc_clk+1;
    if( dbgc_clk%403200==0 && dbgc_clk<40*806400 )
        $display("CPU pc %h:%h fi %b ipl %0d st %0d irq_rq %b lvl %0d s %h f%0d", pg, pc, fi, ipl, st, irq_rq, irq_lvl, s, dbgc_clk/806400);
end
`endif

endmodule
