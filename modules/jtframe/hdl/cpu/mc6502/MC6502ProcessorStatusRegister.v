// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502ProcessorStatusRegister(
    clk,
    cen,
    rstn,
    i_c,
    i_set_c,
    i_i,
    i_set_i,
    i_v,
    i_set_v,
    i_d,
    i_set_d,
    i_n,
    i_set_n,
    i_z,
    i_set_z,
    i_b,
    i_set_b,
    o_psr);

  input        clk;
  input        cen;
  input        rstn;
  input        i_c;
  input        i_set_c;
  input        i_i;
  input        i_set_i;
  input        i_v;
  input        i_set_v;
  input        i_d;
  input        i_set_d;
  input        i_n;
  input        i_set_n;
  input        i_z;
  input        i_set_z;
  input        i_b;
  input        i_set_b;
  output [7:0] o_psr;

  reg          r_n;
  reg          r_v;
  reg          r_b;
  reg          r_d;
  reg          r_i;
  reg          r_z;
  reg          r_c;

  assign o_psr = { r_n, r_v, 1'b1, r_b, r_d, r_i, r_z, r_c };

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      r_n <= 1'b0;
      r_v <= 1'b0;
      r_b <= 1'b0;
      r_d <= 1'b0;
      r_i <= 1'b0;
      r_z <= 1'b0;
      r_c <= 1'b0;
    end else if(cen) begin
      if (i_set_c) begin
        r_c <= i_c;
      end
      if (i_set_i) begin
        r_i <= i_i;
      end
      if (i_set_v) begin
        r_v <= i_v;
      end
      if (i_set_d) begin
        r_d <= i_d;
      end
      if (i_set_n) begin
        r_n <= i_n;
      end
      if (i_set_z) begin
        r_z <= i_z;
      end
      if (i_set_b) begin
        r_b <= i_b;
      end
    end
  end
endmodule  // MC6502ProcessorStatusRegister
