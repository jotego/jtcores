/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-5-2025 */

module jtpaclan_colmix(
    input             clk,
    input             pxl_cen, pxl2_cen, fixed,
    input      [ 1:0] palbank,

    input      [ 9:0] scr0_pxl, scr1_pxl,
    input      [ 7:0] obj_pxl,
    input             scr0_prio,

    output     [ 9:0] scr0pal_addr, scr1pal_addr,
    input      [ 7:0] scr0pal_data, scr1pal_data,

    output reg [ 9:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,

    input      [ 3:0] gfx_en,
    output reg [ 3:0] red, green, blue
);

// background (scr1)
// sprites 00~7F
// foreground low prio (scr0)
// sprites, all but 7F (lantern), FF (no sprite)
// foreground high prio (scr0)
// sprites F0~FE

localparam [6:0] ALPHA=7'h7f;

reg  [7:0] scr_pal;
reg        scrwin, scr1win;
wire       scr0_op, obj0_op, obj1_op, obj2_op, obj3_op;

assign scr0pal_addr = scr0_pxl;
assign scr1pal_addr = scr1_pxl;

assign scr0_op = scr0pal_data[6:0]!=ALPHA && gfx_en[0]; // foreground
assign obj0_op = obj_pxl<8'h80;
assign obj1_op = obj_pxl[6:0]!=ALPHA;
assign obj2_op = obj_pxl>=8'hf0 && obj_pxl!=8'hff;
assign obj3_op = obj0_op & ~obj1_op;

always @(posedge clk) begin
    scr_pal <= (scr1win ? scr1pal_data : scr0pal_data);
end

always @* begin
    scr1win = ~scr0_op && gfx_en[1];
    scrwin = 1;
    if(gfx_en[3]) begin
        if(obj0_op && scr1win) scrwin=0;
        if(obj1_op && (scr1win || !scr0_prio)) scrwin = 0;
        if(obj2_op) scrwin = 0;
        if(obj3_op) {scr1win,scrwin} = {scr0_op,1'b1};
    end
end

always @(posedge clk) if(pxl_cen) begin
    rgb_addr[9:8] <= palbank;
    rgb_addr[7:0] <= scrwin ? scr_pal : obj_pxl;
    {green,red,blue} <= {rg_data,b_data[3:0]};
end

endmodule    