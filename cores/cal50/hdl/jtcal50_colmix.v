/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-11-2025 */

module jtcal50_colmix(
    input             clk,
    input             clk_cpu,
    input             pxl_cen,
    input             LHBL,
    input             LVBL,

    input      [ 8:0] scr_pxl,      // unused ?
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
wire [ 8:0] obj_srt;
wire        blank;
reg         obj_sel;

assign blank    = ~(LVBL & LHBL);
assign {red,green,blue} = blank ? 15'd0 : rgb;
assign obj_srt = {obj_pxl[8:4],obj_pxl[1],obj_pxl[3],obj_pxl[0],obj_pxl[2]};

always @* begin
    obj_sel = obj_srt[3:0] != 4'h0;
    case( {gfx_en[3],gfx_en[0]})
        2'b00: col_addr = 0;
        2'b01: col_addr = tiles_pxl;
        2'b10: col_addr = obj_srt;
        2'b11: col_addr = obj_sel ? obj_srt : tiles_pxl; // simple priority for now.
    endcase
end

always @(posedge clk) begin
    if( pxl_cen ) begin
        rgb <= pal_data[14:0];
        pal_addr <= col_addr;
    end
end

endmodule