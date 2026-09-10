/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-11-2025 */

module jtcal50_colmix #(
    parameter SCR_EN = 0   // 1: blend the X1-001 background layer (metafox/arbalest)
)(
    input             clk,
    input             clk_cpu,
    input             pxl_cen,
    input             LHBL,
    input             LVBL,

    input      [ 8:0] scr_pxl,      // X1-001 draw_background (column-scrolled sprite BG)
    input      [ 8:0] obj_pxl, tiles_pxl,

    output reg [ 9:1] pal_addr,
    input      [15:0] pal_data,

    input      [ 7:0] debug_bus,
    input      [ 3:0] gfx_en,
    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue
);

reg  [ 8:0] col_addr;
reg  [14:0] rgb;
wire [ 8:0] obj_srt, scr_srt, bg;
wire        blank, scr_sel;
reg         obj_sel;

assign blank    = ~(LVBL & LHBL);
assign {red,green,blue} = blank ? 15'd0 : rgb;
// X1-001 pen-bit order (same for foreground sprites and the background layer)
assign obj_srt = {obj_pxl[8:4],obj_pxl[1],obj_pxl[3],obj_pxl[0],obj_pxl[2]};
assign scr_srt = {scr_pxl[8:4],scr_pxl[1],scr_pxl[3],scr_pxl[0],scr_pxl[2]};
// X1-001 background (draw_background) masks the X1-012 tiles where opaque. Only
// for SCR_EN cores; calibr50 (SCR_EN=0) keeps bg==tiles_pxl, so the mux below is
// byte-identical to before.
assign scr_sel = SCR_EN & gfx_en[1] & (scr_srt[3:0]!=4'h0);
assign bg      = scr_sel ? scr_srt : tiles_pxl;

always @* begin
    obj_sel = obj_srt[3:0] != 4'h0;
    case( {gfx_en[3],gfx_en[0]})
        2'b00: col_addr = 0;
        2'b01: col_addr = bg;
        2'b10: col_addr = obj_srt;
        2'b11: col_addr = obj_sel ? obj_srt : bg;
    endcase
end

always @(posedge clk) begin
    if( pxl_cen ) begin
        rgb <= pal_data[14:0];
        pal_addr <= col_addr;
    end
end

endmodule