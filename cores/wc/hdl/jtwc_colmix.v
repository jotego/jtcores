/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2024 */

module jtwc_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             prio_n,
    input      [ 6:0] obj,
    input      [ 7:0] fix,
    input      [ 7:0] scr,

    output reg [ 9:0] pal_addr,
    input      [15:0] pal_dout,

    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue,

    input      [ 3:0] gfx_en
);

localparam [2:0] OBJ = 3'b010;
localparam [1:0] SCR = 2'b10,
                 FIX = 2'b00;

wire [7:0] scr_eff = gfx_en[1] ? scr : {scr[7:4],4'd0};
wire obj_opaque = gfx_en[3] && obj[3:0]!=0;
wire fix_opaque = gfx_en[0] && fix[3:0]!=0;

always @(posedge clk) begin
    pal_addr = {SCR,scr_eff};
    if( obj_opaque && (!fix_opaque ||  prio_n)) pal_addr = {OBJ,obj};
    if( fix_opaque && (!obj_opaque || !prio_n)) pal_addr = {FIX,fix};
    if(pxl_cen) {blue,green,red} <= {pal_dout[3:0],pal_dout[15:8]}; //pal_dout[11:0];
end

endmodule
