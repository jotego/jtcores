// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502ExecutionController(
    clk,
    cen,
    rstn,
    // InstructionDecode interfaces
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
    id2ec_reg,
    ec2id_done,
    // RegisterFile interfaces
    rf2ec_pcl,
    rf2ec_pch,
    rf2ec_a,
    rf2ec_x,
    rf2ec_y,
    rf2ec_c,
    rf2ec_d,
    rf2ec_n,
    rf2ec_v,
    rf2ec_z,
    ec2rf_c,
    ec2rf_set_c,
    ec2rf_i,
    ec2rf_set_i,
    ec2rf_v,
    ec2rf_set_v,
    ec2rf_d,
    ec2rf_set_d,
    ec2rf_n,
    ec2rf_set_n,
    ec2rf_z,
    ec2rf_set_z,
    ec2rf_data,
    ec2rf_set_a,
    ec2rf_set_x,
    ec2rf_set_y,
    ec2rf_set_s,
    ec2rf_set_pcl,
    ec2rf_set_pch,
    // MemoryController interfaces
    ec2mc_data,
    ec2mc_store);
  input        clk;
  input        cen;
  input        rstn;

  input        id2ec_reset_c;
  input        id2ec_set_c;
  input        id2ec_reset_i;
  input        id2ec_set_i;
  input        id2ec_reset_v;
  input        id2ec_reset_d;
  input        id2ec_set_d;
  input        id2ec_load;
  input        id2ec_ops;
  input        id2ec_branch;
  input  [4:0] id2ec_opcode;
  input  [7:0] id2ec_data;
  input  [1:0] id2ec_reg;
  output       ec2id_done;

  input  [7:0] rf2ec_pcl;
  input  [7:0] rf2ec_pch;
  input  [7:0] rf2ec_a;
  input  [7:0] rf2ec_x;
  input  [7:0] rf2ec_y;
  input        rf2ec_c;
  input        rf2ec_d;
  input        rf2ec_n;
  input        rf2ec_v;
  input        rf2ec_z;
  output       ec2rf_c;
  output       ec2rf_set_c;
  output       ec2rf_i;
  output       ec2rf_set_i;
  output       ec2rf_v;
  output       ec2rf_set_v;
  output       ec2rf_d;
  output       ec2rf_set_d;
  output       ec2rf_n;
  output       ec2rf_set_n;
  output       ec2rf_z;
  output       ec2rf_set_z;
  output [7:0] ec2rf_data;
  output       ec2rf_set_a;
  output       ec2rf_set_x;
  output       ec2rf_set_y;
  output       ec2rf_set_s;
  output       ec2rf_set_pcl;
  output       ec2rf_set_pch;

  output [7:0] ec2mc_data;
  output       ec2mc_store;

  reg          r_done;
  reg          r_branch;
  reg          r_shift;
  reg          r_inc;
  reg    [7:0] r_data;
  reg    [1:0] r_m2m_cnt;

  wire         w_update_flag;

  wire   [2:0] w_opcode;
  wire         w_opx_10;
  wire         w_opx_11;
  wire         w_opx_01;
  wire         w_opx_00;

  wire   [7:0] w_ora;
  wire   [7:0] w_and;
  wire   [7:0] w_eor;

  wire         w_use_alu;
  wire         w_ops_set_nz;
  wire         w_shift_set_cnz;
  wire         w_cmp;
  wire         w_sbc;
  wire         w_inc;
  wire         w_dec;
  wire         w_shift_rotate;
  wire         w_shift_right;
  wire         w_shift_a;
  wire         w_shift;
  wire         w_dexy;
  wire         w_indexy;
  wire         w_bit;
  wire         w_plp;

  wire         w_m2m_done;

  wire   [7:0] w_alu_in_a;
  wire   [7:0] w_alu_in_b;
  wire   [7:0] w_alu_out;
  wire         w_alu_cin;
  wire         w_alu_sbc;
  wire         w_alu_n;
  wire         w_alu_z;
  wire         w_alu_c;
  wire         w_alu_v;

  wire   [7:0] w_shift_in;
  wire   [7:0] w_shift_out;
  wire         w_shift_n;
  wire         w_shift_z;
  wire         w_shift_c;

  wire   [7:0] w_bit_out;
  wire         w_bit_n;
  wire         w_bit_z;
  wire         w_bit_v;
  wire         w_bit_set_nzv;

  wire         w_taken;
  wire         w_b_carry;
  wire         w_b_inc;
  wire         w_b_dec;

  `include "MC6502Common.vh"

  assign ec2id_done      = r_done | r_branch | id2ec_load | w_m2m_done |
                           (id2ec_ops & !w_opx_10) |
                           (id2ec_branch & !w_b_carry);

  assign ec2rf_c         = w_plp ? id2ec_data[0] :
                           w_use_alu ? w_alu_c :
                           w_shift_set_cnz ? w_shift_c : id2ec_set_c;
  assign ec2rf_set_c     = w_plp | w_use_alu | w_shift_set_cnz |
                           id2ec_set_c | id2ec_reset_c;
  assign ec2rf_i         = w_plp ? id2ec_data[2] : id2ec_set_i;
  assign ec2rf_set_i     = w_plp | id2ec_set_i | id2ec_reset_i;
  assign ec2rf_v         = w_plp ? id2ec_data[6] :
                           w_use_alu ? w_alu_v :
                           w_bit_set_nzv ? w_bit_v : 1'b0;
  assign ec2rf_set_v     = w_plp | id2ec_reset_v | w_bit_set_nzv |
                           (w_use_alu & (w_opcode != OP_CMP));
  assign ec2rf_d         = w_plp ? id2ec_data[3] : id2ec_set_d;
  assign ec2rf_set_d     = w_plp | id2ec_set_d | id2ec_reset_d;
  assign ec2rf_n         = w_plp ? id2ec_data[7] :
                           w_shift_set_cnz ? w_shift_n :
                           w_bit_set_nzv ? w_bit_n :
                           (w_use_alu | w_m2m_done) ? w_alu_n : ec2rf_data[7];
  assign ec2rf_set_n     = w_plp | w_use_alu | w_m2m_done | w_ops_set_nz;
  assign ec2rf_z         = w_plp ? id2ec_data[1] :
                           w_shift_set_cnz ? w_shift_z :
                           w_bit_set_nzv ? w_bit_z :
                           (w_use_alu | w_m2m_done) ? w_alu_z :
                           (ec2rf_data == 8'h00);
  assign ec2rf_set_z     = w_plp | w_use_alu | w_m2m_done | w_ops_set_nz;
  assign ec2rf_data      = (w_use_alu | w_taken | r_branch) ? w_alu_out :
                           ((w_inc | w_dec) & id2ec_load) ? w_alu_out :
                           w_shift_a ? w_shift_out :
                           (id2ec_ops & w_opx_10) ? id2ec_data :
                           !id2ec_ops ? id2ec_data :
                           (w_opcode == OP_ORA) ? w_ora :
                           (w_opcode == OP_AND) ? w_and :
                           (w_opcode == OP_EOR) ? w_eor :
                           (w_opcode == OP_LDA) ? id2ec_data : 8'hxx;
  assign ec2rf_set_a     = (id2ec_load & (id2ec_reg == REG_A)) |
                           (id2ec_ops & w_opx_01 & ((w_opcode == OP_ORA) |
                                                    (w_opcode == OP_AND) |
                                                    (w_opcode == OP_EOR) |
                                                    (w_opcode == OP_ADC) |
                                                    (w_opcode == OP_SBC)));
  assign ec2rf_set_x     = id2ec_load & (id2ec_reg == REG_X);
  assign ec2rf_set_y     = id2ec_load & (id2ec_reg == REG_Y);
  assign ec2rf_set_s     = id2ec_load & (id2ec_reg == REG_S);
  assign ec2rf_set_pcl   = w_taken;
  assign ec2rf_set_pch   = r_branch;

  assign ec2mc_data      = r_shift ? w_shift_out : w_alu_out;
  assign ec2mc_store     = w_m2m_done;

  assign w_update_flag   = id2ec_reset_c | id2ec_set_c | id2ec_reset_i |
                           id2ec_set_i | id2ec_reset_v | id2ec_reset_d |
                           id2ec_set_d;

  assign w_opcode        = id2ec_opcode[2:0];
  assign w_opx_10        = id2ec_opcode[4:3] == 2'b10;
  assign w_opx_11        = id2ec_opcode[4:3] == 2'b11;
  assign w_opx_01        = id2ec_opcode[4:3] == 2'b01;
  assign w_opx_00        = id2ec_opcode[4:3] == 2'b00;

  assign w_ora           = rf2ec_a | id2ec_data;
  assign w_and           = rf2ec_a & id2ec_data;
  assign w_eor           = rf2ec_a ^ id2ec_data;

  assign w_use_alu       = id2ec_ops & w_opx_01 & ((w_opcode == OP_ADC) |
                                                   (w_opcode == OP_SBC) |
                                                   (w_opcode == OP_CMP));
  assign w_ops_set_nz    = (id2ec_ops & w_opx_01 & (w_opcode != OP_STA)) |
                           w_bit_set_nzv | w_indexy;
  assign w_shift_set_cnz = w_shift_a | (r_shift & w_m2m_done);
  assign w_cmp           = id2ec_ops & w_opx_01 & (w_opcode == OP_CMP);
  assign w_sbc           = id2ec_ops & w_opx_01 & (w_opcode == OP_SBC);
  assign w_inc           = id2ec_ops & w_opx_10 & (w_opcode == OP_INC);
  assign w_dec           = id2ec_ops & w_opx_10 & (w_opcode == OP_DEC);
  assign w_shift_rotate  = (w_opcode == OP_ROL) | (w_opcode == OP_ROR);
  assign w_shift_right   = (w_opcode == OP_LSR) | (w_opcode == OP_ROR);
  assign w_shift_a       = w_shift & id2ec_load;
  assign w_shift         = id2ec_ops & w_opx_10 & ((w_opcode == OP_ASL) |
                                                   (w_opcode == OP_ROL) |
                                                   (w_opcode == OP_LSR) |
                                                   (w_opcode == OP_ROR));
  assign w_dexy          = w_dec & id2ec_load & (id2ec_reg != REG_A);
  assign w_indexy        = (w_inc | w_dec) & id2ec_load & (id2ec_reg != REG_A);
  assign w_bit           = w_opx_00 & (w_opcode == OP_BIT);
  assign w_plp           = id2ec_ops & w_opx_11 & (w_opcode == OP_PLP);

  assign w_m2m_done      = r_m2m_cnt == 2'b01;

  assign w_alu_in_a      = id2ec_branch ? rf2ec_pcl :
                           r_branch ? rf2ec_pch :
                           w_indexy ? id2ec_data :
                           r_m2m_cnt[0] ? r_data :
                           (id2ec_reg == REG_X) ? rf2ec_x :
                           (id2ec_reg == REG_Y) ? rf2ec_y : rf2ec_a;
  assign w_alu_in_b      = r_branch ? 8'h00 :
                           r_m2m_cnt[0] ? 8'h00 :
                           w_indexy ? 8'h00 : id2ec_data;
  assign w_alu_cin       = r_branch ? r_inc :
                           r_m2m_cnt[0] ? r_inc :
                           (rf2ec_c | w_cmp | id2ec_branch | w_inc);
  assign w_alu_sbc       = ((r_branch | (r_m2m_cnt != 2'b00)) & !r_inc) |
                           (w_dec & id2ec_load) | w_sbc | w_cmp;

  assign w_shift_in      = r_m2m_cnt[0] ? r_data : id2ec_data;

  assign w_taken         = !id2ec_branch ? 1'b0 :
                           (w_opcode == OP_BPL) ? !rf2ec_n :
                           (w_opcode == OP_BMI) ? rf2ec_n :
                           (w_opcode == OP_BVC) ? !rf2ec_v :
                           (w_opcode == OP_BVS) ? rf2ec_v :
                           (w_opcode == OP_BCC) ? !rf2ec_c :
                           (w_opcode == OP_BCS) ? rf2ec_c :
                           (w_opcode == OP_BNE) ? !rf2ec_z : rf2ec_z;
  assign w_b_inc         = !id2ec_data[7] & w_alu_c;
  assign w_b_dec         = id2ec_data[7] & !w_alu_c;
  assign w_b_carry       = w_taken & id2ec_branch & (w_b_inc | w_b_dec);

  assign w_bit_out       = id2ec_data & rf2ec_a;
  assign w_bit_set_nzv   = id2ec_ops & w_bit;
  assign w_bit_z         = w_bit_out == 8'h00;
  assign w_bit_n         = w_bit_out[7];
  assign w_bit_v         = w_bit_out[0];

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_done    <= 1'b0;
      r_branch  <= 1'b0;
      r_shift   <= 1'b0;
      r_inc     <= 1'b0;
      r_data    <= 0;
      r_m2m_cnt <= 2'b00;
    end else if(cen) begin
      r_done    <= w_update_flag;
      r_branch  <= w_b_carry;
      if (id2ec_ops) begin
        r_shift   <= w_shift;
      end
      if (r_m2m_cnt == 2'b00) begin
        r_inc     <= w_b_inc | w_inc;
      end
      if ((w_inc | w_dec | w_shift) & !id2ec_load)  begin
        r_data    <= id2ec_data;
        r_m2m_cnt <= 2'b11;
      end else if (r_m2m_cnt != 2'b00) begin
        r_m2m_cnt <= { 1'b0, r_m2m_cnt[1] };
      end
    end
  end

  MC6502Accumulator alu(
      .i_a     (w_alu_in_a    ),
      .i_m     (w_alu_in_b    ),
      .i_c     (w_alu_cin     ),
      .i_d     (rf2ec_d       ),
      .i_s     (w_alu_sbc     ),
      .o_a     (w_alu_out     ),
      .o_n     (w_alu_n       ),
      .o_z     (w_alu_z       ),
      .o_c     (w_alu_c       ),
      .o_v     (w_alu_v       ));

  MC6502Shifter shifter(
      .i_data  (w_shift_in    ),
      .i_rotate(w_shift_rotate),
      .i_right (w_shift_right ),
      .i_c     (rf2ec_c       ),
      .o_data  (w_shift_out   ),
      .o_n     (w_shift_n     ),
      .o_z     (w_shift_z     ),
      .o_c     (w_shift_c     ));
endmodule  // MC6502InstructionDecode
