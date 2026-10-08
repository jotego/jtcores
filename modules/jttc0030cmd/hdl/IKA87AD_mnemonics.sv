package IKA87AD_mnemonics;

localparam MA = 2'd3;
localparam SP = 2'd2;
localparam PC = 2'd0;


///////////////////////////////////////////////////////////
//////  BUS CYCLE TYPES
////

localparam IDLE = 2'b00;
localparam RD4 = 2'b01;
localparam RD3 = 2'b10;
localparam WR3 = 2'b11;



///////////////////////////////////////////////////////////
//////  MICROCODE TYPES
////

localparam MCTYPE0 = 2'd0;
localparam MCTYPE1 = 2'd1;
localparam MCTYPE2 = 2'd2;
localparam MCTYPE3 = 2'd3;



///////////////////////////////////////////////////////////
//////  GPR READ BUS TYPES
////

localparam GPRBUS_xV_b = 5'b00000;
localparam GPRBUS_xA_b = 5'b00001;
localparam GPRBUS_VA_w = 5'b00010;
localparam GPRBUS_xB_b = 5'b00100;
localparam GPRBUS_xC_b = 5'b00101;
localparam GPRBUS_BC_w = 5'b00110;
localparam GPRBUS_xD_b = 5'b01000;
localparam GPRBUS_xE_b = 5'b01001;
localparam GPRBUS_DE_w = 5'b01010;
localparam GPRBUS_xH_b = 5'b01100;
localparam GPRBUS_xL_b = 5'b01101;
localparam GPRBUS_HL_w = 5'b01110;
localparam GPRBUS_EH_b = 5'b10000;
localparam GPRBUS_EL_b = 5'b10001;
localparam GPRBUS_EA_w = 5'b10010;
localparam GPRBUS_SP_w = 5'b11010;



///////////////////////////////////////////////////////////
//////  MICROCODE TYPE 0 FIELDS
////

localparam T0_SRC_R         = 4'b0000;
localparam T0_SRC_R2        = 4'b0001;
localparam T0_SRC_R1        = 4'b0010;
localparam T0_SRC_RP2       = 4'b0011;
localparam T0_SRC_RP        = 4'b0100;
localparam T0_SRC_RP1       = 4'b0101;
localparam T0_SRC_SRTMP     = 4'b0110;
localparam T0_SRC_PSW       = 4'b0111;
localparam T0_SRC_MD        = 4'b1000;
localparam T0_SRC_MD0       = 4'b1001;
localparam T0_SRC_DAUX       = 4'b1011;
localparam T0_SRC_A         = 4'b1100;
localparam T0_SRC_EA        = 4'b1110;
localparam T0_SRC_IGNORE    = 4'b1110;
/* -------------------------------- */
localparam T0_DST_R         = 4'b0000;
localparam T0_DST_R2        = 4'b0001;
localparam T0_DST_R1        = 4'b0010;
localparam T0_DST_RP2       = 4'b0011;
localparam T0_DST_RP        = 4'b0100;
localparam T0_DST_RP1       = 4'b0101;
localparam T0_DST_SRTMP     = 4'b0110;
localparam T0_DST_PSW       = 4'b0111;
localparam T0_DST_MD        = 4'b1000;
localparam T0_DST_MD0       = 4'b1001;
localparam T0_DST_MD1       = 4'b1010;
localparam T0_DST_MDR       = 4'b1011; //MD, byte-reversed(word store to ascending addresses)
localparam T0_DST_A         = 4'b1100;
localparam T0_DST_C         = 4'b1101;
localparam T0_DST_EA        = 4'b1110;
localparam T0_DST_BC        = 4'b1111;
/* -------------------------------- */
localparam T0_DEU_MOV       = 4'b0000;
localparam T0_DEU_NEG       = 4'b0001;
localparam T0_DEU_INC       = 4'b0010;
localparam T0_DEU_DEC       = 4'b0011;
localparam T0_DEU_ROT       = 4'b0100;
localparam T0_DEU_SHFT      = 4'b0101;
localparam T0_DEU_DAA       = 4'b0110; //011?
localparam T0_DEU_MUL       = 4'b1000; //100?
localparam T0_DEU_DIV       = 4'b1010; //101?
localparam T0_DEU_COMOP     = 4'b1100; //11??
/* -------------------------------- */
localparam DEU_OP_MOV       = 4'h0;
localparam DEU_OP_XOR       = 4'h1;
localparam DEU_OP_AND       = 4'h8;
localparam DEU_OP_OR        = 4'h9;
localparam DEU_OP_ADD       = 4'h4;
localparam DEU_OP_ADDWC     = 4'h5;
localparam DEU_OP_SUB       = 4'h6;
localparam DEU_OP_SUBWB     = 4'h7;
localparam DEU_OP_SK_ANDNZ  = 4'hC;
localparam DEU_OP_SK_ANDZ   = 4'hD;
localparam DEU_OP_SK_ADDNC  = 4'h2;
localparam DEU_OP_SK_SUBNB  = 4'h3;
localparam DEU_OP_SK_NE     = 4'hE;
localparam DEU_OP_SK_EQ     = 4'hF;
localparam DEU_OP_SK_GT     = 4'hA;
localparam DEU_OP_SK_LT     = 4'hB;



///////////////////////////////////////////////////////////
//////  MICROCODE TYPE 1 FIELDS
////

localparam T1_SRC_A_TA      = 4'b0000;
localparam T1_SRC_A_FA      = 4'b0001;
localparam T1_SRC_A_REL_S   = 4'b0010;
localparam T1_SRC_A_REL_L   = 4'b0011;
localparam T1_SRC_A_INT     = 4'b0100;
localparam T1_SRC_RPA_OFFSET= 4'b0101;
localparam T1_SRC_RPA       = 4'b0110;
localparam T1_SRC_RPA2      = 4'b0111;
localparam T1_SRC_AAUX      = 4'b1000;
localparam T1_SRC_IGNORE    = 4'b1001;
localparam T1_SRC_EA        = 4'b1010;
localparam T1_SRC_BC        = 4'b1011;
localparam T1_SRC_DE        = 4'b1100;
localparam T1_SRC_HL        = 4'b1101;
localparam T1_SRC_SP        = 4'b1110;
localparam T1_SRC_PC        = 4'b1111;
/* -------------------------------- */
localparam T1_DST_RPA       = 4'b0110;
localparam T1_DST_MD        = 4'b1001;
localparam T1_DST_MA        = 4'b1010;
localparam T1_DST_PC        = 4'b1111;
/* -------------------------------- */
localparam T1_AEU_ADD       = 4'b0000;
localparam T1_AEU_RPA_ADJ   = 4'b0001;
localparam T1_AEU_RPA3_ADJ  = 4'b0010;
localparam T1_AEU_PINC      = 4'b0011;
localparam T1_AEU_DINC      = 4'b0100;
localparam T1_AEU_POP       = 4'b0101;
localparam T1_AEU_PUSH      = 4'b0110;
localparam T1_AEU_DEC       = 4'b0111;
localparam T1_AEU_MOV       = 4'b1000;



///////////////////////////////////////////////////////////
//////  MICROCODE TYPE 2 COMMANDS
////

localparam T2_ATYPE_BYTE    = 3'b001;
localparam T2_ATYPE_WORD    = 3'b010;
localparam T2_ATYPE_IRO     = 3'b011;
localparam T2_ATYPE_SR      = 3'b100;
localparam T2_SKIP_BTST     = 3'b011;
localparam T2_SKIP_SK       = 3'b100;
localparam T2_SKIP_SKN      = 3'b101;
localparam T2_SKIP_SKIT     = 3'b110;
localparam T2_SKIP_SKNIT    = 3'b111;

                            // rsvd   atsel  cmod   irq   xchg  susp  skctrl
localparam T2_NOP           = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_BYTE      = {1'b0, 3'b001, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_WORD      = {1'b0, 3'b010, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_IRO       = {1'b0, 3'b011, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_SR        = {1'b0, 3'b100, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_SR2       = {1'b0, 3'b101, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_SR3       = {1'b0, 3'b110, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_STA_SR4       = {1'b0, 3'b111, 1'b0, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_CARRY_MOD     = {1'b0, 3'b000, 1'b1, 1'b0, 2'b00, 1'b0, 3'b000};
localparam T2_IRQ_MOD       = {1'b0, 3'b000, 1'b0, 1'b1, 2'b00, 1'b0, 3'b000};
localparam T2_XCHG_EXX      = {1'b0, 3'b000, 1'b0, 1'b0, 2'b01, 1'b0, 3'b000};
localparam T2_XCHG_EXA      = {1'b0, 3'b000, 1'b0, 1'b0, 2'b10, 1'b0, 3'b000};
localparam T2_XCHG_EXH      = {1'b0, 3'b000, 1'b0, 1'b0, 2'b11, 1'b0, 3'b000};
localparam T2_SUSP_EN       = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b1, 3'b000};
localparam T2_SK_BTST       = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b011};
localparam T2_SK_SK         = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b100};
localparam T2_SK_SKN        = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b101};
localparam T2_SK_SKIT       = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b110};
localparam T2_SK_SKNIT      = {1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 1'b0, 3'b111};



///////////////////////////////////////////////////////////
//////  MICROCODE TYPE 2 COMMANDS
////
                            // rsvd  ird   cpd   bralu
localparam T3_IRD           = {7'd0, 1'b1, 1'b0, 3'b000};
localparam T3_COND_PC_DEC   = {7'd0, 1'b0, 1'b1, 3'b000};
localparam T3_BRA_ON_ALU    = {7'd0, 1'b0, 1'b0};




///////////////////////////////////////////////////////////
//////  MICROCODE ROUTINE ENTRANCE ADDRESSES
////

//1-word segment group                  imp? s  cycles
localparam IRD              = 8'd000; // O | instruction read(similar to nop but cannot be skipped)
localparam NOP              = 8'd001; // O | 1,  4
localparam MOV_R1_A         = 8'd002; // O | 1,  4
localparam MOV_A_R1         = 8'd003; // O | 1,  4
localparam DMOV_RP_EA       = 8'd004; // O | 1,  4
localparam DMOV_EA_RP       = 8'd005; // O | 1,  4
localparam ROTSHFT_R2       = 8'd006; // O | 1, 44
localparam ROTSHFT_EA       = 8'd007; // O | 1, 44
localparam INR              = 8'd008; // O | 1,  4
localparam DCR              = 8'd009; // O | 1,  4
localparam DAA              = 8'd010; // O | 1,  4
localparam NEGA             = 8'd011; // O | 1, 44
localparam ALU_A_R          = 8'd012; // O | 1, 44
localparam ALU_R_A          = 8'd013; // O | 1, 44
localparam EXX              = 8'd014; // O | 1,  4
localparam EXA              = 8'd015; // O | 1,  4
localparam EXH              = 8'd016; // O | 1,  4
localparam SK               = 8'd017; // O | 1, 44
localparam SKN              = 8'd018; // O | 1, 44
localparam SKIT             = 8'd019; // O | 1, 44
localparam SKNIT            = 8'd020; // O | 1, 44
localparam EIDI             = 8'd021; // O | 1,  4
localparam SUSP             = 8'd022; // O | 1,  4+(44)
localparam STC_CLC          = 8'd023; // O | 1,  4
//2-word segment group
localparam MVI_R_IM         = 8'd024; // O | 2,  43
localparam LDAX_A_RPA       = 8'd026; // O | 2,  43
localparam STAX_RPA_A       = 8'd028; // O | 2,  43
localparam INX_RP2          = 8'd030; // O | 2,  43
localparam INX_EA           = 8'd032; // O | 2,  43
localparam DCX_RP2          = 8'd034; // O | 2,  43
localparam DCX_EA           = 8'd036; // O | 2,  43
localparam ALUX_A_RPA       = 8'd038; // O | 2, 443
localparam ALUI_A_IM        = 8'd040; // O | 2,  43
localparam ALUI_R_IM        = 8'd042; // O | 2, 443
localparam EALU_EA_R2       = 8'd044; // O | 2, 443
localparam DALU_EA_RP       = 8'd046; // O | 2, 443
localparam MUL              = 8'd048; // O | 2, 4433333333
localparam DIV              = 8'd050; // O | 2, 4433333333_33333333_3
//4-word segment group
localparam LXI_RP2_IM       = 8'd056; // O | 3,  433
localparam MVIX_RPA_IM      = 8'd060; // O | 3,  433
localparam LDAW             = 8'd064; // O | 3,  433
localparam STAW             = 8'd068; // O | 3,  433
localparam MOV_SR_A         = 8'd072; // O | 3, 433
localparam MOV_A_SR1        = 8'd076; // O | 3,  433
localparam DMOV_SR3_EA      = 8'd080; // O | 3, 4433
localparam DMOV_EA_SR4      = 8'd084; // O | 3, 4433
localparam ALUW_A_WA        = 8'd088; // O | 3, 4433
localparam BTST_WA          = 8'd092; // O | 3,  433
localparam JRE              = 8'd096; // O | 3,  433
localparam JEA              = 8'd099; // O |^1, 44
localparam JMP              = 8'd100; // O |V3,  433
localparam JB               = 8'd103; // O |^1,  4
localparam JR               = 8'd104; // O |V3,  433
localparam PUSH             = 8'd108; // O | 4,  4333
localparam POP              = 8'd112; // O | 3,  433
localparam MOV_MEM_R        = 8'd116; // O | 4, 44333
localparam MOV_R_MEM        = 8'd120; // O | 4, 44333
localparam MVIW_WA_IM       = 8'd124; // O | 4,  4333
localparam LDAX_A_RPA2      = 8'd128; // O | 4,  4333
localparam STAX_RPA2_A      = 8'd132; // O | 4,  4333
localparam RLD_RRD          = 8'd136; // O | 4, 44333
localparam CALB             = 8'd140; // O | 4, 44333
localparam CALF             = 8'd144; // O | 4,  4333
localparam RETI             = 8'd148; // O | 4,  4333
localparam BLOCK            = 8'd152; // O | 4,  4333
localparam TABLE            = 8'd156; // O | 4, 44333
//8-word segment group
localparam LD_RP2_MEM       = 8'd160; // O | 5, 443333, (LBCD, LDED, LHLD, LSPD)
localparam ST_MEM_RP2       = 8'd168; // O |^5, 443333, (SBCD, SDED, SHLD, SSPD)
localparam LDEAX_EA_RPA3    = 8'd176; // O |V3, 4433
localparam LDEAX_EA_RPA2    = 8'd179; // O |^5, 443333
localparam STEAX_RPA3_EA    = 8'd184; // O |V3, 4433
localparam STEAX_RPA2_EA    = 8'd187; // O | 5, 443333
localparam INRW             = 8'd192; // O | 5,  43333
localparam DCRW             = 8'd200; // O | 5,  43333
localparam CALL             = 8'd208; // O | 5,  43333
localparam CALT             = 8'd216; // O |^5,  43333
localparam RET_RETS         = 8'd221; // O |V3,  433
localparam SOFTI            = 8'd224; // O | 5,  43333
localparam HARDI            = 8'd232; // O | 5,  43333
//opcode with branch microcode
localparam ALUIW_WA_IM      = 8'd240; // O | 8
localparam ALUI_SR2_IM      = 8'd248; // O | 6

endpackage : IKA87AD_mnemonics
