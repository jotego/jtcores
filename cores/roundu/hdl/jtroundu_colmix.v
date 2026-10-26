/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             blank_n,
    input             obj_top,
    input       [6:0] text_pxl,
    input       [9:0] obj_pxl,
    input       [8:0] bg_pxl,
    input             bg_solid,
    input       [8:0] road_pxl,
    input             road_solid,
    output reg [10:1] palette_video_addr,
    input      [15:0] palette_video_data,
    output reg  [4:0] red,
    output reg  [4:0] green,
    output reg  [4:0] blue
);

reg [2:0] phase;
reg [9:0] color_addr;

always @* begin
    color_addr = bg_solid ? {obj_pxl[9],bg_pxl} : {obj_pxl[9],9'd384};
    if (road_solid) color_addr = {obj_pxl[9],road_pxl};
    if (obj_top) begin
        if (text_pxl[2:0] != 0) color_addr = {3'd0,text_pxl};
        if (obj_pxl[8]) color_addr = {2'b10,obj_pxl[7:0]};
    end else begin
        if (obj_pxl[8]) color_addr = {2'b10,obj_pxl[7:0]};
        if (text_pxl[2:0] != 0) color_addr = {3'd0,text_pxl};
    end
end

always @(posedge clk) begin
    if (rst) begin
        phase <= 0;
        palette_video_addr <= 0;
        red <= 0;
        green <= 0;
        blue <= 0;
    end else begin
        if (pxl_cen) begin
            red <= blank_n ? palette_video_data[14:10] : 5'd0;
            green <= blank_n ? palette_video_data[9:5] : 5'd0;
            blue <= blank_n ? palette_video_data[4:0] : 5'd0;
            phase <= 1;
        end else if (phase != 0) begin
            phase <= phase+1'd1;
            if (phase == 5) palette_video_addr <= color_addr;
        end
    end
end

endmodule
