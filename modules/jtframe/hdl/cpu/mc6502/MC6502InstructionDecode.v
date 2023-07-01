// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502InstructionDecode(
    clk,
    cen,
    rstn,
    // MemoryController interfaces
    mc2id_data,
    mc2id_valid,
    id2mc_fetch,
    id2mc_sync,
    id2mc_operand,
    id2mc_modex,
    id2mc_mode,
    id2mc_reg,
    id2mc_store,
    id2mc_push,
    id2mc_pop,
    id2mc_p_reg,
    id2mc_jump,
    // ExecutionController interfaces
    ec2id_done,
    id2ec_reset_c,
    id2ec_set_c,
    id2ec_reset_i,
    id2ec_set_i,
    id2ec_reset_v,
    id2ec_reset_d,
    id2ec_set_d,
    id2ec_load,
    id2ec_ops,
    id2ec_branch,
    id2ec_opcode,
    id2ec_data,
    id2ec_reg);
  input         clk;
  input         cen;
  input         rstn;
  input  [ 7:0] mc2id_data;
  input         mc2id_valid;
  output        id2mc_fetch;
  output        id2mc_sync;
  output        id2mc_operand;
  output        id2mc_modex;
  output [ 2:0] id2mc_mode;
  output [ 1:0] id2mc_reg;
  output        id2mc_store;
  output        id2mc_push;
  output        id2mc_pop;
  output        id2mc_p_reg;
  output        id2mc_jump;

  input         ec2id_done;
  output        id2ec_reset_c;
  output        id2ec_set_c;
  output        id2ec_reset_i;
  output        id2ec_set_i;
  output        id2ec_reset_v;
  output        id2ec_reset_d;
  output        id2ec_set_d;
  output        id2ec_load;
  output        id2ec_ops;
  output        id2ec_branch;
  output [ 4:0] id2ec_opcode;
  output [ 7:0] id2ec_data;
  output [ 1:0] id2ec_reg;

  reg           r_sync;
  reg           r_load;
  reg           r_ops;
  reg           r_branch;
  reg           r_set_reg;
  reg    [ 1:0] r_reg;
  reg    [ 2:0] r_opcode;
  reg    [ 1:0] r_opx;

  wire   [ 2:0] w_opcode;
  wire   [ 2:0] w_modified_opcode;
  wire   [ 2:0] w_addressing;

  wire          w_fetch_valid;
  wire          w_operand_valid;

  wire          w_unknown_instruction;
  wire          w_xxxx_xx00;
  wire          w_xxxx_xx01;
  wire          w_xxxx_xx10;
  wire          w_xxxx_1x00;
  wire          w_xxxx_0000;
  wire          w_xxxx_1000;
  wire          w_xxx0_0000;
  wire          w_xxx0_1000;
  wire          w_xxx0_1100;
  wire          w_xxx1_0000;
  wire          w_xxx1_1000;
  wire          w_10xx_xxxx;

  // Standard addressing mode (---X_XX--)
  wire          w_indexed_indirect;    // (Indirect, X)
  wire          w_zero_page;           // Zero Page
  wire          w_immediate;           // Immediate
  wire          w_absolute;            // Absolute
  wire          w_indirect_index;      // (Indirect), Y
  wire          w_zero_page_index;     // Zero Page, X
  wire          w_absolute_indexed_y;  // Absolute, Y
  wire          w_absolute_indexed_x;  // Absolute, X

  wire          w_modex_immediate;
  wire          w_modex_register;

  wire          w_ldx_code;
  wire          w_ldy_code;
  wire          w_inc_code;
  wire          w_dec_code;
  wire          w_shift_code;
  wire          w_bit_code;
  wire          w_stx_code;
  wire          w_sty_code;
  wire          w_cpx_code;
  wire          w_cpy_code;

  wire          w_tya;
  wire          w_tay;
  wire          w_lda;
  wire          w_ldx;
  wire          w_ldy;
  wire          w_sta;
  wire          w_stx;
  wire          w_sty;
  wire          w_t;
  wire          w_b;
  wire          w_ops;
  wire          w_inc;
  wire          w_dec;
  wire          w_inx;
  wire          w_iny;
  wire          w_dex;
  wire          w_dey;
  wire          w_inxy;
  wire          w_dexy;
  wire          w_index;
  wire          w_indey;
  wire          w_indexy;
  wire          w_shift;
  wire          w_bit;
  wire          w_cpx;
  wire          w_cpy;
  wire          w_pla;
  wire          w_plp;
  wire          w_jmp_ind;
  wire          w_jmp;
  wire          w_j;
  wire          w_jsr;
  wire          w_call;
  wire          w_return;
  wire          w_interrupt;

  wire          w_request_reg;
  wire   [ 1:0] w_from_reg;
  wire   [ 1:0] w_to_reg;

  wire          w_valid_ld_mode;
  wire          w_valid_inc_mode;
  wire          w_valid_shift_mode;
  wire          w_valid_bit_mode;
  wire          w_valid_stx_mode;
  wire          w_valid_sty_mode;
  wire          w_valid_cp_mode;

  `include "MC6502Common.vh"

  assign id2mc_sync            = r_sync;
  assign id2mc_fetch           = r_sync;
  assign id2mc_operand         = w_ldx | w_ldy | w_request_reg | w_ops | w_b |
                                 w_inc | w_dec | w_shift | w_bit | w_stx |
                                 w_sty | w_cpx | w_cpy | id2mc_push |
                                 id2mc_pop | id2mc_jump;
  assign id2mc_mode            = w_request_reg ? MODEX_REGISTER :
                                 w_b ? MODE_IMMEDIATE :
                                 w_jmp_ind ?  MODEX_INDIRECT_PC :
                                 w_jsr ? MODEX_ABSOLUTE_PC :
                                 w_addressing;
  assign id2mc_modex           = w_request_reg | w_ldx | w_cpx | w_cpy |
                                 w_jmp | (w_j & w_return) |
                                 (w_ldy & w_modex_immediate) |
                                 (w_shift & w_modex_register) |
                                 (w_stx & w_zero_page_index);
  assign id2mc_reg             = w_from_reg;
  assign id2mc_store           = w_sta | w_stx | w_sty;
  assign id2mc_push            = (w_xxx0_1000 & ((w_opcode == OP_PHP) |
                                                 (w_opcode == OP_PHA))) |
                                 (w_j & w_call);
  assign id2mc_pop             = (w_xxx0_1000 & ((w_opcode == OP_PLP) |
                                                 (w_opcode == OP_PLA))) |
                                 (w_j & w_return);
  assign id2mc_p_reg           = (w_xxx0_1000 & ((w_opcode == OP_PHP) |
                                                 (w_opcode == OP_PLP))) |
                                 (w_j & w_interrupt);
  assign id2mc_jump            = w_jmp | w_j;

  assign id2ec_reset_c         = w_xxx1_1000 & (w_opcode == 3'b000);
  assign id2ec_set_c           = w_xxx1_1000 & (w_opcode == 3'b001);
  assign id2ec_reset_i         = w_xxx1_1000 & (w_opcode == 3'b010);
  assign id2ec_set_i           = w_xxx1_1000 & (w_opcode == 3'b011);
  assign id2ec_reset_v         = w_xxx1_1000 & (w_opcode == 3'b101);
  assign id2ec_reset_d         = w_xxx1_1000 & (w_opcode == 3'b110);
  assign id2ec_set_d           = w_xxx1_1000 & (w_opcode == 3'b111);
  assign id2ec_data            = mc2id_data;
  assign id2ec_load            = w_operand_valid & (r_load | w_lda);
  assign id2ec_ops             = r_ops & w_operand_valid;
  assign id2ec_branch          = r_branch & w_operand_valid;
  assign id2ec_opcode          = { r_opx, r_opcode };
  assign id2ec_reg             = r_reg;

  assign w_opcode              = mc2id_data[7:5];
  assign w_modified_opcode     = w_inxy ? OP_INC :
                                 w_dexy ? OP_DEC :
                                 (w_stx | w_sty) ? OP_STA :
                                 (w_cpx | w_cpy) ? OP_CMP :
                                 w_pla ? OP_LDA : w_opcode;
  assign w_addressing          = mc2id_data[4:2];

  assign w_fetch_valid         = mc2id_valid & r_sync;
  assign w_operand_valid       = mc2id_valid & !r_sync;

  assign w_xxxx_xx00           = w_fetch_valid & (mc2id_data[1:0] == 2'b00);
  assign w_xxxx_xx01           = w_fetch_valid & (mc2id_data[1:0] == 2'b01);
  assign w_xxxx_xx10           = w_fetch_valid & (mc2id_data[1:0] == 2'b10);
  assign w_xxxx_1x00           = w_xxxx_xx00 & mc2id_data[3];
  assign w_xxxx_0000           = w_xxxx_xx00 & (mc2id_data[3:2] == 2'b00);
  assign w_xxxx_1000           = w_xxxx_1x00 & !mc2id_data[2];
  assign w_xxx0_1000           = w_xxxx_1000 & !mc2id_data[4];
  assign w_xxx0_1100           = w_xxxx_1x00 & !mc2id_data[4] & mc2id_data[2];
  assign w_xxx0_0000           = w_xxxx_0000 & !mc2id_data[4];
  assign w_xxx1_0000           = w_xxxx_0000 & mc2id_data[4];
  assign w_xxx1_1000           = w_xxxx_1000 & mc2id_data[4];
  assign w_10xx_xxxx           = w_fetch_valid & (mc2id_data[7:6] == 2'b10);

  assign w_indexed_indirect    = w_addressing == MODE_INDEXED_INDIRECT;
  assign w_zero_page           = w_addressing == MODE_ZERO_PAGE;
  assign w_immediate           = w_addressing == MODE_IMMEDIATE;
  assign w_absolute            = w_addressing == MODE_ABSOLUTE;
  assign w_indirect_index      = w_addressing == MODE_INDIRECT_INDEX;
  assign w_zero_page_index     = w_addressing == MODE_ZERO_PAGE_INDEX_X;
  assign w_absolute_indexed_y  = w_addressing == MODE_ABSOLUTE_INDEXED_Y;
  assign w_absolute_indexed_x  = w_addressing == MODE_ABSOLUTE_INDEXED_X;

  assign w_modex_immediate     = w_addressing == MODEX_IMMEDIATE;
  assign w_modex_register      = w_addressing == MODEX_REGISTER;

  assign w_unknown_instruction = w_fetch_valid & !id2mc_operand & !w_xxx1_1000;

  assign w_valid_ld_mode       = w_modex_immediate | w_zero_page | w_absolute |
                                 w_zero_page_index | w_absolute_indexed_x;
  assign w_valid_inc_mode      = w_zero_page | w_zero_page_index |
                                 w_absolute | w_absolute_indexed_x;
  assign w_valid_shift_mode    = w_valid_inc_mode | w_modex_register;
  assign w_valid_bit_mode      = w_zero_page | w_absolute;
  assign w_valid_stx_mode      = w_zero_page | w_absolute | w_zero_page_index;
  assign w_valid_sty_mode      = w_zero_page | w_absolute | w_zero_page_index;
  assign w_valid_cp_mode       = w_modex_immediate | w_zero_page | w_absolute;

  assign w_ldx_code            = w_xxxx_xx10 & (w_opcode == OP_LDX);
  assign w_ldy_code            = w_xxxx_xx00 & (w_opcode == OP_LDY);
  assign w_inc_code            = w_xxxx_xx10 & (w_opcode == OP_INC);
  assign w_dec_code            = w_xxxx_xx10 & (w_opcode == OP_DEC);
  assign w_shift_code          = w_xxxx_xx10 & ((w_opcode == OP_ASL) |
                                                (w_opcode == OP_ROL) |
                                                (w_opcode == OP_LSR) |
                                                (w_opcode == OP_ROR));
  assign w_bit_code            = w_xxxx_xx00 & (w_opcode == OP_BIT);
  assign w_stx_code            = w_xxxx_xx10 & (w_opcode == OP_STX);
  assign w_sty_code            = w_xxxx_xx00 & (w_opcode == OP_STY);
  assign w_cpx_code            = w_xxxx_xx00 & (w_opcode == OP_CPX);
  assign w_cpy_code            = w_xxxx_xx00 & (w_opcode == OP_CPY);
  assign w_ldx                 = w_ldx_code & w_valid_ld_mode;
  assign w_ldy                 = w_ldy_code & w_valid_ld_mode;
  assign w_tya                 = w_xxx1_1000 & (w_opcode == 3'b100);
  assign w_tay                 = w_xxx0_1000 & (w_opcode == OP_TAY);
  assign w_lda                 = r_ops & (r_opx == 2'b01) &
                                 (r_opcode == OP_LDA);
  assign w_t                   = w_tya | w_tay |
                                 (w_10xx_xxxx & (mc2id_data[3:0] == 4'b1010));
  assign w_b                   = w_xxx1_0000;
  assign w_ops                 = w_xxxx_xx01;
  assign w_inc                 = w_inc_code & w_valid_inc_mode;
  assign w_dec                 = w_dec_code & w_valid_inc_mode;
  assign w_shift               = w_shift_code & w_valid_shift_mode;
  assign w_bit                 = w_bit_code & w_valid_bit_mode;
  assign w_sta                 = w_ops & (w_opcode == OP_STA) & !w_immediate;
  assign w_stx                 = w_stx_code & w_valid_stx_mode;
  assign w_sty                 = w_sty_code & w_valid_sty_mode;
  assign w_inx                 = w_xxx0_1000 & (w_opcode == OP_INX);
  assign w_iny                 = w_xxx0_1000 & (w_opcode == OP_INY);
  assign w_dex                 = w_inc_code & w_immediate;
  assign w_dey                 = w_xxx0_1000 & (w_opcode == OP_DEY);
  assign w_inxy                = w_inx | w_iny;
  assign w_dexy                = w_dex | w_dey;
  assign w_index               = w_inx | w_dex;
  assign w_indey               = w_iny | w_dey;
  assign w_indexy              = w_inx | w_iny | w_dex | w_dey;
  assign w_cpx                 = w_cpx_code & w_valid_cp_mode;
  assign w_cpy                 = w_cpy_code & w_valid_cp_mode;
  assign w_pla                 = w_xxx0_1000 & (w_opcode == OP_PLA);
  assign w_plp                 = w_xxx0_1000 & (w_opcode == OP_PLP);
  assign w_jmp_ind             = w_xxx0_1100 & (w_opcode == OP_JMP_IND);
  assign w_jmp                 = w_xxx0_1100 & ((w_opcode == OP_JMP_ABS) |
                                                (w_opcode == OP_JMP_IND));
  assign w_j                   = w_xxx0_0000 & !mc2id_data[7];
  assign w_jsr                 = w_xxx0_0000 & (w_opcode == OP_JSR);
  assign w_call                = (w_opcode == OP_BRK) | (w_opcode == OP_JSR);
  assign w_return              = (w_opcode == OP_RTI) | (w_opcode == OP_RTS);
  assign w_interrupt           = (w_opcode == OP_BRK) | (w_opcode == OP_RTI);

  assign w_request_reg         = w_t | w_indexy;
  assign w_from_reg            = (w_tya | w_indey | w_sty) ? REG_Y :
                                 (w_tay | w_shift | w_sta) ? REG_A :
                                 (!mc2id_data[5] | w_index | w_stx) ? REG_X :
                                 mc2id_data[4] ? REG_S : REG_A;
  assign w_to_reg              = w_tya ? REG_A :
                                 (w_tay | w_indey) ? REG_Y :
                                 (mc2id_data[5] | w_index) ? REG_X :
                                 mc2id_data[4] ? REG_S : REG_A;

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_sync    <= 1'b1;
      r_load    <= 1'b0;
      r_ops     <= 1'b0;
      r_branch  <= 1'b0;
      r_reg     <= 2'b00;
      r_opcode  <= 3'b000;
      r_opx     <= 2'b00;
    end else if(cen) begin
      r_sync    <= ec2id_done | (r_sync & !mc2id_valid);
      if (w_fetch_valid) begin
        r_load    <= w_ldx | w_ldy | w_t | w_indexy |
                     (w_shift & w_modex_register);
        r_ops     <= w_ops | w_inc | w_dec | w_shift | w_indexy | w_bit |
                     w_stx | w_sty | w_cpx | w_cpy | id2mc_push | id2mc_pop |
                     id2mc_jump;
        r_branch  <= w_b;
        r_reg     <= (w_ldx | w_cpx) ? REG_X :
                     (w_ldy | w_cpy) ? REG_Y :
                     w_request_reg ? w_to_reg : REG_A;
        r_opcode  <= w_modified_opcode;
        r_opx     <= w_indexy ? 2'b10 :
                     w_plp ? 2'b11 :
                     (w_stx | w_sty | w_cpx | w_cpy | w_pla) ? 2'b01 :
                     mc2id_data[1:0];
      end
    end
  end
endmodule  // MC6502InstructionDecode
