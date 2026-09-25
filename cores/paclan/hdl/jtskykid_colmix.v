/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-9-2026 */

module jtskykid_colmix(
    input             clk, pxl_cen,
    input      [ 7:0] pri,

    input      [ 5:0] txt_pal,
    input      [ 3:0] txt_cat,
    input      [ 1:0] txt_pxl,
    input      [ 7:0] obj_pxl,
    input      [ 7:0] scrpal_data,

    output reg [ 7:0] rgb_addr,
    input      [ 3:0] r_data, g_data, b_data,
    output reg [ 3:0] red, green, blue,

    input      [ 3:0] gfx_en
);

wire txt_op, obj_op, txt_low, txt_hi;

assign txt_op  = txt_pxl!=0     && gfx_en[0];
assign obj_op  = obj_pxl!=8'hff && gfx_en[3];
assign txt_low = txt_op && pri[2] && txt_cat==pri[7:4];
assign txt_hi  = txt_op && !txt_low;

always @(posedge clk) if(pxl_cen) begin
    rgb_addr <= txt_hi  ? {txt_pal,txt_pxl} :
                obj_op  ? obj_pxl           :
                txt_low ? {txt_pal,txt_pxl} :
                (gfx_en[1] ? scrpal_data : 8'd0);
    {red,green,blue} <= {r_data,g_data,b_data};
end

endmodule
