// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Modifications by Jose Tejada 2021
// * Remove high-Z port
// * Remove clk1 clk2 outputs
// * Added clock enable signal

module MC6502(
    clk,
    cen,
    rstn,
    i_rdy,
    i_irqn,
    i_nmin,
    i_db,
    o_db,

    o_sync,
    o_rw,
    o_ab);
  input         clk;
  input         cen;
  input         rstn;
  input         i_rdy;
  input         i_irqn;
  input         i_nmin;
  input  [ 7:0] i_db;
  output [ 7:0] o_db;
  output        o_sync;
  output        o_rw;
  output [15:0] o_ab;

  // InterruptLogic <=> MemoryController
  wire   [ 7:0] w_mc2il_data;
  wire          w_mc2il_brk;
  wire   [15:0] w_il2mc_addr;
  wire          w_il2mc_read;
  wire          w_il2mc_write;
  wire   [ 7:0] w_il2mc_data;

  // InterruptLogic <=> RegisterFile
  wire   [ 7:0] w_rf2il_s;
  wire   [ 7:0] w_rf2il_psr;
  wire   [15:0] w_rf2il_pc;
  wire          w_il2rf_set_i;
  wire          w_il2rf_set_b;
  wire   [ 7:0] w_il2rf_data;
  wire          w_il2rf_set_pcl;
  wire          w_il2rf_set_pch;
  wire          w_il2rf_pushed;

  // RegisterFile <=> MemoryController
  wire   [15:0] w_rf2mc_pc;
  wire   [ 7:0] w_rf2mc_a;
  wire   [ 7:0] w_rf2mc_x;
  wire   [ 7:0] w_rf2mc_y;
  wire   [ 7:0] w_rf2mc_s;
  wire   [ 7:0] w_rf2mc_psr;
  wire          w_mc2rf_fetched;
  wire          w_mc2rf_pushed;
  wire          w_mc2rf_pull;
  wire   [15:0] w_mc2rf_pc;
  wire          w_mc2rf_set_pc;
  wire   [ 7:0] w_mc2rf_psr;
  wire          w_mc2rf_set_psr;

  // InstructionDecode <=> MemoryController
  wire   [ 7:0] w_mc2id_data;
  wire          w_mc2id_valid;
  wire          w_id2mc_fetch;
  wire          w_id2mc_sync;
  wire          w_id2mc_operand;
  wire   [ 2:0] w_id2mc_mode;
  wire          w_id2mc_modex;
  wire   [ 1:0] w_id2mc_reg;
  wire          w_id2mc_store;
  wire          w_id2mc_push;
  wire          w_id2mc_pop;
  wire          w_id2mc_p_reg;
  wire          w_id2mc_jump;

  // InstructionDecode <=> ExecutionController
  wire          w_id2ec_reset_c;
  wire          w_id2ec_set_c;
  wire          w_id2ec_reset_i;
  wire          w_id2ec_set_i;
  wire          w_id2ec_reset_v;
  wire          w_id2ec_reset_d;
  wire          w_id2ec_set_d;
  wire          w_id2ec_load;
  wire          w_id2ec_ops;
  wire          w_id2ec_branch;
  wire   [ 4:0] w_id2ec_opcode;
  wire   [ 7:0] w_id2ec_data;
  wire   [ 1:0] w_id2ec_reg;
  wire          w_ec2id_done;

  // ExecutionController <=> RegisterFile
  wire   [ 7:0] w_rf2ec_pcl;
  wire   [ 7:0] w_rf2ec_pch;
  wire   [ 7:0] w_rf2ec_a;
  wire   [ 7:0] w_rf2ec_x;
  wire   [ 7:0] w_rf2ec_y;
  wire          w_rf2ec_c;
  wire          w_rf2ec_d;
  wire          w_rf2ec_n;
  wire          w_rf2ec_v;
  wire          w_rf2ec_z;
  wire          w_ec2rf_c;
  wire          w_ec2rf_set_c;
  wire          w_ec2rf_i;
  wire          w_ec2rf_set_i;
  wire          w_ec2rf_v;
  wire          w_ec2rf_set_v;
  wire          w_ec2rf_d;
  wire          w_ec2rf_set_d;
  wire          w_ec2rf_n;
  wire          w_ec2rf_set_n;
  wire          w_ec2rf_z;
  wire          w_ec2rf_set_z;
  wire   [ 7:0] w_ec2rf_data;
  wire          w_ec2rf_set_a;
  wire          w_ec2rf_set_x;
  wire          w_ec2rf_set_y;
  wire          w_ec2rf_set_s;
  wire          w_ec2rf_set_pcl;
  wire          w_ec2rf_set_pch;

  // ExecutionController <=> MemoryController
  wire   [ 7:0] w_ec2mc_data;
  wire          w_ec2mc_store;

  MC6502MemoryController mc(
      .clk          (clk            ),
      .cen          (cen            ),
      .rstn         (rstn           ),
      .i_rdy        (i_rdy          ),
      .i_db         (i_db           ),
      .o_db         (o_db           ),
      .o_ab         (o_ab           ),
      .o_rw         (o_rw           ),
      .o_sync       (o_sync         ),
      .il2mc_addr   (w_il2mc_addr   ),
      .il2mc_read   (w_il2mc_read   ),
      .il2mc_write  (w_il2mc_write  ),
      .il2mc_data   (w_il2mc_data   ),
      .mc2il_data   (w_mc2il_data   ),
      .mc2il_brk    (w_mc2il_brk    ),
      .rf2mc_pc     (w_rf2mc_pc     ),
      .rf2mc_a      (w_rf2mc_a      ),
      .rf2mc_x      (w_rf2mc_x      ),
      .rf2mc_y      (w_rf2mc_y      ),
      .rf2mc_s      (w_rf2mc_s      ),
      .rf2mc_psr    (w_rf2mc_psr    ),
      .mc2rf_fetched(w_mc2rf_fetched),
      .mc2rf_pushed (w_mc2rf_pushed ),
      .mc2rf_pull   (w_mc2rf_pull   ),
      .mc2rf_pc     (w_mc2rf_pc     ),
      .mc2rf_set_pc (w_mc2rf_set_pc ),
      .mc2rf_psr    (w_mc2rf_psr    ),
      .mc2rf_set_psr(w_mc2rf_set_psr),
      .id2mc_fetch  (w_id2mc_fetch  ),
      .id2mc_sync   (w_id2mc_sync   ),
      .id2mc_operand(w_id2mc_operand),
      .id2mc_mode   (w_id2mc_mode   ),
      .id2mc_modex  (w_id2mc_modex  ),
      .id2mc_reg    (w_id2mc_reg    ),
      .id2mc_store  (w_id2mc_store  ),
      .id2mc_push   (w_id2mc_push   ),
      .id2mc_pop    (w_id2mc_pop    ),
      .id2mc_p_reg  (w_id2mc_p_reg  ),
      .id2mc_jump   (w_id2mc_jump   ),
      .mc2id_data   (w_mc2id_data   ),
      .mc2id_valid  (w_mc2id_valid  ),
      .ec2mc_data   (w_ec2mc_data   ),
      .ec2mc_store  (w_ec2mc_store  ));

  MC6502InterruptLogic il(
      .clk          (clk            ),
      .cen          (cen            ),
      .rstn         (rstn           ),
      .i_irqn       (i_irqn         ),
      .i_nmin       (i_nmin         ),
      .mc2il_data   (w_mc2il_data   ),
      .mc2il_brk    (w_mc2il_brk    ),
      .il2mc_addr   (w_il2mc_addr   ),
      .il2mc_read   (w_il2mc_read   ),
      .il2mc_write  (w_il2mc_write  ),
      .il2mc_data   (w_il2mc_data   ),
      .rf2il_s      (w_rf2il_s      ),
      .rf2il_psr    (w_rf2il_psr    ),
      .rf2il_pc     (w_rf2il_pc     ),
      .il2rf_set_i  (w_il2rf_set_i  ),
      .il2rf_set_b  (w_il2rf_set_b  ),
      .il2rf_data   (w_il2rf_data   ),
      .il2rf_set_pcl(w_il2rf_set_pcl),
      .il2rf_set_pch(w_il2rf_set_pch),
      .il2rf_pushed (w_il2rf_pushed ));

  MC6502RegisterFile rf(
      .clk          (clk            ),
      .cen          (cen            ),
      .rstn         (rstn           ),
      .il2rf_set_i  (w_il2rf_set_i  ),
      .il2rf_set_b  (w_il2rf_set_b  ),
      .il2rf_data   (w_il2rf_data   ),
      .il2rf_set_pcl(w_il2rf_set_pcl),
      .il2rf_set_pch(w_il2rf_set_pch),
      .il2rf_pushed (w_il2rf_pushed ),
      .rf2il_s      (w_rf2il_s      ),
      .rf2il_psr    (w_rf2il_psr    ),
      .rf2il_pc     (w_rf2il_pc     ),
      .mc2rf_fetched(w_mc2rf_fetched),
      .mc2rf_pushed (w_mc2rf_pushed ),
      .mc2rf_pull   (w_mc2rf_pull   ),
      .mc2rf_pc     (w_mc2rf_pc     ),
      .mc2rf_set_pc (w_mc2rf_set_pc ),
      .mc2rf_psr    (w_mc2rf_psr    ),
      .mc2rf_set_psr(w_mc2rf_set_psr),
      .rf2mc_pc     (w_rf2mc_pc     ),
      .rf2mc_a      (w_rf2mc_a      ),
      .rf2mc_x      (w_rf2mc_x      ),
      .rf2mc_y      (w_rf2mc_y      ),
      .rf2mc_s      (w_rf2mc_s      ),
      .rf2mc_psr    (w_rf2mc_psr    ),
      .ec2rf_c      (w_ec2rf_c      ),
      .ec2rf_set_c  (w_ec2rf_set_c  ),
      .ec2rf_i      (w_ec2rf_i      ),
      .ec2rf_set_i  (w_ec2rf_set_i  ),
      .ec2rf_v      (w_ec2rf_v      ),
      .ec2rf_set_v  (w_ec2rf_set_v  ),
      .ec2rf_d      (w_ec2rf_d      ),
      .ec2rf_set_d  (w_ec2rf_set_d  ),
      .ec2rf_n      (w_ec2rf_n      ),
      .ec2rf_set_n  (w_ec2rf_set_n  ),
      .ec2rf_z      (w_ec2rf_z      ),
      .ec2rf_set_z  (w_ec2rf_set_z  ),
      .ec2rf_data   (w_ec2rf_data   ),
      .ec2rf_set_a  (w_ec2rf_set_a  ),
      .ec2rf_set_x  (w_ec2rf_set_x  ),
      .ec2rf_set_y  (w_ec2rf_set_y  ),
      .ec2rf_set_s  (w_ec2rf_set_s  ),
      .ec2rf_set_pcl(w_ec2rf_set_pcl),
      .ec2rf_set_pch(w_ec2rf_set_pch),
      .rf2ec_pcl    (w_rf2ec_pcl    ),
      .rf2ec_pch    (w_rf2ec_pch    ),
      .rf2ec_a      (w_rf2ec_a      ),
      .rf2ec_x      (w_rf2ec_x      ),
      .rf2ec_y      (w_rf2ec_y      ),
      .rf2ec_c      (w_rf2ec_c      ),
      .rf2ec_d      (w_rf2ec_d      ),
      .rf2ec_n      (w_rf2ec_n      ),
      .rf2ec_v      (w_rf2ec_v      ),
      .rf2ec_z      (w_rf2ec_z      ));

  MC6502InstructionDecode id(
      .clk          (clk            ),
      .cen          (cen            ),
      .rstn         (rstn           ),
      .mc2id_data   (w_mc2id_data   ),
      .mc2id_valid  (w_mc2id_valid  ),
      .id2mc_fetch  (w_id2mc_fetch  ),
      .id2mc_sync   (w_id2mc_sync   ),
      .id2mc_operand(w_id2mc_operand),
      .id2mc_mode   (w_id2mc_mode   ),
      .id2mc_modex  (w_id2mc_modex  ),
      .id2mc_reg    (w_id2mc_reg    ),
      .id2mc_store  (w_id2mc_store  ),
      .id2mc_push   (w_id2mc_push   ),
      .id2mc_pop    (w_id2mc_pop    ),
      .id2mc_p_reg  (w_id2mc_p_reg  ),
      .id2mc_jump   (w_id2mc_jump   ),
      .id2ec_reset_c(w_id2ec_reset_c),
      .id2ec_set_c  (w_id2ec_set_c  ),
      .id2ec_reset_i(w_id2ec_reset_i),
      .id2ec_set_i  (w_id2ec_set_i  ),
      .id2ec_reset_v(w_id2ec_reset_v),
      .id2ec_reset_d(w_id2ec_reset_d),
      .id2ec_set_d  (w_id2ec_set_d  ),
      .id2ec_load   (w_id2ec_load   ),
      .id2ec_ops    (w_id2ec_ops    ),
      .id2ec_branch (w_id2ec_branch ),
      .id2ec_opcode (w_id2ec_opcode ),
      .id2ec_data   (w_id2ec_data   ),
      .id2ec_reg    (w_id2ec_reg    ),
      .ec2id_done   (w_ec2id_done   ));

  MC6502ExecutionController ec(
      .clk          (clk            ),
      .cen          (cen            ),
      .rstn         (rstn           ),
      .id2ec_reset_c(w_id2ec_reset_c),
      .id2ec_set_c  (w_id2ec_set_c  ),
      .id2ec_reset_i(w_id2ec_reset_i),
      .id2ec_set_i  (w_id2ec_set_i  ),
      .id2ec_reset_v(w_id2ec_reset_v),
      .id2ec_reset_d(w_id2ec_reset_d),
      .id2ec_set_d  (w_id2ec_set_d  ),
      .id2ec_load   (w_id2ec_load   ),
      .id2ec_ops    (w_id2ec_ops    ),
      .id2ec_branch (w_id2ec_branch ),
      .id2ec_opcode (w_id2ec_opcode ),
      .id2ec_data   (w_id2ec_data   ),
      .id2ec_reg    (w_id2ec_reg    ),
      .ec2id_done   (w_ec2id_done   ),
      .rf2ec_pcl    (w_rf2ec_pcl    ),
      .rf2ec_pch    (w_rf2ec_pch    ),
      .rf2ec_a      (w_rf2ec_a      ),
      .rf2ec_x      (w_rf2ec_x      ),
      .rf2ec_y      (w_rf2ec_y      ),
      .rf2ec_c      (w_rf2ec_c      ),
      .rf2ec_d      (w_rf2ec_d      ),
      .rf2ec_n      (w_rf2ec_n      ),
      .rf2ec_v      (w_rf2ec_v      ),
      .rf2ec_z      (w_rf2ec_z      ),
      .ec2rf_c      (w_ec2rf_c      ),
      .ec2rf_set_c  (w_ec2rf_set_c  ),
      .ec2rf_i      (w_ec2rf_i      ),
      .ec2rf_set_i  (w_ec2rf_set_i  ),
      .ec2rf_v      (w_ec2rf_v      ),
      .ec2rf_set_v  (w_ec2rf_set_v  ),
      .ec2rf_d      (w_ec2rf_d      ),
      .ec2rf_set_d  (w_ec2rf_set_d  ),
      .ec2rf_n      (w_ec2rf_n      ),
      .ec2rf_set_n  (w_ec2rf_set_n  ),
      .ec2rf_z      (w_ec2rf_z      ),
      .ec2rf_set_z  (w_ec2rf_set_z  ),
      .ec2rf_data   (w_ec2rf_data   ),
      .ec2rf_set_a  (w_ec2rf_set_a  ),
      .ec2rf_set_x  (w_ec2rf_set_x  ),
      .ec2rf_set_y  (w_ec2rf_set_y  ),
      .ec2rf_set_s  (w_ec2rf_set_s  ),
      .ec2rf_set_pcl(w_ec2rf_set_pcl),
      .ec2rf_set_pch(w_ec2rf_set_pch),
      .ec2mc_data   (w_ec2mc_data   ),
      .ec2mc_store  (w_ec2mc_store  ));

endmodule  // MC6502
