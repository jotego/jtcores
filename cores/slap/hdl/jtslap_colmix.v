/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_colmix(
    input            clk,
    input            pxl_cen,
    input            LHBL, LVBL,
    input      [7:0] fix_pxl, scr_pxl, obj_pxl,
    output     [7:0] pal_addr,
    input      [3:0] palr_data, palg_data, palb_data,
    output     [3:0] red, green, blue,
    input      [3:0] gfx_en
);

wire blank;
reg [3:0] r, g, b;

assign blank = !LHBL || !LVBL;
assign red   = blank ? 4'd0 : r;
assign green = blank ? 4'd0 : g;
assign blue  = blank ? 4'd0 : b;
assign pal_addr = gfx_en[0] && fix_pxl[1:0]!=0 ? fix_pxl :
                  gfx_en[3] && obj_pxl[3:0]!=0 ? obj_pxl :
                  gfx_en[1]                     ? scr_pxl : 8'd0;

always @(posedge clk) if(pxl_cen) begin
    r <= palr_data;
    g <= palg_data;
    b <= palb_data;
end

endmodule
