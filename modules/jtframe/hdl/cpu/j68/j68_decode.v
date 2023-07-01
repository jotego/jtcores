// Copyright 2011-2018 Frederic Requin
//
// This file is part of the MCC216 project
//
// The J68 core:
// -------------
// Simple re-implementation of the MC68000 CPU
// The core has the following characteristics:
//  - Tested on a Cyclone III (90 MHz) and a Stratix II (180 MHz)
//  - from 1500 (~70 MHz) to 1900 LEs (~90 MHz) on Cyclone III
//  - 2048 x 20-bit microcode ROM
//  - 256 x 28-bit decode ROM
//  - 2 x block RAM for the data and instruction stacks
//  - stack based CPU with forth-like microcode
//  - not cycle-exact : needs a frequency ~3 x higher
//  - all 68000 instructions are implemented
//  - almost all 68000 exceptions are implemented (only bus error missing)
//  - only auto-vector interrupts supported

module j68_decode
(
    input             rst,
    input             clk,
    input             clk_ena,
    input             ins_rdy,
    input      [15:0] instr,
    input             ext_rdy,
    input      [15:0] ext_wd,
    input             imm_rdy,
    input      [15:0] imm_wd,
    input             user_mode,
    input      [3:0]  ccr_in,
    output     [11:0] dec_jmp,
    output     [3:0]  ea1_jmp,
    output     [3:0]  ea2_jmp,
    output reg [15:0] imm_val,
    output     [15:0] ea1_bit,
    output reg        cc_jmp,
    output            ext_inst,
    output            bit_inst,
    output            vld_inst
);
    parameter USE_CLK_ENA = 0;
    
    // Trap routines addresses
    localparam [11:0] OP_PRIVILEDGED = (USE_CLK_ENA) ? 12'h038 : 12'h039;
    localparam [11:0] OP_ILLEGAL     = (USE_CLK_ENA) ? 12'h03A : 12'h03B;
  
    // $FE00 - $FEFF : Instruction decoder jump table
    // $FF00 - $FF1F : Empty
    // $FF20 - $FF2F : EA1 read BYTE jump table
    // $FF30 - $FF3F : EA1 read WORD jump table
    // $FF40 - $FF4F : EA1 read LONG jump table
    // $FF50 - $FF5F : EA1 calculation jump table
    // $FF60 - $FF6F : EA1 write BYTE jump table
    // $FF70 - $FF7F : EA1 write WORD jump table
    // $FF80 - $FF8F : EA1 write LONG jump table
    // $FF90 - $FF9F : EA2 write BYTE jump table
    // $FFA0 - $FFAF : EA2 write WORD jump table
    // $FFB0 - $FFBF : EA2 write LONG jump table
    // $FFC0 - $FFCF : Bit masks
    // $FFD0 - $FFD5 : Empty
    // $FFD6 - $FFD7 : VBR
    // $FFD8 - $FFD9 : TMP1
    // $FFDA - $FFDB : TMP2
    // $FFDC - $FFDD : USP
    // $FFDE - $FFDF : SSP
    // $FFE0 - $FFEF : Data registers (D0 - D7)
    // $FFF0 - $FFFF : Address registers (A0 - A7)


    // +---------------------+-------+----------------+------------------+
    // |        Index        |       |                |                  |
    // | Decimal  |  Binary  | Group | Description    | Op-code          |
    // +----------+----------+-------+----------------+------------------+
    // |   0..63  | 00xxxxxx |   4   | miscellaneous  | 0100111001xxxxxx |
    // |  64..95  | 010xxxxx |   0   | immediate      | 0000xxx0xx------ |
    // |  96..127 | 011xxxxx |   4   | one operand    | 0100xxx0xx------ |
    // | 128..143 | 1000xxxx |   E   | shift byte reg | 1110---x00xxx--- |
    // | 144..159 | 1001xxxx |   E   | shift word reg | 1110---x01xxx--- |
    // | 160..175 | 1010xxxx |   E   | shift long reg | 1110---x10xxx--- |
    // |    177   | 10110001 |   1   | MOVE.B         | 0001------------ |
    // |    178   | 10110010 |   2   | MOVE.L         | 0010------------ |
    // |    179   | 10110011 |   3   | MOVE.W         | 0011------------ |
    // |    182   | 10110110 |   6   | Bcc            | 0110------------ |
    // |    183   | 10110111 |   7   | MOVEQ          | 0111------------ |
    // |    186   | 10111010 |   A   | Line A         | 1010------------ |
    // |    191   | 10111111 |   F   | Line F         | 1111------------ |
    // | 192..199 | 11000xxx |   8   | OR/DIVx        | 1000---xxx------ |
    // | 200..207 | 11001xxx |   9   | SUB            | 1001---xxx------ |
    // | 208..215 | 11010xxx |   5   | ADDQ/SUBQ      | 0101---xxx------ |
    // | 216..223 | 11011xxx |   B   | CMP/EOR        | 1011---xxx------ |
    // | 224..231 | 11100xxx |   C   | AND/MULx       | 1100---xxx------ |
    // | 232..239 | 11101xxx |   D   | ADD            | 1101---xxx------ |
    // | 240..247 | 11110xxx |   E   | shift memory   | 1110---011xxx--- |
    // | 248..251 | 111110xx |   0   | bit operation  | 0000---1xx------ |
    // | 252..255 | 111111xx |   4   | two operands   | 0100---1xx------ |
    // +----------+----------+-------+----------------+------------------+
  
    // Instructions groups
    wire [15:0] w_grp_p0;
    
    // Effective address bitfields
    wire [15:0] w_ea1b_p0;      // EA #1
    reg  [15:0] r_ea1b_p1;
    wire [9:0]  w_ea2b_p0;      // EA #2 
    
    // Jump table indexes
    wire [3:0]  w_ea1_jmp_p0;   // EA #1
    reg  [3:0]  r_ea1_jmp_p1;
    //reg  [3:0]  r_ea1_jmp_p2;
    wire [3:0]  w_ea2_jmp_p0;   // EA #2
    reg  [3:0]  r_ea2_jmp_p1;
    //reg  [3:0]  r_ea2_jmp_p2;
    
    // Instructions sub-groups
    wire        w_g0_immed_p0;
    wire        w_g0_bitimm_p0;
    wire        w_g0_bitop_p0;
    wire        w_g4_misc_p0;
    wire        w_g4_oneop_p0;
    wire        w_g4_twoop_p0;
    wire        w_g5_addsub_p0;
    wire        w_g6_bsr_p0;
    wire        w_gE_shmem_p0;
    wire        w_gE_shreg_p0;
    
    // NEGX, ADDX, SUBX, NBCD, ABCD, SBCD
    wire        w_g4_nbcd_p0;
    wire        w_g8_sbcd_p0;
    wire        w_gC_abcd_p0;
    wire        w_g4_negx_p0;
    wire        w_g9_subx_p0;
    wire        w_gD_addx_p0;
    
    // Pre-decode
    wire        w_ill_ins_p0;   // Illegal instruction
    reg         r_ill_ins_p1;
    wire        w_prv_ins_p0;   // Priviledged instruction
    reg         r_prv_ins_p1;
    wire        w_ext_ins_p0;   // Special Z flag treatment
    reg         r_ext_ins_p1;
    //reg         r_ext_ins_p2;
    wire        w_bit_ins_p0;   // Bit manipulation instructions
    reg         r_bit_ins_p1;
    //reg         r_bit_ins_p2;
    reg         w_vld_ins_p1;   // Valid instruction
    reg         r_vld_ins_p2;
    
    // Call address
    wire        w_call1_ena_p0; // Jump table call #1 enable
    wire        w_call2_ena_p0; // Jump table call #2 enable
    reg  [1:0]  r_call_en_p1;
    reg  [11:0] r_call_p2;
    
    // Indexes
    wire [5:0]  w_idx6_5_0_p0;  // 5..0
    wire [5:0]  w_idx5_B_6_p0;  // 11..9, 7..6
    wire [5:0]  w_idx4_8_3_p0;  // 8, 5..3
    wire [5:0]  w_idx4_F_C_p0;  // 15..12
    wire [5:0]  w_idx3_8_6_p0;  // 8..6
    wire [5:0]  w_idx3_A_8_p0;  // 10..8
    wire [5:0]  w_idx2_7_6_p0;  // 7..6
    
    // Decoder ROM
    wire [7:0]  w_addr_p0;      // Decoder ROM address
    wire [35:0] w_data_p1;      // Decoder ROM data
    reg  [15:0] w_ea1m_p1;      // Effective address #1 mask
    reg  [5:0]  w_incr_p1;      // Call address increment
    reg  [11:0] w_call_p1;      // Call address
    
    // Immediate values
    wire [15:0] w_imm3_i;       // For ADDQ, SUBQ, Shift reg
    wire [15:0] w_imm4_i;       // For TRAP
    wire [15:0] w_imm8_i;       // For MOVEQ, Bcc.B
    wire [15:0] w_imm5_e;       // For BTST, BCHG, BCLR, BSET
    wire [15:0] w_imm8_e;       // For d8(An, Rn), d8(PC, Rn)
    
    // Instructions groups decode
    assign w_grp_p0[0]    = (instr[15:12] == 4'b0000) ? 1'b1 : 1'b0; // Immed
    assign w_grp_p0[1]    = (instr[15:12] == 4'b0001) ? 1'b1 : 1'b0; // MOVE.B
    assign w_grp_p0[2]    = (instr[15:12] == 4'b0010) ? 1'b1 : 1'b0; // MOVE.L
    assign w_grp_p0[3]    = (instr[15:12] == 4'b0011) ? 1'b1 : 1'b0; // MOVE.W
    assign w_grp_p0[4]    = (instr[15:12] == 4'b0100) ? 1'b1 : 1'b0; // Misc
    assign w_grp_p0[5]    = (instr[15:12] == 4'b0101) ? 1'b1 : 1'b0; // ADDQ, SUBQ
    assign w_grp_p0[6]    = (instr[15:12] == 4'b0110) ? 1'b1 : 1'b0; // Bcc
    assign w_grp_p0[7]    = (instr[15:12] == 4'b0111) ? 1'b1 : 1'b0; // MOVEQ
    assign w_grp_p0[8]    = (instr[15:12] == 4'b1000) ? 1'b1 : 1'b0; // OR, DIV
    assign w_grp_p0[9]    = (instr[15:12] == 4'b1001) ? 1'b1 : 1'b0; // SUB
    assign w_grp_p0[10]   = (instr[15:12] == 4'b1010) ? 1'b1 : 1'b0; // Line A
    assign w_grp_p0[11]   = (instr[15:12] == 4'b1011) ? 1'b1 : 1'b0; // CMP, EOR
    assign w_grp_p0[12]   = (instr[15:12] == 4'b1100) ? 1'b1 : 1'b0; // AND, MUL
    assign w_grp_p0[13]   = (instr[15:12] == 4'b1101) ? 1'b1 : 1'b0; // ADD
    assign w_grp_p0[14]   = (instr[15:12] == 4'b1110) ? 1'b1 : 1'b0; // Shift
    assign w_grp_p0[15]   = (instr[15:12] == 4'b1111) ? 1'b1 : 1'b0; // Line F
    
    // Effective addresses #1 bitfield
    assign w_ea1b_p0[15]  = (instr[5:0] == 6'b111111) ? 1'b1 : 1'b0; // ???
    assign w_ea1b_p0[14]  = (instr[5:0] == 6'b111110) ? 1'b1 : 1'b0; // ???
    assign w_ea1b_p0[13]  = (instr[5:0] == 6'b111101) ? 1'b1 : 1'b0; // ???
    assign w_ea1b_p0[12]  = (instr[5:0] == 6'b111100) ? 1'b1 : 1'b0; // #imm, CCR/SR
    assign w_ea1b_p0[11]  = (instr[5:0] == 6'b111011) ? 1'b1 : 1'b0; // d8(PC,Rn)
    assign w_ea1b_p0[10]  = (instr[5:0] == 6'b111010) ? 1'b1 : 1'b0; // d16(PC)
    assign w_ea1b_p0[9]   = (instr[5:0] == 6'b111001) ? 1'b1 : 1'b0; // xxxxxxxx.L
    assign w_ea1b_p0[8]   = (instr[5:0] == 6'b111000) ? 1'b1 : 1'b0; // xxxx.W
    assign w_ea1b_p0[7]   = (instr[5:4] == 2'b00)     ? 1'b1 : 1'b0; // Bcc.W
    assign w_ea1b_p0[6]   = (instr[5:3] == 3'b110)    ? 1'b1 : 1'b0; // d8(An,Rn)
    assign w_ea1b_p0[5]   = (instr[5:3] == 3'b101)    ? 1'b1 : 1'b0; // d16(An)
    assign w_ea1b_p0[4]   = (instr[5:3] == 3'b100)    ? 1'b1 : 1'b0; // -(An)
    assign w_ea1b_p0[3]   = (instr[5:3] == 3'b011)    ? 1'b1 : 1'b0; // (An)+
    assign w_ea1b_p0[2]   = (instr[5:3] == 3'b010)    ? 1'b1 : 1'b0; // (An)
    assign w_ea1b_p0[1]   = (instr[5:3] == 3'b001)    ? 1'b1 : 1'b0; // An
    assign w_ea1b_p0[0]   = (instr[5:3] == 3'b000)    ? 1'b1 : 1'b0; // Dn
    
    // Effective addresses #2 bitfield
    assign w_ea2b_p0[9]   = (instr[8:6]  == 3'b111) 
                         && (instr[11:10] != 2'b00)    ? 1'b1 : 1'b0; // ???
    assign w_ea2b_p0[8]   = (instr[11:6] == 6'b001111) ? 1'b1 : 1'b0; // xxxxxxxx.L
    assign w_ea2b_p0[7]   = (instr[11:6] == 6'b000111) ? 1'b1 : 1'b0; // xxxx.W
    assign w_ea2b_p0[6]   = (instr[8:6]  == 3'b110)    ? 1'b1 : 1'b0; // d8(An,Rn)
    assign w_ea2b_p0[5]   = (instr[8:6]  == 3'b101)    ? 1'b1 : 1'b0; // d16(An)
    assign w_ea2b_p0[4]   = (instr[8:6]  == 3'b100)    ? 1'b1 : 1'b0; // -(An)
    assign w_ea2b_p0[3]   = (instr[8:6]  == 3'b011)    ? 1'b1 : 1'b0; // (An)+
    assign w_ea2b_p0[2]   = (instr[8:6]  == 3'b010)    ? 1'b1 : 1'b0; // (An)
    assign w_ea2b_p0[1]   = (instr[8:6]  == 3'b001)    ? 1'b1 : 1'b0; // An
    assign w_ea2b_p0[0]   = (instr[8:6]  == 3'b000)    ? 1'b1 : 1'b0; // Dn
    
    // Effective addresses indexes (6-bit EA field -> 4-bit index)
    assign w_ea1_jmp_p0[3]   = (instr[5:3] == 3'b111) ? 1'b1 : 1'b0;
    assign w_ea1_jmp_p0[2:0] = (instr[5:3] == 3'b111) ? instr[2:0] : instr[5:3];
    assign w_ea2_jmp_p0[3]   = (instr[8:6] == 3'b111) ? 1'b1 : 1'b0;
    assign w_ea2_jmp_p0[2:0] = (instr[8:6] == 3'b111) ? instr[11:9] : instr[8:6];
    
    // Instructions sub-groups decode
    assign w_g0_immed_p0  = w_grp_p0[0]  &  ~instr[8];
    assign w_g0_bitimm_p0 = (instr[15:8] == 8'b0000_1000) ? 1'b1 : 1'b0;
    assign w_g0_bitop_p0  = w_grp_p0[0]  &   instr[8];
    assign w_g4_misc_p0   = (instr[15:6] == 10'b0100_111_001) ? 1'b1 : 1'b0;
    assign w_g4_oneop_p0  = w_grp_p0[4]  &  ~instr[8] & ~w_g4_misc_p0;
    assign w_g4_twoop_p0  = w_grp_p0[4]  &   instr[8];
    assign w_g5_addsub_p0 = w_grp_p0[5]  & ~(instr[7] & instr[6]);
    assign w_g6_bsr_p0    = (instr[11:8] == 4'b0001) ? 1'b1 : 1'b0;
    assign w_gE_shmem_p0  = w_grp_p0[14] &   instr[7] & instr[6];
    assign w_gE_shreg_p0  = w_grp_p0[14] & ~(instr[7] & instr[6]);
    
    // Special Z flag treatment for NBCD, SBCD, ABCD, NEGX, SUB, ADDX
    assign w_g4_nbcd_p0   = (w_grp_p0[4])  && (instr[11:6] == 6'b100000) ? 1'b1 : 1'b0;
    assign w_g8_sbcd_p0   = (w_grp_p0[8])  &&  (instr[8:4] == 5'b10000)  ? 1'b1 : 1'b0;
    assign w_gC_abcd_p0   = (w_grp_p0[12]) &&  (instr[8:4] == 5'b10000)  ? 1'b1 : 1'b0;
    assign w_g4_negx_p0   = (w_grp_p0[4])  && (instr[11:8] == 4'b0000)   ? 1'b1 : 1'b0;
    assign w_g9_subx_p0   = (w_grp_p0[9])  && ((instr[8:4] == 5'b10000) ||
                                               (instr[8:4] == 5'b10100) ||
                                               (instr[8:4] == 5'b11000)) ? 1'b1 : 1'b0;
    assign w_gD_addx_p0   = (w_grp_p0[13]) && ((instr[8:4] == 5'b10000) ||
                                               (instr[8:4] == 5'b10100) ||
                                               (instr[8:4] == 5'b11000)) ? 1'b1 : 1'b0;
    assign w_ext_ins_p0   = w_g4_negx_p0 | w_g9_subx_p0 | w_gD_addx_p0
                          | w_g4_nbcd_p0 | w_g8_sbcd_p0 | w_gC_abcd_p0;
    
    // Bit manipulation instructions
    assign w_bit_ins_p0   = w_g0_bitop_p0 | w_g0_bitimm_p0;
    
    // Illegal instruction pre-decode (not present in the jump table)
    assign w_ill_ins_p0   = (w_grp_p0[1]  & w_ea2b_p0[1])                     // MOVE.B An,<ea>
                          | (w_grp_p0[1]  & w_ea2b_p0[9])                     // MOVE.B <ea>,???
                          | (w_grp_p0[2]  & w_ea2b_p0[9])                     // MOVE.L <ea>,???
                          | (w_grp_p0[3]  & w_ea2b_p0[9])                     // MOVE.W <ea>,???
                          | (w_grp_p0[7]  & instr[8])                         // Coldfire's MVS/MVZ instr.
                          | (w_grp_p0[14] & instr[11] & instr[7] & instr[6]); // Empty slots in shift instr.
    // Priviledged instruction pre-decode
    assign w_prv_ins_p0   = ((w_grp_p0[0])  && (instr[6]) && (w_ea1b_p0[12])) // Log. immed SR
                         || ((w_g4_misc_p0) && ((instr[5:4] == 2'b10) ||      // MOVE USP
                                                (instr[5:0] == 6'b110000) ||  // RESET
                                                (instr[6:1] == 6'b11001)))    // STOP, RTE
                         || ((w_grp_p0[4])  && (instr[11:6] == 6'b011011))    // MOVE <ea>,SR
                         ? user_mode : 1'b0;
    
    // Jump table call #1 enable
    assign w_call1_ena_p0 = (w_grp_p0[0]  & w_ea1b_p0[0])                     // Bit op. reg
                          | (w_grp_p0[2]  & w_ea2b_p0[1])                     // MOVEA.L
                          | (w_grp_p0[3]  & w_ea2b_p0[1])                     // MOVEA.W
                          | (w_grp_p0[4]  & ~w_g4_misc_p0 & w_ea1b_p0[0])     // SWAP, EXT
                          | (w_grp_p0[6]  & w_g6_bsr_p0)                      // BSR
                          | (w_grp_p0[8]  & w_ea1b_p0[0])                     // SBCD reg
                          | (w_grp_p0[9]  & w_ea1b_p0[0])                     // SUBX reg
                          | (w_grp_p0[12] & w_ea1b_p0[0])                     // ABCD reg, EXG
                          | (w_grp_p0[13] & w_ea1b_p0[0]);                    // ADDX reg
    // Jump table call #2 enable
    assign w_call2_ena_p0 = (w_grp_p0[0]  & ~instr[8]     & w_ea1b_p0[12])    // Log op. SR
                          | (w_grp_p0[0]  & instr[8]      & w_ea1b_p0[1])     // MOVEP
                          | (w_grp_p0[4]  & ~w_g4_misc_p0 & w_ea1b_p0[3])     // MOVEM (An)+<list>
                          | (w_grp_p0[4]  & ~w_g4_misc_p0 & w_ea1b_p0[4])     // MOVEM <list>,-(An)
                          | (w_grp_p0[5]  & w_ea1b_p0[1])                     // ADDQA, SUBQA, DBcc
                          | (w_grp_p0[8]  & w_ea1b_p0[1])                     // SBCD mem
                          | (w_grp_p0[9]  & w_ea1b_p0[1])                     // SUBX mem
                          | (w_grp_p0[11] & w_ea1b_p0[1])                     // CMPM
                          | (w_grp_p0[12] & w_ea1b_p0[1])                     // ABCD mem, EXG
                          | (w_grp_p0[13] & w_ea1b_p0[1]);                    // ADDX mem
    
    // 6-bit indexes calculations
    assign w_idx6_5_0_p0  = (w_g4_misc_p0)
                          ? instr[5:0]
                          : 6'b000000;
    assign w_idx5_B_6_p0  = (w_g0_immed_p0 | w_g4_oneop_p0)
                          ? { instr[14], instr[11:9], instr[7:6] }
                          : 6'b000000;
    assign w_idx4_8_3_p0  = (w_gE_shreg_p0)
                          ? { instr[7:6], instr[8], instr[5:3] }
                          : 6'b000000;
    assign w_idx4_F_C_p0  = (w_grp_p0[1] | w_grp_p0[2] | w_grp_p0[3] | w_grp_p0[6] | w_grp_p0[7] | w_grp_p0[10] | w_grp_p0[15])
                          ? { 2'b11, instr[15:12] }
                          : 6'b000000;                    
    assign w_idx3_8_6_p0  = (w_grp_p0[5] | w_grp_p0[8] | w_grp_p0[9] | w_grp_p0[11] | w_grp_p0[12] | w_grp_p0[13])
                          ? { instr[14] ^ ~instr[15], instr[13] ^ ~instr[15], instr[12] ^ ~instr[15], instr[8:6] }
                          : 6'b000000;
    assign w_idx3_A_8_p0  = (w_gE_shmem_p0)
                          ? { 3'b110, instr[10:8] }
                          : 6'b000000;
    assign w_idx2_7_6_p0  = (w_g0_bitop_p0 | w_g4_twoop_p0)
                          ? { 3'b111, instr[14], instr[7:6] }
                          : 6'b000000;
    
    // 256-entry table index (16-bit instr. -> 8-bit index)
    assign w_addr_p0[7]   = ((instr[12]   | instr[13]) & ~instr[15])       // Groups #1,2,3,5,6,7
                          | instr[15]     | w_g0_bitop_p0 | w_g4_twoop_p0; // Groups #8-15
    assign w_addr_p0[6]   = w_grp_p0[5]   | w_grp_p0[8]   | w_grp_p0[9]
                          | w_grp_p0[11]  | w_grp_p0[12]  | w_grp_p0[13]
                          | w_g0_immed_p0 | w_g0_bitop_p0 | w_g4_oneop_p0
                          | w_g4_twoop_p0 | w_gE_shmem_p0;
    assign w_addr_p0[5:0] = w_idx6_5_0_p0 | w_idx5_B_6_p0 | w_idx4_8_3_p0
                          | w_idx4_F_C_p0 | w_idx3_8_6_p0 | w_idx3_A_8_p0
                          | w_idx2_7_6_p0;
    
    // Jump table ROM
    j68_decode_rom
    #(
        .USE_CLK_ENA (USE_CLK_ENA)
    )
    U_decode_rom
    (
        .clock       (clk),
        .address     (w_addr_p0),
        .q           (w_data_p1)
    );
    
    always@(*) begin
    
        // EA #1 mask
        case (w_data_p1[11:8])
            4'b0000 : w_ea1m_p1 = 16'b000_00000_00000000; // $0000
            4'b0001 : w_ea1m_p1 = 16'b000_00011_01110101; // $01F5
            4'b0010 : w_ea1m_p1 = 16'b000_00011_01111100; // $01FC
            4'b0011 : w_ea1m_p1 = 16'b000_00011_01111101; // $01FD
            4'b0100 : w_ea1m_p1 = 16'b000_00011_01111110; // $01FE
            4'b0101 : w_ea1m_p1 = 16'b000_00011_01111111; // $01FF
            4'b0110 : w_ea1m_p1 = 16'b000_01111_01001101; // $07CD
            4'b0111 : w_ea1m_p1 = 16'b000_01111_01100100; // $07E4
            4'b1000 : w_ea1m_p1 = 16'b000_01111_01100101; // $07E5
            4'b1001 : w_ea1m_p1 = 16'b000_01111_01101100; // $07EC
            4'b1010 : w_ea1m_p1 = 16'b000_01111_01111101; // $07FD
            4'b1011 : w_ea1m_p1 = 16'b000_10011_01111101; // $09FD
            4'b1100 : w_ea1m_p1 = 16'b000_11111_01111101; // $0FFD
            4'b1101 : w_ea1m_p1 = 16'b000_11111_01111111; // $0FFF
            default : w_ea1m_p1 = 16'b111_11111_01111111; // $7FFF
        endcase
        // Call address increment
        w_incr_p1 = (w_data_p1[23:18] & {6{r_call_en_p1[0]}})
                  | (w_data_p1[17:12] & {6{r_call_en_p1[1]}});
        // Call address
        if (((w_ea1m_p1 & r_ea1b_p1) == 16'h0000) || (r_ill_ins_p1)) begin
            // Illegal instruction
            w_call_p1    = OP_ILLEGAL;
            w_vld_ins_p1 = 1'b0;
        end
        else if (r_prv_ins_p1) begin
            // Priviledge violation
            w_call_p1    = OP_PRIVILEDGED;
            w_vld_ins_p1 = 1'b1;
        end
        else begin
            // Valid instruction
            w_call_p1    = w_data_p1[35:24] + { 6'b000000, w_incr_p1 };
            w_vld_ins_p1 = 1'b1;
        end
    end

    // Latch the indexes and bitfields
    always @(posedge rst or posedge clk) begin : DECODE_P1_P2
    
        if (rst) begin
            r_ea1_jmp_p1 <= 4'b0000;
            r_ea2_jmp_p1 <= 4'b0000;
            r_ill_ins_p1 <= 1'b0;
            r_prv_ins_p1 <= 1'b0;
            r_ext_ins_p1 <= 1'b0;
            r_bit_ins_p1 <= 1'b0;
            r_call_en_p1 <= 2'b00;
            r_ea1b_p1    <= 16'b0000000_00000000;      
            
            //r_ext_ins_p2 <= 1'b0;
            //r_bit_ins_p2 <= 1'b0;
            r_vld_ins_p2 <= 1'b0;
            //r_ea1_jmp_p2 <= 4'b0000;
            //r_ea2_jmp_p2 <= 4'b0000;
            r_call_p2    <= 12'h000;
        end
        else if (clk_ena) begin
            // Cycle #1
            r_ea1_jmp_p1 <= w_ea1_jmp_p0;
            r_ea2_jmp_p1 <= w_ea2_jmp_p0;
            r_ill_ins_p1 <= w_ill_ins_p0;
            r_prv_ins_p1 <= w_prv_ins_p0;
            r_ext_ins_p1 <= w_ext_ins_p0;
            r_bit_ins_p1 <= w_bit_ins_p0;
            r_call_en_p1 <= { w_call2_ena_p0, w_call1_ena_p0 };
            r_ea1b_p1    <= w_ea1b_p0;
            // Cycle #2
            //r_ext_ins_p2 <= r_ext_ins_p1;
            //r_bit_ins_p2 <= r_bit_ins_p1;
            r_vld_ins_p2 <= w_vld_ins_p1;
            //r_ea1_jmp_p2 <= r_ea1_jmp_p1;
            //r_ea2_jmp_p2 <= r_ea2_jmp_p1;
            r_call_p2    <= w_call_p1;
        end
    end
  
    assign vld_inst = r_vld_ins_p2;
    assign ext_inst = r_ext_ins_p1;
    assign bit_inst = r_bit_ins_p1;
    assign dec_jmp  = r_call_p2;
    assign ea1_jmp  = r_ea1_jmp_p1;
    assign ea2_jmp  = r_ea2_jmp_p1;
    assign ea1_bit  = r_ea1b_p1;

    // Immediate values from instruction word
    // For ADDQ, SUBQ and shift immediate 
    assign w_imm3_i[15:4] = 12'h000;
    assign w_imm3_i[3]    = (instr[11:9] == 3'b000) ? (w_g5_addsub_p0 | (w_gE_shreg_p0 & ~instr[5])) : 1'b0;
    assign w_imm3_i[2:0]  = (w_g5_addsub_p0 | (w_gE_shreg_p0 & ~instr[5])) ? instr[11:9] : 3'b000;
    // For TRAP #x : xxx0 - xxxF -> 0080 - 00BC
    assign w_imm4_i[15:8] = 8'h00;
    assign w_imm4_i[7:0]  = (w_g4_misc_p0) ? {2'b10, instr[3:0], 2'b00} : 8'h00;
    // For MOVEQ and Bcc.B
    assign w_imm8_i[15:8] = (w_grp_p0[6] | (w_grp_p0[7] & ~instr[8])) ? {8{instr[7]}} : 8'h00;
    assign w_imm8_i[7:0]  = (w_grp_p0[6] | (w_grp_p0[7] & ~instr[8])) ? instr[7:0] : 8'h00;

    // Immediate values from extension word
    // For BTST, BCHG, BCLR and BSET
    assign w_imm5_e[15:5] = 11'b0;
    assign w_imm5_e[4:0]  = ext_wd[4:0];
    // For d8(An,Rn) and d8(PC,Rn)
    assign w_imm8_e[15:8] = {8{ext_wd[7]}};
    assign w_imm8_e[7:0]  = ext_wd[7:0];

    // Latch the immediate values
    always @(posedge rst or posedge clk) begin : IMMED_VAL
    
        if (rst) begin
            imm_val <= 16'h0000;
        end
        else if (clk_ena) begin
            if (ins_rdy) imm_val <= w_imm3_i | w_imm4_i | w_imm8_i;
            if (ext_rdy) begin
                if (w_g0_bitimm_p0) begin
                    imm_val <= w_imm5_e;
                end
                else begin
                    imm_val <= w_imm8_e;
                end
            end
            if (imm_rdy) imm_val <= imm_wd;
        end
    end
  
    // Jump flag from condition codes
    always @(posedge rst or posedge clk) begin : CC_JUMP_FLAG
    
        if (rst) begin
            cc_jmp <= 1'b0;
        end
        else if (clk_ena) begin
            case (instr[11:8])
                4'b0000 : cc_jmp <= 1'b1;                                   // T
                4'b0001 : cc_jmp <= 1'b0;                                   // F
                4'b0010 : cc_jmp <= ~(ccr_in[0] | ccr_in[2]);               // HI
                4'b0011 : cc_jmp <=   ccr_in[0] | ccr_in[2];                // LS
                4'b0100 : cc_jmp <= ~ ccr_in[0];                            // CC
                4'b0101 : cc_jmp <=   ccr_in[0];                            // CS
                4'b0110 : cc_jmp <= ~ ccr_in[2];                            // NE
                4'b0111 : cc_jmp <=   ccr_in[2];                            // EQ
                4'b1000 : cc_jmp <= ~ ccr_in[1];                            // VC
                4'b1001 : cc_jmp <=   ccr_in[1];                            // VS
                4'b1010 : cc_jmp <= ~ ccr_in[3];                            // PL
                4'b1011 : cc_jmp <=   ccr_in[3];                            // MI
                4'b1100 : cc_jmp <= ~(ccr_in[1] ^ ccr_in[3]);               // GE
                4'b1101 : cc_jmp <=   ccr_in[1] ^ ccr_in[3];                // LT
                4'b1110 : cc_jmp <= ~((ccr_in[1] ^ ccr_in[3]) | ccr_in[2]); // GT
                4'b1111 : cc_jmp <=   (ccr_in[1] ^ ccr_in[3]) | ccr_in[2];  // LE
            endcase
        end
    end
  
endmodule
