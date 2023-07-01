// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502MemoryController(
    clk,
    cen,
    rstn,
    i_rdy,
    i_db,
    o_db,
    o_ab,
    o_rw,
    o_sync,
    // InterruptLogic interfaces
    il2mc_addr,
    il2mc_read,
    il2mc_write,
    il2mc_data,
    mc2il_data,
    mc2il_brk,
    // RegisterFile interfaces
    rf2mc_pc,
    rf2mc_a,
    rf2mc_x,
    rf2mc_y,
    rf2mc_s,
    rf2mc_psr,
    mc2rf_fetched,
    mc2rf_pushed,
    mc2rf_pull,
    mc2rf_pc,
    mc2rf_set_pc,
    mc2rf_psr,
    mc2rf_set_psr,
    // InstructionDecode interfaces
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
    mc2id_data,
    mc2id_valid,
    // ExecutionController interfaces
    ec2mc_data,
    ec2mc_store);
  input         clk;
  input         cen;
  input         rstn;
  input         i_rdy;
  input  [ 7:0] i_db;
  output [ 7:0] o_db;
  output [15:0] o_ab;
  output        o_rw;
  output        o_sync;

  input  [15:0] il2mc_addr;
  input         il2mc_read;
  input         il2mc_write;
  input  [ 7:0] il2mc_data;
  output [ 7:0] mc2il_data;
  output        mc2il_brk;

  input  [15:0] rf2mc_pc;
  input  [ 7:0] rf2mc_a;
  input  [ 7:0] rf2mc_x;
  input  [ 7:0] rf2mc_y;
  input  [ 7:0] rf2mc_s;
  input  [ 7:0] rf2mc_psr;
  output        mc2rf_fetched;
  output        mc2rf_pushed;
  output        mc2rf_pull;
  output [15:0] mc2rf_pc;
  output        mc2rf_set_pc;
  output [ 7:0] mc2rf_psr;
  output        mc2rf_set_psr;

  input         id2mc_fetch;
  input         id2mc_sync;
  input         id2mc_operand;
  input  [ 2:0] id2mc_mode;
  input         id2mc_modex;
  input  [ 1:0] id2mc_reg;
  input         id2mc_store;
  input         id2mc_push;
  input         id2mc_pop;
  input         id2mc_p_reg;
  input         id2mc_jump;
  output [ 7:0] mc2id_data;
  output        mc2id_valid;

  input  [ 7:0] ec2mc_data;
  input         ec2mc_store;

  reg    [ 2:0] r_operand;
  reg           r_modex;
  reg    [ 2:0] r_mode;
  reg    [15:0] r_data;
  reg    [ 1:0] r_reg;
  reg           r_carry;
  reg           r_store;
  reg           r_push;
  reg           r_pop;
  reg           r_jump;

  wire          w_adder_valid;
  wire   [ 8:0] w_adder_sum;
  wire   [ 7:0] w_adder_in_a;
  wire   [ 7:0] w_adder_in_b;

  wire          w_write;
  wire          w_push_cycle;
  wire          w_pop_cycle;
  wire          w_il_active;
  wire   [15:0] w_il_addr;
  wire          w_id_active;
  wire   [15:0] w_id_addr;
  wire          w_1t_mode;
  wire          w_2t_mode;
  wire          w_3t_mode;
  wire          w_4t_mode;
  wire          w_5t_mode;
  wire          w_6t_mode;
  wire          w_fetch_opcode;
  wire          w_fetch_next;
  wire          w_register;
  wire          w_immediate;
  wire          w_absolute;
  wire          w_absolute_pc;
  wire          w_indirect_pc;
  wire          w_abs_idx;
  wire          w_abs_idx_x;
  wire          w_abs_idx_y;
  wire          w_zero_page;
  wire          w_zero_idx;
  wire          w_zero_idx_x;
  wire          w_zero_idx_y;
  wire          w_indirect;
  wire          w_indirect_x;
  wire          w_indirect_y;
  wire   [15:0] w_immediate_addr;
  wire   [15:0] w_absolute_addr;
  wire   [15:0] w_abs_idx_addr;
  wire   [15:0] w_zero_page_addr;
  wire   [15:0] w_zero_idx_addr;
  wire   [15:0] w_indirect_addr;
  wire   [15:0] w_idx_ind_addr;
  wire   [15:0] w_ind_idx_addr;
  wire          w_abs_idx_add;
  wire          w_zero_idx_add;
  wire          w_idx_ind_add;
  wire          w_ind_idx_add;
  wire   [ 7:0] w_register_data;
  wire   [ 7:0] w_jsr_data;
  wire          w_jmp;
  wire          w_jsr;
  wire          w_brk;
  wire          w_rts;
  wire          w_rti;

  `include "MC6502Common.vh"

  assign o_db             = ec2mc_store ? ec2mc_data :
                            il2mc_write ? il2mc_data :
                            (r_push & r_jump) ? w_jsr_data :
                            (r_reg == REG_A) ? rf2mc_a :
                            (r_reg == REG_Y) ? rf2mc_y :
                            (r_push & !r_jump) ? rf2mc_psr : rf2mc_x;
  assign o_ab             = w_il_active ? w_il_addr :
                            ec2mc_store ? r_data :
                            w_push_cycle ? { 8'h01, rf2mc_s } :
                            w_pop_cycle ? { 8'h01, rf2mc_s } : w_id_addr;
  assign o_rw             = !w_write;
  assign o_sync           = w_id_active & id2mc_sync;

  assign mc2il_data       = il2mc_read ? i_db : 8'hxx;
  assign mc2il_brk        = w_brk & (r_operand == 3'b101);

  assign mc2rf_fetched    = w_fetch_opcode | w_fetch_next;
  assign mc2rf_pushed     = w_push_cycle;
  assign mc2rf_pull       = ((w_rts | w_rti) & ((r_operand == 3'b101) |
                                                (r_operand == 3'b100))) |
                            (!w_rts & r_pop & (r_operand == 3'b011));
  assign mc2rf_pc         = (w_jsr | w_rts | w_rti) ? r_data :
                            { i_db, r_data[15:8] };
  assign mc2rf_set_pc     = (w_jmp & ((r_operand == 3'b001) |
                                      ((r_operand == 3'b11) & w_indirect_pc))) |
                            ((w_jsr | w_rti)& (r_operand == 3'b001)) |
                            (w_rts & (r_operand == 3'b010));
  assign mc2rf_psr        = mc2rf_set_psr ? i_db : 8'hxx;
  assign mc2rf_set_psr    = w_rti & (r_operand == 3'b100);

  assign mc2id_data       = (!mc2id_valid | w_write) ? 8'hxx :
                            (!w_fetch_opcode & w_register) ? w_register_data :
                            i_db;
  assign mc2id_valid      = w_fetch_opcode | (r_operand == 3'b001);

  assign w_write          = (r_store & (r_operand == 3'b001)) |
                            ec2mc_store | w_push_cycle | il2mc_write;
  assign w_push_cycle     = (r_push & !r_jump & (r_operand == 3'b010)) |
                            (w_jsr & ((r_operand == 3'b011) |
                                      (r_operand == 3'b010)));
  assign w_pop_cycle      = r_pop & ((!r_jump & ((r_operand == 3'b010) |
                                                 (r_operand == 3'b001))) |
                                     (r_jump & ((r_operand == 3'b100) |
                                                (r_operand == 3'b011))) |
                                     (w_rti & (r_operand == 3'b010)));
  assign w_il_active      = il2mc_read | il2mc_write;
  assign w_il_addr        = il2mc_addr;

  assign w_id_active      = !w_il_active;
  assign w_id_addr        = (r_operand == 3'b000) ? rf2mc_pc :
                            w_immediate ? w_immediate_addr :
                            w_absolute ? w_absolute_addr :
                            w_abs_idx ? w_abs_idx_addr :
                            w_zero_page ? w_zero_page_addr :
                            w_zero_idx ? w_zero_idx_addr :
                            w_indirect ? w_indirect_addr : rf2mc_pc;

  assign w_1t_mode        = !id2mc_push & !id2mc_pop &
                            ((id2mc_modex & (id2mc_mode == MODEX_IMMEDIATE)) |
                             (!id2mc_modex & (id2mc_mode == MODE_IMMEDIATE)) |
                             (id2mc_modex & (id2mc_mode == MODEX_REGISTER)));
  assign w_2t_mode        = (id2mc_mode == MODE_ZERO_PAGE) |
                            ((id2mc_mode == MODEX_ABSOLUTE_PC) & id2mc_jump &
                             !id2mc_push) |
                            (id2mc_push & !id2mc_jump);
  assign w_3t_mode        = ((id2mc_mode == MODE_ABSOLUTE) & !id2mc_jump) |
                            (id2mc_pop & !id2mc_jump) |
                            (id2mc_mode == MODE_ZERO_PAGE_INDEX_X) |
                            (id2mc_mode == MODE_ABSOLUTE_INDEXED_X) |
                            (id2mc_mode == MODE_ABSOLUTE_INDEXED_Y);
  assign w_4t_mode        = id2mc_mode == MODE_INDIRECT_INDEX;
  assign w_5t_mode        = !id2mc_jump & !id2mc_modex &
                            (id2mc_mode == MODE_INDEXED_INDIRECT) |
                            (id2mc_jump & id2mc_push & !id2mc_p_reg) |
                            (id2mc_jump & id2mc_pop);
  assign w_6t_mode        = (id2mc_jump & id2mc_push & id2mc_p_reg);
  assign w_register       = r_modex & (r_mode == MODEX_REGISTER);
  assign w_immediate      = (r_modex & (r_mode == MODEX_IMMEDIATE)) |
                            (!r_modex & (r_mode == MODE_IMMEDIATE));
  assign w_absolute       = (r_mode == MODEX_ABSOLUTE) & !r_jump;
  assign w_absolute_pc    = (r_mode == MODEX_ABSOLUTE_PC) &
                            (w_jmp | (r_jump & r_push));
  assign w_indirect_pc    = (r_mode == MODEX_INDIRECT_PC) & w_jmp;
  assign w_abs_idx        = (r_mode == MODE_ABSOLUTE_INDEXED_X) |
                            (r_mode == MODE_ABSOLUTE_INDEXED_Y);
  assign w_abs_idx_x      = !r_modex && (r_mode == MODE_ABSOLUTE_INDEXED_X);
  assign w_abs_idx_y      = w_abs_idx & !w_abs_idx_x;
  assign w_zero_page      = r_mode == MODEX_ZERO_PAGE;
  assign w_zero_idx       = r_mode == MODE_ZERO_PAGE_INDEX_X;
  assign w_zero_idx_x     = !r_modex & w_zero_idx;
  assign w_zero_idx_y     = r_modex & w_zero_idx;
  assign w_indirect       = !r_modex & ((r_mode == MODE_INDEXED_INDIRECT) |
                                        (r_mode == MODE_INDIRECT_INDEX));
  assign w_indirect_x     = !r_modex & (r_mode == MODE_INDEXED_INDIRECT);
  assign w_indirect_y     = !r_modex & (r_mode == MODE_INDIRECT_INDEX);
  assign w_immediate_addr = rf2mc_pc;
  assign w_absolute_addr  = (r_operand != 3'b001) ? rf2mc_pc : r_data;
  assign w_abs_idx_addr   = ((r_operand == 3'b010) && r_carry) ? r_data :
                            (r_operand == 3'b001) ? r_data : rf2mc_pc;
  assign w_zero_page_addr = (r_operand == 3'b010) ? rf2mc_pc :
                            { 8'h00, r_data[15:8] };
  assign w_zero_idx_addr  = (r_operand == 3'b010) ? { 8'h00, r_data[15:8] } :
                            (r_operand == 3'b001) ? { 8'h00, r_data[7:0] } :
                            rf2mc_pc;
  assign w_idx_ind_addr   = (r_operand == 3'b100) ? { 8'h00, r_data[15:8] } :
                            (r_operand == 3'b011) ? { 8'h00, r_data[7:0] } :
                            (r_operand == 3'b010) ? { 8'h00, r_data[7:0] } :
                            (r_operand == 3'b001) ? { 8'h00, r_data[7:0] } :
                            rf2mc_pc;
  assign w_ind_idx_addr   = (r_operand == 3'b011) ? { 8'h00, r_data[15:8] } :
                            (r_operand == 3'b010) ? { 8'h00, r_data[7:0] } :
                            (r_operand == 3'b001) ? r_data : rf2mc_pc;
  assign w_indirect_addr  = w_indirect_x ? w_idx_ind_addr : w_ind_idx_addr;
  assign w_abs_idx_add    = w_abs_idx & (r_operand == 3'b010);
  assign w_zero_idx_add   = w_zero_idx & (r_operand == 3'b010);
  assign w_idx_ind_add    = w_indirect_x & ((r_operand == 3'b100) |
                                            (r_operand == 3'b011));
  assign w_ind_idx_add    = w_indirect_y & ((r_operand == 3'b011) |
                                            (r_operand == 3'b010));
  assign w_fetch_opcode   = w_id_active & id2mc_fetch & i_rdy;
  assign w_fetch_next     = ((w_absolute | w_abs_idx) & (r_operand == 3'b011)) |
                            (w_jmp & (r_operand == 3'b010)) |
                            (w_indirect_pc & (r_operand == 3'b100)) |
                            (w_absolute_pc & (r_operand == 3'b010)) |
                            (!w_register & !r_jump & !r_push & !r_pop &
                             (r_operand == 3'b001)) |
                            (w_brk & (r_operand == 3'b110)) |
                            (w_jsr & (r_operand == 3'b101)) |
                            (w_rts & (r_operand == 3'b001));

  assign w_adder_in_a     = (w_idx_ind_add & (r_operand == 3'b011)) ?
                                r_data[7:0] :
                            w_adder_valid ? r_data[15:8] : 8'h00;
  assign w_adder_in_b     = !w_adder_valid ? 8'h00 :
                            r_carry ? 8'h01 :
                            (w_idx_ind_add & (r_operand == 3'b011)) ? 8'h01 :
                            (w_ind_idx_add & (r_operand == 3'b011)) ? 8'h01 :
                            (w_abs_idx_x | w_zero_idx_x | w_indirect_x) ?
                                rf2mc_x : rf2mc_y;
  assign w_adder_sum      = w_adder_in_a + w_adder_in_b;
  assign w_adder_valid    = (w_abs_idx_add | w_zero_idx_add | w_idx_ind_add |
                             w_ind_idx_add);

  assign w_register_data  = (r_reg == REG_A) ? rf2mc_a :
                            (r_reg == REG_X) ? rf2mc_x :
                            (r_reg == REG_Y) ? rf2mc_y : rf2mc_s;

  assign w_jsr_data       = (r_operand == 3'b011) ? rf2mc_pc[15:8] :
                            rf2mc_pc[7:0];
  assign w_jmp            = r_jump & !r_push & !r_pop;
  assign w_jsr            = r_jump & r_push & !r_reg[0];
  assign w_brk            = r_jump & r_push & r_reg[0];
  assign w_rts            = r_jump & r_pop & !r_reg[0];
  assign w_rti            = r_jump & r_pop & r_reg[0];

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_operand <= 3'b000;
      r_modex   <= 1'b0;
      r_mode    <= 3'b000;
      r_data    <= 16'h00;
      r_reg     <= 2'b00;
      r_carry   <= 1'b0;
      r_store   <= 1'b0;
      r_push    <= 1'b0;
      r_pop     <= 1'b0;
      r_jump    <= 1'b0;
    end else if(cen) begin
      if (id2mc_operand) begin
        r_operand <= w_1t_mode ? 3'b001 :
                     w_2t_mode ? 3'b010 :
                     w_3t_mode ? 3'b011 :
                     w_4t_mode ? 3'b100 :
                     w_5t_mode ? 3'b101 :
                     w_6t_mode ? 3'b110 : 3'bxxx;
        r_modex   <= id2mc_modex;
        r_mode    <= id2mc_mode;
        r_reg     <= (id2mc_push | id2mc_pop) ? { 1'b0, id2mc_p_reg } : id2mc_reg;
        r_store   <= id2mc_store;
        r_push    <= id2mc_push;
        r_pop     <= id2mc_pop;
        r_jump    <= id2mc_jump;
      end else if (r_operand != 3'b000) begin
        if ((w_abs_idx | w_indirect_y) & w_adder_sum[8] & !r_carry) begin
          r_carry   <= 1'b1;
        end else begin
          r_operand <= r_operand - 3'b001;
          r_carry   <= 1'b0;
        end
        if (r_carry) begin
          r_data    <= { w_adder_sum[7:0], r_data[7:0] };
        end else if (w_adder_valid) begin
          r_data    <= { i_db, w_adder_sum[7:0] };
        end else if (w_jsr & ((r_operand == 3'b011) |
                              (r_operand == 3'b010))) begin
          r_data    <= r_data;
        end else if (r_operand == 3'b001) begin
          r_data    <= o_ab;
        end else begin
          r_data    <= { i_db, r_data[15:8] };
        end
      end
    end
  end
endmodule  // MC6502MemoryController
