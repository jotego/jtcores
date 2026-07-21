// IKA87AD — NEC uCOM-87AD (uPD78C11) microcontroller core.
// Copyright (c) 2023, Raki (Sehyeon Kim). Vendored verbatim from
// https://github.com/ika-musume/IKA87AD
//
// Licensed under the "Taito C-Chip Temporary License" (BSD-2 + clause 3).
// Full text: modules/jttc0030cmd/LICENSE.IKA87AD
//
// *** LICENSE CLAUSE 3 (live restriction) ***
// This code — even a snippet — MUST NOT be used to implement Taito's
// game "Rainbow Islands". Do NOT wire jttc0030cmd to the rbisland driver
// until Raki removes this clause. Superman / Operation Wolf / other Taito
// C-chip games are unaffected.
//
module IKA87AD_microcode (
    input   wire                i_CLK,
    input   wire                i_MCROM_READ_TICK,
    input   wire    [7:0]       i_MCROM_ADDR,
    output  wire    [17:0]      o_MCROM_DATA
);

import IKA87AD_mnemonics::*;

reg     [17:0]  mc;
assign  o_MCROM_DATA = mc;

always_ff @(posedge i_CLK) if(i_MCROM_READ_TICK) begin
    case(i_MCROM_ADDR)
        //                       MCTYPE   FLAG  SKIP
        /*
            8-bit data transfer instructions
        */
        MOV_R1_A        : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_A, T0_DST_R1, T0_DEU_MOV, RD4};            //r1<-A, RD4

        MOV_A_R1        : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_R1, T0_DST_A, T0_DEU_MOV, RD4};            //A<-r1, RD4

        MOV_SR_A+0      : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_SR, RD3};                                  //STA_ST, RD3
        MOV_SR_A+1      : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        MOV_SR_A+2      : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_A, T0_DST_SRTMP, T0_DEU_MOV, RD4};         //SRTMP<-A, RD4

        MOV_A_SR1+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_SR, RD3};                                  //STA_ST, RD3
        MOV_A_SR1+1     : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        MOV_A_SR1+2     : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_SRTMP, T0_DST_A, T0_DEU_MOV, RD4};         //A<-SRTMP, RD4

        MOV_R_MEM+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        MOV_R_MEM+1     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        MOV_R_MEM+2     : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-AAUX, RD3
        MOV_R_MEM+3     : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD0, T0_DST_R, T0_DEU_MOV, RD4};           //r<-MD0, RD4
        
        MOV_MEM_R+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        MOV_MEM_R+1     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        MOV_MEM_R+2     : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, WR3};         //MA<-AAUX, WR3
        MOV_MEM_R+3     : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_R, T0_DST_MD0, T0_DEU_MOV, RD4};           //MD0<-r, RD4

        MVI_R_IM        : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        MVI_R_IM+1      : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_MD, T0_DST_R, T0_DEU_MOV, RD4};            //R<-MD, RD4

        // * MVI_SR2_IM is included in ALUI_SR2_IM instruction

        MVIW_WA_IM+0    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        MVIW_WA_IM+1    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        MVIW_WA_IM+2    : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, WR3};         //MA<-Vwa, WR3
        MVIW_WA_IM+3    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        MVIX_RPA_IM+0   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        MVIX_RPA_IM+1   : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_MOV, WR3};          //MA<-RPA, WR3
        MVIX_RPA_IM+2   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        LDAW+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        LDAW+1          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3
        LDAW+2          : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD0, T0_DST_A, T0_DEU_MOV, RD4};           //A<-MD0, RD4

        STAW+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        STAW+1          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, WR3};         //MA<-Vwa, WR3
        STAW+2          : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_A, T0_DST_MD0, T0_DEU_MOV, RD4};           //MD0<-A, RD4

        LDAX_A_RPA      : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_RPA_ADJ, RD3};      //MA<-RPA, RD3
        LDAX_A_RPA+1    : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD0, T0_DST_A, T0_DEU_MOV, RD4};           //A<-MD0, RD4
        
        LDAX_A_RPA2     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_IRO, IDLE};                                //conditional read, IDLE
        LDAX_A_RPA2+1   : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA2, T1_DST_MA, T1_AEU_MOV, IDLE};        //MA<-RPA2, IDLE
        LDAX_A_RPA2+2   : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_RPA_OFFSET, T1_DST_MA, T1_AEU_ADD, RD3};   //MA<-MA+RPA2_OFFSET, RD3
        LDAX_A_RPA2+3   : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD0, T0_DST_A, T0_DEU_MOV, RD4};           //A<-MD0, RD4

        STAX_RPA_A      : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_RPA_ADJ, WR3};      //MA<-RPA, WR3
        STAX_RPA_A+1    : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_A, T0_DST_MD0, T0_DEU_MOV, RD4};           //MD0<-A, RD4

        STAX_RPA2_A     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_IRO, IDLE};                                //conditional read, IDLE
        STAX_RPA2_A+1   : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA2, T1_DST_MA, T1_AEU_MOV, IDLE};        //MA<-RPA2, IDLE
        STAX_RPA2_A+2   : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_RPA_OFFSET, T1_DST_MA, T1_AEU_ADD, WR3};   //MA<-MA+RPA2_OFFSET, WR3
        STAX_RPA2_A+3   : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_A, T0_DST_MD0, T0_DEU_MOV, RD4};           //MD0<-A, RD4

        EXX             : mc <= {MCTYPE2, 1'b0, 1'b1, T2_XCHG_EXX, RD4};                                //exx mod, RD4
        
        EXA             : mc <= {MCTYPE2, 1'b0, 1'b1, T2_XCHG_EXA, RD4};                                //exa mod, RD4
        
        EXH             : mc <= {MCTYPE2, 1'b0, 1'b1, T2_XCHG_EXH, RD4};                                //exh mod, RD4
        
        BLOCK+0         : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_HL, T1_DST_MA, T1_AEU_PINC, RD3};          //MA<-HL+, RD3
        BLOCK+1         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_DE, T1_DST_MA, T1_AEU_PINC, WR3};          //MA<-DE+, WR3
        BLOCK+2         : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_IGNORE, T0_DST_C, T0_DEU_DEC, IDLE};       //C<-C-1(dec), IDLE
        BLOCK+3         : mc <= {MCTYPE3, 1'b0, 1'b0, T3_COND_PC_DEC, RD4};                             //conditional PC decrement, RD4


        /*
            16-bit data transfer instructions
        */
        DMOV_RP_EA      : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_EA, T0_DST_RP, T0_DEU_MOV, RD4};           //rp<-EA, RD4
        
        DMOV_EA_RP      : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_RP, T0_DST_EA, T0_DEU_MOV, RD4};           //EA<-rp, RD4
        
        DMOV_SR3_EA+0   : mc <= {MCTYPE2, 1'b0, 1'b1, T2_STA_SR3, IDLE};                                //STSR3, IDLE
        DMOV_SR3_EA+1   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop, IDLE
        DMOV_SR3_EA+2   : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_EA, T0_DST_SRTMP, T0_DEU_MOV, RD4};        //SRTMP<-EA, RD4
        
        DMOV_EA_SR4+0   : mc <= {MCTYPE2, 1'b0, 1'b1, T2_STA_SR4, IDLE};                                //STSR4, IDLE
        DMOV_EA_SR4+1   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop(read delay), IDLE
        DMOV_EA_SR4+2   : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_SRTMP, T0_DST_EA, T0_DEU_MOV, RD4};        //EA<-sr4, RD4
        
        LXI_RP2_IM+0    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LXI_RP2_IM+1    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LXI_RP2_IM+2    : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_MD, T0_DST_RP2, T0_DEU_MOV, RD4};          //rp2<-MD, RD4
        
        LD_RP2_MEM+0    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LD_RP2_MEM+1    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        LD_RP2_MEM+2    : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-ADDR_IA, RD3
        LD_RP2_MEM+3    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LD_RP2_MEM+4    : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD, T0_DST_RP2, T0_DEU_MOV, RD4};          //rp2<-MD, RD4
        
        ST_MEM_RP2+0    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        ST_MEM_RP2+1    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        ST_MEM_RP2+2    : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, WR3};         //MA<-ADDR_IA, WR3

        ST_MEM_RP2+3    : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_RP2, T0_DST_MDR, T0_DEU_MOV, WR3};         //MD<-rp2(reversed), WR3
        ST_MEM_RP2+4    : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4
        
        LDEAX_EA_RPA3+0 : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_RPA3_ADJ, RD3};     //MA<-adj RPA3, RD3
        LDEAX_EA_RPA3+1 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LDEAX_EA_RPA3+2 : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD, T0_DST_EA, T0_DEU_MOV, RD4};           //EA<-MD, RD4

        LDEAX_EA_RPA2+0 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_IRO, IDLE};                                //STIRO(conditional), IDLE
        LDEAX_EA_RPA2+1 : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA2, T1_DST_MA, T1_AEU_MOV, IDLE};        //MA<-RPA2, IDLE
        LDEAX_EA_RPA2+2 : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_RPA_OFFSET, T1_DST_MA, T1_AEU_ADD, RD3};   //MA<-MA+RPA_OFFSET, RD3
        LDEAX_EA_RPA2+3 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        LDEAX_EA_RPA2+4 : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD, T0_DST_EA, T0_DEU_MOV, RD4};           //EA<-MD, RD4

        STEAX_RPA3_EA+0 : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_RPA3_ADJ, WR3};     //MA<-adj RPA3, WR3
        STEAX_RPA3_EA+1 : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_EA, T0_DST_MDR, T0_DEU_MOV, WR3};          //MD<-EA(reversed), WR3
        STEAX_RPA3_EA+2 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        STEAX_RPA2_EA+0 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_IRO, IDLE};                                //STIRO(conditional), IDLE
        STEAX_RPA2_EA+1 : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA2, T1_DST_MA, T1_AEU_MOV, IDLE};        //MA<-RPA2, IDLE
        STEAX_RPA2_EA+2 : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_RPA_OFFSET, T1_DST_MA, T1_AEU_ADD, WR3};   //MA<-MA+RPA_OFFSET, WR3
        STEAX_RPA2_EA+3 : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_EA, T0_DST_MDR, T0_DEU_MOV, WR3};          //MD<-EA(reversed), WR3
        STEAX_RPA2_EA+4 : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        PUSH+0          : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_RP1, T0_DST_MD, T0_DEU_MOV, IDLE};         //MD<-rp1, IDLE
        PUSH+1          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        PUSH+2          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, WR3};                                     //nop, WR3
        PUSH+3          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        POP+0           : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_SP, T1_DST_MA, T1_AEU_POP, RD3};           //MA<-pop SP, RD3
        POP+1           : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        POP+2           : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD, T0_DST_RP1, T0_DEU_MOV, RD4};          //rp1<-MD, RD4

        TABLE+0         : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA_OFFSET, T1_DST_MA, T1_AEU_ADD, IDLE};  //MA<-MA+A(rpa offset A, opcode[1:0]==00), IDLE
        TABLE+1         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_IGNORE, T1_DST_MA, T1_AEU_DINC, RD3};      //MA<-MA+2, IDLE
        TABLE+2         : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        TABLE+3         : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD, T0_DST_BC, T0_DEU_MOV, RD4};           //BC<-MD, RD4
        
        /*
            8-bit register-accumulator arithmetic instructions
            (add, adc, addnc, sub, subnc, ana, ora, xra, gta, lta, nea, eqa, ona, offa)
        */
        ALU_A_R         : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_R, T0_DST_A, T0_DEU_COMOP, RD4};           //A<-A(op)R, RD4
        
        ALU_R_A         : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_A, T0_DST_R, T0_DEU_COMOP, RD4};           //R<-R(op)A, RD4

        /*
            8-bit memory-accumulator arithmetic instructions
            (addx, adcx, addncx, subx, sbbx, subncx, anax, orax, xrax, gtax, ltax, neax, eqax, onax, offax)
        */
        ALUX_A_RPA+0    : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_RPA, T1_DST_MA, T1_AEU_RPA_ADJ, RD3};      //MA<-adj RPA, RD3
        ALUX_A_RPA+1    : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_A, T0_DEU_COMOP, RD4};         //A<-A(op)MD0, RD4
        
        /*
            8-bit immediate-register arithmetic instructions
            (mvi, adi, aci, adinc, sui, sbi, suinb, ani, ori, xri, gti, lti, nei, eqi, oni, offi)
        */
        ALUI_A_IM+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        ALUI_A_IM+1     : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_MD0, T0_DST_A, T0_DEU_COMOP, RD4};         //A<-A (op) MD

        ALUI_R_IM+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        ALUI_R_IM+1     : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_MD0, T0_DST_R, T0_DEU_COMOP, RD4};         //R<-R (op) MD

        ALUI_SR2_IM+0   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_SR2, RD3};                                 //STSR2, RD3
        ALUI_SR2_IM+1   : mc <= {MCTYPE3, 1'b0, 1'b1, T3_BRA_ON_ALU, 3'd3, IDLE};                       //branch+4, IDLE
        ALUI_SR2_IM+2   : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_SRTMP, T0_DEU_COMOP, IDLE};    //SR2<-SR2(op)MD, IDLE
        ALUI_SR2_IM+3   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop(sr write delay), IDLE
        ALUI_SR2_IM+4   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4
        ALUI_SR2_IM+5   : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_SRTMP, T0_DEU_COMOP, RD4};     //SR2<-SR2(op)MD, RD4

        /*
            8-bit working register arithmetic instructions
            (aniw, oriw(19 cyc) / gti, lti, oni, offi, eqi, nei(13 cyc))
        */
        ALUW_A_WA+0     : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3(Vwa)
        ALUW_A_WA+1     : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3(Vwa data)
        ALUW_A_WA+2     : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_A, T0_DEU_COMOP, RD4};         //A<-A(op)MD0, RD4

        ALUIW_WA_IM+0   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3(Vwa)
        ALUIW_WA_IM+1   : mc <= {MCTYPE3, 1'b0, 1'b0, T3_BRA_ON_ALU, 3'd4, RD3};                        //branch+5, RD3(im)
        ALUIW_WA_IM+2   : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3(Vwa data)
        ALUIW_WA_IM+3   : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_MD1, T0_DEU_COMOP, IDLE};      //MD1<-MD1(op)MD0, IDLE
        ALUIW_WA_IM+4   : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_IGNORE, T1_DST_MA, T1_AEU_DEC, WR3};       //MA<-MA-1, WR3
        ALUIW_WA_IM+5   : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4
        ALUIW_WA_IM+6   : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3(Vwa data)
        ALUIW_WA_IM+7   : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_MD1, T0_DEU_COMOP, RD4};       //MD1<-MD1(op)MD0, RD4

        /*
            16-bit register-accumulator arithmetic instructions
            (eadd, esub / dadd, dadc, daddnc, dsub, dsbb, dsubnb, dan, dor, dxr, dgt, dlt, dne, deq, don, doff)
        */
        EALU_EA_R2+0    : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        EALU_EA_R2+1    : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_R2, T0_DST_EA, T0_DEU_COMOP, RD4};         //EA<-EA (op) R2, RD4

        DALU_EA_RP+0    : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        DALU_EA_RP+1    : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_RP, T0_DST_EA, T0_DEU_COMOP, RD4};         //EA<-EA (op) RP, RD4

        /*
            Multiplication/division instructions
        */
        MUL+0           : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_R2, T0_DST_EA, T0_DEU_MUL, IDLE};          //EA<-A*r2, IDLE
        MUL+1           : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        DIV+0           : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_R2, T0_DST_EA, T0_DEU_DIV, IDLE};          //EA<-EA/r2, IDLE
        DIV+1           : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_DAUX, T0_DST_R2, T0_DEU_MOV, RD4};         //r2<-AUX, RD4

        /*
            Increment/decrement instructions
        */
        INR             : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_R2, T0_DST_R2, T0_DEU_INC, RD4};           //r2<-r2+1, IDLE

        INRW+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        INRW+1          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3
        INRW+2          : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_MD0, T0_DEU_INC, IDLE};        //MD0<-MD0+1, IDLE
        INRW+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_IGNORE, T1_DST_MA, T1_AEU_DEC, WR3};       //MA<-MA-1, WR3
        INRW+4          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        INX_RP2+0       : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_RP2, T0_DST_RP2, T0_DEU_INC, IDLE};        //rp2<-rp2+1, IDLE
        INX_RP2+1       : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        INX_EA+0        : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_EA, T0_DST_EA, T0_DEU_INC, IDLE};          //EA<-EA+1, IDLE
        INX_EA+1        : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        DCR             : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_R2, T0_DST_R2, T0_DEU_DEC, RD4};           //r2<-r2-1, IDLE

        DCRW+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        DCRW+1          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3
        DCRW+2          : mc <= {MCTYPE0, 1'b1, 1'b0, T0_SRC_MD0, T0_DST_MD0, T0_DEU_DEC, IDLE};        //MD0<-MD0-1, IDLE
        DCRW+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_IGNORE, T1_DST_MA, T1_AEU_DEC, WR3};       //MA<-MA-1, WR3
        DCRW+4          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        DCX_RP2+0       : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_RP2, T0_DST_RP2, T0_DEU_DEC, IDLE};        //rp2<-rp2-1, IDLE
        DCX_RP2+1       : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4

        DCX_EA+0        : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_EA, T0_DST_EA, T0_DEU_DEC, IDLE};          //EA<-EA-1, IDLE
        DCX_EA+1        : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};                                     //nop, RD4
        

        /*
            Shift/rotation instructions
        */
        ROTSHFT_R2      : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_R2, T0_DST_R2, T0_DEU_SHFT, RD4};          //byte rot/shft, RD4

        ROTSHFT_EA      : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_EA, T0_DST_EA, T0_DEU_SHFT, RD4};          //word rot/shft, RD4

        RLD_RRD+0       : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_HL, T1_DST_MA, T1_AEU_MOV, RD3};           //MA<-HL, RD3
        RLD_RRD+1       : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_A, T0_DST_MD0, T0_DEU_ROT, IDLE};          //(TEMP, MD0)<-(A, MD0), IDLE
        RLD_RRD+2       : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_IGNORE, T1_DST_MA, T1_AEU_DEC, WR3};       //MA<-MA-1, WR3
        RLD_RRD+3       : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_DAUX, T0_DST_A, T0_DEU_MOV, RD4};          //A<-DAUX, RD4

        /*
            Misc arithmetic instructions
        */
        DAA             : mc <= {MCTYPE0, 1'b1, 1'b1, T0_SRC_A, T0_DST_A, T0_DEU_DAA, RD4};             //A<-daa A, IDLE

        NEGA            : mc <= {MCTYPE0, 1'b0, 1'b1, T0_SRC_A, T0_DST_A, T0_DEU_NEG, RD4};             //A<-negative A, RD4

        STC_CLC         : mc <= {MCTYPE2, 1'b1, 1'b1, T2_CARRY_MOD, RD4};                               //carry mod

        /*
            Jump/call/return instructions
        */
        JMP+0           : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        JMP+1           : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        JMP+2           : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_PC, T1_AEU_MOV, RD4};         //PC<-AAUX, RD4

        JB              : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_BC, T1_DST_PC, T1_AEU_MOV, RD4};           //PC<-BC, RD4

        JR+0            : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        JR+1            : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop, IDLE
        JR+2            : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_A_REL_S, T1_DST_PC, T1_AEU_ADD, RD4};      //PC<-PC+jdisp1(short), RD4

        JRE+0           : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STA_BYTE, RD3
        JRE+1           : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        JRE+2           : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_A_REL_L, T1_DST_PC, T1_AEU_ADD, RD4};      //PC<-PC+jdisp(long), RD4

        JEA             : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_EA, T1_DST_PC, T1_AEU_MOV, RD4};           //PC<-EA, RD4

        CALL+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD3};                                     //nop, RD3
        CALL+1          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        CALL+2          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        CALL+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        CALL+4          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_AAUX, T1_DST_PC, T1_AEU_MOV, RD4};         //PC<-AAUX, RD4

        CALB+0          : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, IDLE};                                    //nop, IDLE
        CALB+1          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        CALB+2          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        CALB+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_BC, T1_DST_PC, T1_AEU_MOV, RD4};           //PC<-BC, RD4

        CALF+0          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STA_BYTE, RD3
        CALF+1          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        CALF+2          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        CALF+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_A_FA, T1_DST_PC, T1_AEU_MOV, RD4};         //PC<-ADDR_FA, RD4
    
        CALT+0          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_A_TA, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-ADDR_TA, RD3
        CALT+1          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        CALT+2          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        CALT+3          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        CALT+4          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_AAUX, T1_DST_PC, T1_AEU_MOV, RD4};         //PC<-AAUX, RD4

        RET_RETS+0      : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_SP, T1_DST_MA, T1_AEU_POP, RD3};           //MA<-pop SP, RD3
        RET_RETS+1      : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        RET_RETS+2      : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_AAUX, T1_DST_PC, T1_AEU_MOV, RD4};         //PC<-AAUX, RD4

        RETI+0          : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_SP, T1_DST_MA, T1_AEU_POP, RD3};           //MA<-pop SP, RD3
        RETI+1          : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_WORD, RD3};                                //STA_WORD, RD3
        RETI+2          : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_AAUX, T1_DST_PC, T1_AEU_MOV, RD3};         //PC<-AAUX, RD3
        RETI+3          : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_MD0, T0_DST_PSW, T0_DEU_MOV, RD4};         //PSW<-MD0, RD4

        SOFTI+0         : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop, IDLE
        SOFTI+1         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        SOFTI+2         : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_PSW, T0_DST_MD0, T0_DEU_MOV, WR3};         //MD0<-PSW, WR3
        SOFTI+3         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        SOFTI+4         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_A_INT, T1_DST_PC, T1_AEU_MOV, RD4};        //PC<-0060, RD4

        HARDI+0         : mc <= {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};                                    //nop, IDLE
        HARDI+1         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_SP, T1_DST_MA, T1_AEU_PUSH, WR3};          //MA<-push SP, WR3
        HARDI+2         : mc <= {MCTYPE0, 1'b0, 1'b0, T0_SRC_PSW, T0_DST_MD0, T0_DEU_MOV, WR3};         //MD0<-PSW, WR3
        HARDI+3         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_PC, T1_DST_MD, T1_AEU_MOV, WR3};           //MD<-PC, WR3
        HARDI+4         : mc <= {MCTYPE1, 1'b0, 1'b0, T1_SRC_A_INT, T1_DST_PC, T1_AEU_MOV, RD4};        //PC<-0060, RD4

        /*
            SKIP instructions
        */
        BTST_WA+0       : mc <= {MCTYPE2, 1'b0, 1'b0, T2_STA_BYTE, RD3};                                //STBYTE, RD3
        BTST_WA+1       : mc <= {MCTYPE1, 1'b0, 1'b1, T1_SRC_AAUX, T1_DST_MA, T1_AEU_MOV, RD3};         //MA<-Vwa, RD3
        BTST_WA+2       : mc <= {MCTYPE2, 1'b1, 1'b0, T2_SK_BTST, RD4};                                 //skip if a bit is high

        SK              : mc <= {MCTYPE2, 1'b1, 1'b1, T2_SK_SK, RD4};                                   //skip if flag
        
        SKN             : mc <= {MCTYPE2, 1'b1, 1'b1, T2_SK_SKN, RD4};                                  //skip if no flag
        
        SKIT            : mc <= {MCTYPE2, 1'b1, 1'b1, T2_SK_SKIT, RD4};                                 //skip if interrupt
        
        SKNIT           : mc <= {MCTYPE2, 1'b1, 1'b1, T2_SK_SKNIT, RD4};                                //skip if no interrupt

        /*
            Processor control instructions
        */
        EIDI            : mc <= {MCTYPE2, 1'b0, 1'b1, T2_IRQ_MOD, RD4};                                 //irq enable/disable, RD3
        
        SUSP            : mc <= {MCTYPE2, 1'b0, 1'b1, T2_SUSP_EN, RD4};                                 //set suspension flag, IDLE
        
        NOP             : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, RD4};                                     //nop, RD4
        
        IRD             : mc <= {MCTYPE3, 1'b0, 1'b0, T3_IRD, RD4};                                     //wait for decoding
        
        default         : mc <= {MCTYPE2, 1'b0, 1'b1, T2_NOP, RD4};                                     //nop, RD4
    endcase
end

endmodule