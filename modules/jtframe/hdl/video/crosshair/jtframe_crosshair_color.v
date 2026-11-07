/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-02-2025 */

module jtframe_crosshair_color #(parameter COLORW=4)(
    input                 clk,
    input                 draw_en,
    input                 hs_in,  vs_in,
    output reg            hs_out, vs_out,
    input  [         2:0] cross_disable,
    input  [         5:0] crosshair,
    input  [  COLORW-1:0] rin,
    input  [  COLORW-1:0] gin,
    input  [  COLORW-1:0] bin,
    output [3*COLORW-1:0] rgb_cross
    );

reg  [COLORW-1:0] r_cross, g_cross, b_cross;
wire [       2:0] ch_col, ch_black;

assign rgb_cross = {r_cross, g_cross, b_cross};
assign ch_col    = {crosshair[4],crosshair[2],crosshair[0]} & ~cross_disable;
assign ch_black  = {crosshair[5],crosshair[3],crosshair[1]} & ~cross_disable;

always @(posedge clk) begin
    {hs_out, vs_out} <= {hs_in, vs_in};
    if(draw_en) begin
        r_cross <= |ch_col ? {COLORW{ch_col[0]}} : rin;
        g_cross <= |ch_col ? {COLORW{ch_col[1]}} : gin;
        b_cross <= |ch_col ? {COLORW{ch_col[2]}} : bin;
        if(ch_black!=0)
            {r_cross, g_cross, b_cross} <= 0;
    end else begin 
        r_cross <= rin;
        g_cross <= gin;
        b_cross <= bin;
    end
end

endmodule
