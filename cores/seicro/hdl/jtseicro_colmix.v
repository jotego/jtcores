/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_colmix(
    input             clk, pxl_cen,
    input             hblankn, vblankn,
    input       [7:0] scr_pxl, obj_pxl,
    input       [3:0] gfx_en,
    output      [5:0] pal_addr,
    input       [7:0] pal_data,
    output reg  [3:0] red, green, blue,
    output reg        LHBL, LVBL
);

wire obj_visible = gfx_en[3] && obj_pxl[1:0]!=0;
wire scr_visible = gfx_en[0] && scr_pxl[1:0]!=0;
wire pixel_visible = obj_visible || scr_visible;
wire [7:0] color = obj_visible ? obj_pxl : scr_pxl;
reg [3:0] cen_dly;
wire [7:0] r = (pal_data[0] ? 8'h21 : 8'd0) +
               (pal_data[1] ? 8'h47 : 8'd0) +
               (pal_data[2] ? 8'h97 : 8'd0);
wire [7:0] g = (pal_data[3] ? 8'h21 : 8'd0) +
               (pal_data[4] ? 8'h47 : 8'd0) +
               (pal_data[5] ? 8'h97 : 8'd0);
wire [7:0] b = (pal_data[6] ? 8'h52 : 8'd0) +
               (pal_data[7] ? 8'had : 8'd0);

assign pal_addr = pixel_visible ? {color[7:4],color[1:0]} : 6'd0;

always @(posedge clk) begin
    cen_dly <= {cen_dly[2:0],pxl_cen};
    if(cen_dly[3]) begin
        LHBL <= hblankn;
        LVBL <= vblankn;
        red <= hblankn && vblankn && pixel_visible ? r[7:4] : 4'd0;
        green <= hblankn && vblankn && pixel_visible ? g[7:4] : 4'd0;
        blue <= hblankn && vblankn && pixel_visible ? b[7:4] : 4'd0;
    end
end

endmodule
