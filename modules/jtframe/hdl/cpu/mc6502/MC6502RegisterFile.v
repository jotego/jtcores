// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502RegisterFile(
    clk,
    cen,
    rstn,
    // InterruptLogic interfaces
    il2rf_set_i,
    il2rf_set_b,
    il2rf_data,
    il2rf_set_pcl,
    il2rf_set_pch,
    il2rf_pushed,
    rf2il_s,
    rf2il_psr,
    rf2il_pc,
    // RegisterFile interfaces
    mc2rf_fetched,
    mc2rf_pushed,
    mc2rf_pull,
    mc2rf_pc,
    mc2rf_set_pc,
    mc2rf_psr,
    mc2rf_set_psr,
    rf2mc_pc,
    rf2mc_a,
    rf2mc_x,
    rf2mc_y,
    rf2mc_s,
    rf2mc_psr,
    // ExecutionController interfaces
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
    rf2ec_pcl,
    rf2ec_pch,
    rf2ec_a,
    rf2ec_x,
    rf2ec_y,
    rf2ec_c,
    rf2ec_d,
    rf2ec_n,
    rf2ec_v,
    rf2ec_z);
  input         clk;
  input         cen;
  input         rstn;

  input         il2rf_set_i;
  input         il2rf_set_b;
  input  [ 7:0] il2rf_data;
  input         il2rf_set_pcl;
  input         il2rf_set_pch;
  input         il2rf_pushed;
  output [ 7:0] rf2il_s;
  output [ 7:0] rf2il_psr;
  output [15:0] rf2il_pc;

  input         mc2rf_fetched;
  input         mc2rf_pushed;
  input         mc2rf_pull;
  input  [15:0] mc2rf_pc;
  input         mc2rf_set_pc;
  input  [ 7:0] mc2rf_psr;
  input         mc2rf_set_psr;
  output [15:0] rf2mc_pc;
  output [ 7:0] rf2mc_a;
  output [ 7:0] rf2mc_x;
  output [ 7:0] rf2mc_y;
  output [ 7:0] rf2mc_s;
  output [ 7:0] rf2mc_psr;

  input         ec2rf_c;
  input         ec2rf_set_c;
  input         ec2rf_i;
  input         ec2rf_set_i;
  input         ec2rf_v;
  input         ec2rf_set_v;
  input         ec2rf_d;
  input         ec2rf_set_d;
  input         ec2rf_n;
  input         ec2rf_set_n;
  input         ec2rf_z;
  input         ec2rf_set_z;
  input  [ 7:0] ec2rf_data;
  input         ec2rf_set_a;
  input         ec2rf_set_x;
  input         ec2rf_set_y;
  input         ec2rf_set_s;
  input         ec2rf_set_pcl;
  input         ec2rf_set_pch;
  output [ 7:0] rf2ec_pcl;
  output [ 7:0] rf2ec_pch;
  output [ 7:0] rf2ec_a;
  output [ 7:0] rf2ec_x;
  output [ 7:0] rf2ec_y;
  output        rf2ec_c;
  output        rf2ec_d;
  output        rf2ec_n;
  output        rf2ec_v;
  output        rf2ec_z;

  reg    [ 7:0] r_pcl;
  reg    [ 7:0] r_pch;
  reg    [ 7:0] r_a;
  reg    [ 7:0] r_x;
  reg    [ 7:0] r_y;
  reg    [ 7:0] r_sp;

  wire          w_load_pc;
  wire   [15:0] w_next_pc;
  wire   [ 7:0] w_psr;

  wire          w_c;
  wire          w_i;
  wire          w_v;
  wire          w_d;
  wire          w_n;
  wire          w_z;
  wire          w_b;
  wire          w_set_c;
  wire          w_set_i;
  wire          w_set_v;
  wire          w_set_d;
  wire          w_set_n;
  wire          w_set_z;
  wire          w_set_b;

  assign rf2il_s   = r_sp;
  assign rf2il_psr = w_psr;
  assign rf2il_pc  = { r_pch, r_pcl };

  assign rf2mc_pc  = { r_pch, r_pcl };
  assign rf2mc_a   = r_a;
  assign rf2mc_x   = r_x;
  assign rf2mc_y   = r_y;
  assign rf2mc_s   = r_sp;
  assign rf2mc_psr = w_psr;
  assign rf2ec_pcl = r_pcl;
  assign rf2ec_pch = r_pch;
  assign rf2ec_a   = r_a;
  assign rf2ec_x   = r_x;
  assign rf2ec_y   = r_y;
  assign rf2ec_c   = w_psr[0];
  assign rf2ec_d   = w_psr[3];
  assign rf2ec_n   = w_psr[7];
  assign rf2ec_v   = w_psr[6];
  assign rf2ec_z   = w_psr[1];

  assign w_load_pc = il2rf_set_pcl | il2rf_set_pch |
                     ec2rf_set_pcl | ec2rf_set_pch;
  assign w_next_pc = { r_pch, r_pcl } + 16'h0001;

  assign w_c       = ec2rf_set_c ? ec2rf_c : mc2rf_psr[0];
  assign w_set_c   = ec2rf_set_c | mc2rf_set_psr;
  assign w_i       = ec2rf_set_i ? ec2rf_i : il2rf_set_i ? 1'b1 : mc2rf_psr[2];
  assign w_set_i   = ec2rf_set_i | mc2rf_set_psr | il2rf_set_i;
  assign w_v       = ec2rf_set_v ? ec2rf_v : mc2rf_psr[6];
  assign w_set_v   = ec2rf_set_v | mc2rf_set_psr;
  assign w_d       = ec2rf_set_d ? ec2rf_d : mc2rf_psr[3];
  assign w_set_d   = ec2rf_set_d | mc2rf_set_psr;
  assign w_n       = ec2rf_set_n ? ec2rf_n : mc2rf_psr[7];
  assign w_set_n   = ec2rf_set_n | mc2rf_set_psr;
  assign w_z       = ec2rf_set_z ? ec2rf_z : mc2rf_psr[1];
  assign w_set_z   = ec2rf_set_z | mc2rf_set_psr;
  assign w_b       = il2rf_set_b ? 1'b1 : mc2rf_psr[4];
  assign w_set_b   = mc2rf_set_psr | il2rf_set_b;

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_pcl <= 8'h00;
      r_pch <= 8'h00;
      r_a   <= 8'h00;
      r_x   <= 8'h00;
      r_y   <= 8'h00;
      r_sp  <= 8'h00;
    end else if(cen) begin
      if (w_load_pc) begin
        if (il2rf_set_pcl) begin
          r_pcl <= il2rf_data;
        end else if (ec2rf_set_pcl) begin
          r_pcl <= ec2rf_data;
        end
        if (il2rf_set_pch) begin
          r_pch <= il2rf_data;
        end else if (ec2rf_set_pch) begin
          r_pch <= ec2rf_data;
        end
      end else begin
        if (mc2rf_fetched) begin
          r_pch <= w_next_pc[15:8];
          r_pcl <= w_next_pc[ 7:0];
        end else if (mc2rf_set_pc) begin
          r_pch <= mc2rf_pc[15:8];
          r_pcl <= mc2rf_pc[ 7:0];
        end
      end  // else (w_load_pc)
      if (ec2rf_set_a) begin
        r_a   <= ec2rf_data;
      end
      if (ec2rf_set_x) begin
        r_x   <= ec2rf_data;
      end
      if (ec2rf_set_y) begin
        r_y   <= ec2rf_data;
      end
      if (ec2rf_set_s) begin
        r_sp  <= ec2rf_data;
      end else if (mc2rf_pushed | il2rf_pushed) begin
        r_sp  <= r_sp - 8'h01;
      end else if (mc2rf_pull) begin
        r_sp  <= r_sp + 8'h01;
      end
    end
  end  // always @ (posedge clk or negedge rstn)

  MC6502ProcessorStatusRegister ps(
      .clk    (clk    ),
      .cen    (cen    ),
      .rstn   (rstn   ),
      .i_c    (w_c    ),
      .i_set_c(w_set_c),
      .i_i    (w_i    ),
      .i_set_i(w_set_i),
      .i_v    (w_v    ),
      .i_set_v(w_set_v),
      .i_d    (w_d    ),
      .i_set_d(w_set_d),
      .i_n    (w_n    ),
      .i_set_n(w_set_n),
      .i_z    (w_z    ),
      .i_set_z(w_set_z),
      .i_b    (w_b    ),
      .i_set_b(w_set_b),
      .o_psr  (w_psr  ));
endmodule  // MC6502RegisterFile
