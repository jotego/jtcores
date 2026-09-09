/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

// layer priority and color PROMs
// galivan layers: 2=text off, 1=bg off, 0=text under sprites
// ninjemak: fixed bg < obj < text, dispen_n blanks the bg
module jtnnjema_colmix(
    input             clk,
    input             pxl_cen,

    input             m4_en,
    input      [ 2:0] layers,
    input             dispen_n,

    input      [ 7:0] char_pxl,
    input      [ 7:0] scr_pxl,
    input      [11:0] obj_pxl,

    input             LHBL,
    input             LVBL,

    // PROMs
    output     [ 7:0] objlut_addr,
    input      [ 3:0] objlut_data,
    output reg [ 7:0] red_addr,
    output     [ 7:0] green_addr,
    output     [ 7:0] blue_addr,
    input      [ 3:0] red_data,
    input      [ 3:0] green_data,
    input      [ 3:0] blue_data,

    output     [ 3:0] red,
    output     [ 3:0] green,
    output     [ 3:0] blue
);

reg  [ 7:0] char_l, scr_l;
reg  [11:0] obj_l;
reg  [ 7:0] char_pen, scr_pen, obj_pen, pen;
reg         char_op, obj_op, blank;
wire        tx_en, bg_en, tx_below;

assign tx_en    = m4_en | ~layers[2];
assign bg_en    = m4_en ? ~dispen_n : ~layers[1];
assign tx_below = ~m4_en & layers[0];
assign objlut_addr = {obj_pxl[7:4], obj_pxl[3:0]};

// stage 1: latch layer pixels along the LUT PROM readout
always @(posedge clk) begin
    char_l <= char_pxl;
    scr_l  <= scr_pxl;
    obj_l  <= obj_pxl;
end

// stage 2: pens
always @(posedge clk) begin
    char_pen <= m4_en ? {1'b0, char_l[6:4], char_l[3:0]} :
        {2'b00, char_l[3] ? char_l[7:6] : char_l[5:4], char_l[3:0]};
    scr_pen  <= !bg_en ? 8'd0 :
        {2'b11, scr_l[3] ? scr_l[7:6] : scr_l[5:4], scr_l[3:0]};
    obj_pen  <= {2'b10, obj_l[3] ? obj_l[9:8] : obj_l[11:10], objlut_data};
    char_op  <= tx_en && char_l[3:0]!=15;
    obj_op   <= obj_l[3:0]!=15;
    blank    <= ~(LHBL & LVBL);
end

// stage 3: priority
always @(posedge clk) begin
    pen <= tx_below ? (obj_op  ? obj_pen  : char_op ? char_pen : scr_pen)
                    : (char_op ? char_pen : obj_op  ? obj_pen  : scr_pen);
    red_addr <= blank ? 8'd0 : pen;
end

assign green_addr = red_addr;
assign blue_addr  = red_addr;
assign red   = red_data;
assign green = green_data;
assign blue  = blue_data;

endmodule
