/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-4-2024 */

module jts18_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              LHBL,
    input              LVBL,
    output             LHBL_dly,
    output             LVBL_dly,
    // S16B
    input              vid16_en, obj16, sa, sb, fix, s1_pri, s2_pri,
    input        [1:0] obj_prio,
    // VDP
    input              vdp_en,
    input        [2:0] vdp_prio,
    input              vdp_ysn,
    // color
    input        [3:0] gfx_en,
    input        [5:0] s16_r, s16_g, s16_b,
    input        [7:0] vdp_r, vdp_g, vdp_b,
    output       [7:0] red,   green, blue,
    //Debug
    input        [7:0] debug_bus,
    output       [7:0] st_show,
    input        [1:0] joystick1
);

wire [7:0] ex_r, ex_g, ex_b;
reg  [7:0] pr, pg, pb;
wire       vdp_blank, vdp_sel_o, obj;
reg        vdp_sel, nblnk;
reg  [4:0] tilemap_l;
reg  [1:0] obj_prio_l;

assign ex_r = {s16_r,s16_r[5:4]};
assign ex_g = {s16_g,s16_g[5:4]};
assign ex_b = {s16_b,s16_b[5:4]};
assign obj  = {tilemap_l[4:2]}==0;

always @(posedge clk) if (pxl_cen) begin
    tilemap_l  <= {sa, sb, fix, s1_pri, s2_pri};
    obj_prio_l <=  obj_prio;
    nblnk      <= {obj16, sa, sb, fix}==0;
end

always @(posedge clk) begin
    vdp_sel <= vdp_sel_o;
    if(  nblnk    ) vdp_sel <= 1;
    if( !vdp_ysn  ) vdp_sel <= 0;
    if( !vid16_en ) vdp_sel <= 1;
    if( !vdp_en   ) vdp_sel <= 0;
    pr <= vdp_sel ? vdp_r : ex_r;
    pg <= vdp_sel ? vdp_g : ex_g;
    pb <= vdp_sel ? vdp_b : ex_b;
end

jtframe_blank #(.DLY(4),.DW(24)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( LHBL      ),
    .preLVBL    ( LVBL      ),
    .LHBL       ( LHBL_dly  ),
    .LVBL       ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ( { pr,   pg,  pb} ),
    .rgb_out    ( {red,green,blue} )
);

jts18_vdp_pri_test u_vdp_test(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .debug_bus  ( debug_bus ),
    .vdp_prio   ( vdp_prio  ),
    .obj_prio   ( obj_prio_l),
    .buttons    ( joystick1 ),
    .sa         ( tilemap_l[4] ),
    .sb         ( tilemap_l[3] ),
    .fix        ( tilemap_l[2] ),
    .s1_pri     ( tilemap_l[1] ),
    .s2_pri     ( tilemap_l[0] ),
    .obj        ( obj       ),
    .LVBL       ( LVBL      ),
    .vdp_sel    ( vdp_sel_o ),
    .st_show    ( st_show   )
);

endmodule
