/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-5-2025 */

module jtmetrox_colmix(
    input             clk,
    input             pxl_cen,
    input      [ 8:0] hdump, vdump,

    input      [10:0] scr0_pxl, obj_pxl,
    input      [ 2:0] obj_prio,
    input             scr0_front,   // front tilemap is opaque at this pixel
    input      [ 8:0] txt_pxl,

    output reg [10:0] rgb_addr,
    input      [ 7:0] bg_data, r_data,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 3:0] red, green, blue
);

localparam [2:0] ALPHA=7;
localparam [3:0] OALPHA=15;
localparam [1:0] OBJ=2'b01;

wire       txt_op, obj_op, obj_win;

assign txt_op = txt_pxl[1:0]!= ALPHA[1:0] && gfx_en[0];
assign obj_op = obj_pxl[3:0]!=OALPHA      && gfx_en[3];
// baraduke.cpp draws the sprites with pri_mask = priority ? 0 : GFX_PMASK_2, so
// a sprite with priority 0 hides behind the front tilemap but not the back one
assign obj_win = obj_op && (obj_prio[0] || !scr0_front);

always @(posedge clk) if(pxl_cen) begin
    rgb_addr <= txt_op ? {txt_pxl[8:2],2'd0,txt_pxl[1:0]} :
                obj_win ? obj_pxl : scr0_pxl;
    {blue,green,red} <= {bg_data,r_data[3:0]};
end

endmodule
