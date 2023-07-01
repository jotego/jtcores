// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

module MC6502Accumulator(
    i_a,
    i_m,
    i_c,
    i_d,
    i_s,
    o_a,
    o_n,
    o_z,
    o_c,
    o_v);
  input  [7:0] i_a;
  input  [7:0] i_m;
  input        i_c;
  input        i_d;
  input        i_s;
  output [7:0] o_a;
  output       o_n;
  output       o_z;
  output       o_c;
  output       o_v;

  wire   [7:0] w_m;
  wire   [4:0] w_bsum_lo;
  wire   [4:0] w_dsum_lo;
  wire   [4:0] w_bsum_hi;
  wire   [4:0] w_dsum_hi;
  wire   [4:0] w_sum_low;
  wire   [4:0] w_sum_high;
  wire         w_dover_lo;
  wire         w_carry;
  wire   [3:0] w_fix;

  assign w_m        = i_s ? ~i_m : i_m;
  assign w_fix      = i_s ? 4'ha : 4'h6;
  assign w_bsum_lo  = i_a[3:0] + w_m[3:0] + { 3'b000, i_c };
  assign w_dover_lo = w_bsum_lo > 5'h9;
  assign w_dsum_lo  = w_dover_lo ? (w_bsum_lo + w_fix) : w_bsum_lo;
  assign w_sum_low  = i_d ? w_dsum_lo : w_bsum_lo;
  assign w_carry    = i_d ? w_dover_lo ^ i_s : w_sum_low[4];
  assign w_bsum_hi  = i_a[7:4] + w_m[7:4] + { 3'b000, w_carry };
  assign w_dsum_hi  = (w_bsum_hi[3:0] < 4'ha) ? w_bsum_hi : (w_bsum_hi + w_fix);
  assign w_sum_high = i_d ? w_dsum_hi : w_bsum_hi;
  assign o_a        = { w_sum_high[3:0], w_sum_low[3:0] };
  assign o_n        = o_a[7];
  assign o_z        = o_a == 8'h00;
  assign o_c        = w_sum_high[4];
  assign o_v        = (!(i_a[7] ^ w_m[7]) & (i_a[7] ^ o_a[7]));
endmodule  // MC6502Accumulator
