/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-11-2026 */

module jtshdfrc_colmix(
    input                clk,
    input                pxl_cen,
    input                video_en,
    input         [ 3:0] gfx_en,
    input         [ 7:0] brt,

    input         [ 7:0] lfg,
    input         [ 9:0] lbg1,
    input         [10:0] lbg0, lobj,

    output reg    [14:1] pal_rd_addr,
    input         [15:0] pal_rd_data,
    output reg    [ 7:0] red, green, blue
);

reg        cen_d1, mix_go, pal_go, pal_w, rgb_go;
reg [13:0] pidx;
reg        blank_px;
wire       op0  = lbg0[5:0] != 0;
wire       sopq = lobj[4:0] != 0;
wire [7:0] r8 = { pal_rd_data[ 4: 0], pal_rd_data[ 4: 2] };
wire [7:0] g8 = { pal_rd_data[ 9: 5], pal_rd_data[ 9: 7] };
wire [7:0] b8 = { pal_rd_data[14:10], pal_rd_data[14:12] };
wire [15:0] rm = r8 * brt, gm = g8 * brt, bm = b8 * brt;

function [7:0] div255(input [15:0] x);
    div255 = x[15:8] + { 7'd0, x[7:0] >= ~x[15:8] };
endfunction

always @(posedge clk) begin
    cen_d1 <= pxl_cen;
    mix_go <= cen_d1;
    pal_go <= mix_go;
    pal_w  <= pal_go;
    rgb_go <= pal_w;
    if( mix_go ) begin
        pidx <= { 2'b11, 2'b00, lbg1[9:6], lbg1[5:0] };
        if( op0 && gfx_en[1] )
            pidx <= { 2'b10, lbg0[10], 1'b0, lbg0[9:6], lbg0[5:0] };
        if( sopq && !(lobj[10] && op0) && gfx_en[3] )
            pidx <= { 2'b01, lobj[9], 1'b0, lobj[8:5], 1'b0, lobj[4:0] };
        if( lfg[3:0]!=0 && gfx_en[0] )
            pidx <= { 4'b0000, lfg[7:4], 2'b00, lfg[3:0] };
        blank_px <= !video_en || !gfx_en[2];
    end
    if( pal_go ) pal_rd_addr <= pidx;
    if( rgb_go ) begin
        red   <= blank_px ? 8'd0 : div255( rm );
        green <= blank_px ? 8'd0 : div255( gm );
        blue  <= blank_px ? 8'd0 : div255( bm );
    end
end

endmodule
