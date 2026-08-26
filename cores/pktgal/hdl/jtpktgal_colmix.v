/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-7-2026 */

module jtpktgal_colmix(
    input             LHBL,
    input             LVBL,
    input      [ 7:0] tile_pxl,
    input      [ 4:0] obj_pxl,
    output     [ 8:0] promrg_addr,
    input      [ 7:0] promrg_data,
    output     [ 8:0] promb_addr,
    input      [ 7:0] promb_data,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,
    input      [ 3:0] gfx_en
);

wire       blank, obj_opaque, color_en;
wire [ 8:0] prom_addr;
wire [ 7:0] red_full, green_full, blue_full;

assign blank      = ~LHBL | ~LVBL;
assign obj_opaque = gfx_en[3] && obj_pxl[1:0] != 2'd0;
assign color_en   = obj_opaque || gfx_en[0];
assign prom_addr  = obj_opaque ? {4'd0, obj_pxl} : {1'b1, tile_pxl};
assign promrg_addr = prom_addr;
assign promb_addr  = prom_addr;

assign red_full   = ({8{promrg_data[0]}} & 8'h0e) +
                    ({8{promrg_data[1]}} & 8'h1f) +
                    ({8{promrg_data[2]}} & 8'h43) +
                    ({8{promrg_data[3]}} & 8'h8f);
assign green_full = ({8{promrg_data[4]}} & 8'h0e) +
                    ({8{promrg_data[5]}} & 8'h1f) +
                    ({8{promrg_data[6]}} & 8'h43) +
                    ({8{promrg_data[7]}} & 8'h8f);
assign blue_full  = ({8{promb_data[0]}} & 8'h0e) +
                    ({8{promb_data[1]}} & 8'h1f) +
                    ({8{promb_data[2]}} & 8'h43) +
                    ({8{promb_data[3]}} & 8'h8f);

assign red   = blank || !color_en ? 8'd0 : red_full;
assign green = blank || !color_en ? 8'd0 : green_full;
assign blue  = blank || !color_en ? 8'd0 : blue_full;

endmodule
