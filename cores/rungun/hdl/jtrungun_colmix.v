/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-7-2025 */

module jtrungun_colmix(
    input             lrsw, pri,

    // Final pixels
    input      [ 1:0] shadow,
    input      [ 8:0] obj_pxl,
    input      [ 7:0] fix_pxl, psc_pxl,

    // frame buffer
    output     [15:0] pxl,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

localparam [ 1:0] FIX =2'b00, PSC=2'b01;
localparam [10:0] BACK=11'h7ff;
localparam [ 0:0] OBJ =1'b1;

wire        shad, fix_op, psc_op, obj_op, obj_wins;

assign fix_op     = fix_pxl[3:0]!=0 && gfx_en[0];
assign psc_op     = psc_pxl[3:0]!=0;
assign obj_op     = obj_pxl[3:0]!=0;
assign obj_wins   = (!psc_op && obj_op ) || (!pri && obj_op);
assign pxl[15:11] = {4'd0,lrsw};
assign pxl[10: 0] =  fix_op ? {FIX, fix_pxl, 1'b0} :
                   obj_wins ? {OBJ, obj_pxl, 1'b0} :
                     psc_op ? {PSC, psc_pxl, shad} : BACK;

assign shad = |shadow & gfx_en[3];

endmodule
