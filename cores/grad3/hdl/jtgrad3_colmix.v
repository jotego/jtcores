/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-5-2026 */

// Based on the work in Gradius III schematics by Skutis
module jtgrad3_colmix(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         prio,
    input  [ 1:0] obj_pri,

    input         lhbl,
    input         lvbl,

    output reg [11:1] pal_rd_addr,
    input  [15:0] palrd_dout,

    input  [ 7:0] prog_addr,
    input  [ 3:0] prog_data,
    input         prom_pal_we,

    input         lyrf_blnk_n, // NFX
    input         lyra_blnk_n, // NVA
    input         lyrb_blnk_n, // NVB
    input         lyro_blnk_n, // NOBJ
    input  [ 7:0] lyrf_pxl,
    input  [11:0] lyra_pxl,
    input  [11:0] lyrb_pxl,
    input  [11:0] lyro_pxl,
    input         shadow,

    output [ 4:0] red,
    output [ 4:0] green,
    output [ 4:0] blue,

    input  [ 7:0] debug_bus
);

reg  [14:0] rgb;
reg  [10:0] pal_addr;
wire [ 7:0] pixel_mux;
wire [ 1:0] sel;
reg         shl;
wire        en_b, shd;

assign pixel_mux    = {prio, shadow, obj_pri,     lyrb_blnk_n,
                       lyra_blnk_n,  lyro_blnk_n, lyrf_blnk_n};
assign { red, green, blue } = (lvbl & lhbl) ? rgb : 15'd0;

function [14:0] dim( input [14:0] d );
    dim = {1'b0, d[14:11],
           1'b0, d[ 9: 6],
           1'b0, d[ 4: 1] };
endfunction

always @(*) begin
    case({sel})
        0: pal_addr[7:0] = {1'b0,lyrf_pxl[6:0]};
        1: pal_addr[7:0] = {lyro_pxl[8:5],lyro_pxl[3:0]};
        2: pal_addr[7:0] = {1'b0,lyra_pxl[6:0]};
        3: pal_addr[7:0] = {1'b0,lyrb_pxl[6:0]};
        default:;
    endcase
    pal_addr[10:8] = {en_b,sel};
end

always @(posedge clk) begin
    if(rst) begin
        pal_rd_addr <= 0;
        shl <= 0;
        rgb <= 0;
    end else if(pxl_cen) begin
        pal_rd_addr <= pal_addr;
        shl <= shd;
        rgb <= shl ? palrd_dout[14:0] : dim(palrd_dout[14:0]);
    end
end

// PROM256W4B
jtframe_prom #(.AW(8),.DW(4)) u_palette(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( prog_data      ),
    .rd_addr( pixel_mux      ),
    .wr_addr( prog_addr      ),
    .we     ( prom_pal_we    ),
    .q      ( {en_b,shd,sel} )
);

endmodule
