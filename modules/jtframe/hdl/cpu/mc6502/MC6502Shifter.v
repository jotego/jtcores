// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502Shifter(
    i_data,
    i_rotate,
    i_right,
    i_c,
    o_data,
    o_n,
    o_z,
    o_c);
  input  [7:0] i_data;
  input        i_rotate;
  input        i_right;
  input        i_c;
  output [7:0] o_data;
  output       o_n;
  output       o_z;
  output       o_c;

  wire   [8:0] w_to_left;
  wire   [8:0] w_to_right;

  assign o_data     = i_right ? w_to_right[8:1] : w_to_left[7:0];
  assign o_n        = o_data[7];
  assign o_z        = o_data == 8'h00;
  assign o_c        = i_right ? w_to_right[0] : w_to_left[8];

  assign w_to_left  = { i_data, i_rotate ? i_c : 1'b0 };
  assign w_to_right = { i_rotate ? i_c : 1'b0, i_data };
endmodule  // MC6502Shifter
