/* SPDX-License-Identifier: GPL-3.0-or-later */

// Moo K1 input boundary.  The five CI groups are not interchangeable.
// K053251 accepts F as 4 colour plus 5 palette bits, and A/B as
// 4 colour plus 4 palette bits.
module jtmoomsa_k053251_map(
    input      [7:0] direct_pxl,
    input      [8:0] f_pxl,
    input      [7:0] a_pxl,
    input      [7:0] b_pxl,
    input      [8:0] object_pxl,
    output     [8:0] ci0,
    output     [8:0] ci1,
    output     [8:0] ci2,
    output     [7:0] ci3,
    output     [7:0] ci4,
    output     [10:0] direct_palette,
    output            direct_opaque
);

assign ci0 = object_pxl;
assign ci1 = 9'd0;
assign ci2 = f_pxl;
assign ci3 = a_pxl;
assign ci4 = b_pxl;

assign direct_palette = {3'b111,direct_pxl};
assign direct_opaque  = |direct_pxl[3:0];

endmodule
