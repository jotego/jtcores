// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO: NMI and IRQ handling is not correct. It should push PC and PSR to
// stack, and follow timing constraint. It must be realized by collaboration
// with the core sequencer.
module MC6502InterruptLogic(
    clk,
    cen,
    rstn,
    i_irqn,
    i_nmin,
    // MemoryController interfaces.
    mc2il_data,
    mc2il_brk,
    il2mc_addr,
    il2mc_read,
    il2mc_write,
    il2mc_data,
    // RegisterFile interfaces.
    rf2il_s,
    rf2il_psr,
    rf2il_pc,
    il2rf_set_i,
    il2rf_set_b,
    il2rf_data,
    il2rf_set_pcl,
    il2rf_set_pch,
    il2rf_pushed);
  input         clk;
  input         cen;
  input         rstn;
  input         i_irqn;
  input         i_nmin;

  input  [ 7:0] mc2il_data;
  input         mc2il_brk;
  output [15:0] il2mc_addr;
  output        il2mc_read;
  output        il2mc_write;
  output [ 7:0] il2mc_data;

  input  [ 7:0] rf2il_s;
  input  [ 7:0] rf2il_psr;
  input  [15:0] rf2il_pc;
  output        il2rf_set_i;
  output        il2rf_set_b;
  output [ 7:0] il2rf_data;
  output        il2rf_set_pcl;
  output        il2rf_set_pch;
  output        il2rf_pushed;

  reg    [ 1:0] r_res_state;
  reg    [ 1:0] r_int_state;
  reg    [ 1:0] r_vector;

  wire          w_read_pcl;
  wire          w_read_pch;

  localparam VECTOR_NMI = 2'b01;
  localparam VECTOR_RES = 2'b10;
  localparam VECTOR_IRQ = 2'b11;
  localparam VECTOR_BRK = 2'b11;

  localparam S_RES_IDLE     = 2'b00;
  localparam S_RES_LOAD_PCL = 2'b01;
  localparam S_RES_LOAD_PCH = 2'b11;

  localparam S_INT_IDLE     = 2'b00;
  localparam S_INT_PUSH_PCL = 2'b01;
  localparam S_INT_PUSH_PSR = 2'b10;

  assign il2mc_addr    = il2mc_write ? { 8'h01, rf2il_s } :
                         { 12'hfff, 1'b1, r_vector, w_read_pch };
  assign il2mc_read    = w_read_pcl | w_read_pch;
  assign il2mc_write   = mc2il_brk | (r_int_state == S_INT_PUSH_PCL) |
                         (r_int_state == S_INT_PUSH_PSR);
  assign il2mc_data    = mc2il_brk ? rf2il_pc[15:8] :
                         (r_int_state == S_INT_PUSH_PCL) ? rf2il_pc[7:0] :
                         (r_int_state == S_INT_PUSH_PSR) ? rf2il_psr :
                          8'hxx;
  assign il2rf_set_i   = (r_int_state == S_INT_PUSH_PSR) | !i_irqn | !i_nmin;
  assign il2rf_set_b   = r_int_state == S_INT_PUSH_PSR;
  assign il2rf_data    = mc2il_data;
  assign il2rf_set_pcl = w_read_pcl;
  assign il2rf_set_pch = w_read_pch;
  assign il2rf_pushed  = il2mc_write;

  assign w_read_pcl    = r_res_state == S_RES_LOAD_PCL;
  assign w_read_pch    = r_res_state == S_RES_LOAD_PCH;

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_res_state  <= S_RES_LOAD_PCL;
      r_vector     <= VECTOR_RES;
    end else if(cen) begin
      case (r_res_state)
        S_RES_IDLE: begin
          if (!i_irqn | (r_int_state == S_INT_PUSH_PSR)) begin
            r_res_state  <= S_RES_LOAD_PCL;
            r_vector     <= VECTOR_IRQ;
          end else if (!i_nmin) begin
            r_res_state  <= S_RES_LOAD_PCL;
            r_vector     <= VECTOR_NMI;
          end
        end
        S_RES_LOAD_PCL: begin
          r_res_state  <= S_RES_LOAD_PCH;
        end
        S_RES_LOAD_PCH: begin
          r_res_state  <= S_RES_IDLE;
        end
        default:;
      endcase  // r_res_state
    end
  end  // always @ (posedge clk or negedge rstn)

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_int_state <= S_INT_IDLE;
    end else if(cen) begin
      case (r_int_state)
        S_INT_IDLE: begin
          if (mc2il_brk) begin
            r_int_state <= S_INT_PUSH_PCL;
          end
        end
        S_INT_PUSH_PCL: begin
          r_int_state <= S_INT_PUSH_PSR;
        end
        S_INT_PUSH_PSR: begin
          r_int_state <= S_INT_IDLE;
        end
        default:;
      endcase  // r_int_state
    end
  end  // always @ (posedge clk or negedge rstn)
endmodule  // MC6502InterruptLogic
