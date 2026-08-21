/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-7-2026 */

module jtgals_colmix(
    input              clk,
    input              pxl_cen,
    input       [ 3:0] gfx_en,
    input              pxl_blank,
    input       [15:0] fg_data,
    input       [15:0] bg_data,
    input       [ 7:0] obj_pxl,
    input       [15:0] pal_data,
    output      [10:1] pal_addr,

    output reg  [ 4:0] red,
    output reg  [ 4:0] green,
    output reg  [ 4:0] blue
);

wire [14:0] bg_rgb = bg_data[15:1];
wire        obj_opaque = gfx_en[3] && obj_pxl[3:0] != 4'd0;
wire        fg_opaque  = gfx_en[0] && fg_data != 16'd0;
wire        bg_opaque  = gfx_en[1];
wire        pal_pixel  = obj_opaque || fg_opaque;
wire [ 9:0] pal_index  = obj_opaque ? { 2'b01, obj_pxl } : fg_data[9:0];
wire [ 4:0] blank_rgb = 5'd0;

assign pal_addr = pal_index;

always @(posedge clk) if (pxl_cen) begin
    red   <= pxl_blank ? blank_rgb : (pal_pixel ? pal_data[10:6]  : (bg_opaque ? bg_rgb[ 9:5]  : blank_rgb));
    green <= pxl_blank ? blank_rgb : (pal_pixel ? pal_data[15:11] : (bg_opaque ? bg_rgb[14:10] : blank_rgb));
    blue  <= pxl_blank ? blank_rgb : (pal_pixel ? pal_data[ 5:1]  : (bg_opaque ? bg_rgb[ 4:0]  : blank_rgb));
end

endmodule
