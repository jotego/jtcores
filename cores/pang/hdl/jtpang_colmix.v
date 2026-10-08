/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-5-2022 */

module jtpang_colmix(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             LHBL,
    input             LVBL,
    input             video_en,

    input      [ 7:0] obj_pxl,
    input      [10:0] ch_pxl,

    input             pal_bank,
    input             pal_cs,
    input             wr_n,
    input      [10:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] pal_dout,

    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue
);

reg  [10:0] pal_a;
wire [11:0] pal_wa;
wire [ 7:0] col_half;
reg         half;
reg  [ 3:0] nr,ng,nb;
wire        obj_blank, pal_we;

assign pal_we    = pal_cs & ~wr_n & ~video_en;
assign obj_blank = &obj_pxl[3:0];
assign pal_wa    = { cpu_addr[0], pal_bank, cpu_addr[10:1] };

always @(posedge clk) begin
    half <= ~half;
    if( pxl_cen ) begin
        half <= 0;
        { red, green, blue } <= (!LVBL || !LHBL || !video_en ) ? 12'd0 : { nr, ng, nb };
        // This is what the circuit suggests but this doesn't work well:
        // pal_a <= &ch_pxl[3:0] ? 11'd0 :
        //             obj_blank ? ch_pxl : { 3'h0, obj_pxl };
        pal_a <= obj_blank ? ( &ch_pxl[3:0] ? 11'd0 : ch_pxl ) : { 3'h0, obj_pxl };
    end
    if( half )
        { ng, nb } <= col_half;
    else
        nr <= col_half[3:0];
end

jtframe_dual_ram #(.AW(12)) u_dual_ram (
    // CPU
    .clk0  ( clk        ),
    .data0 ( cpu_dout   ),
    .addr0 ( pal_wa     ),
    .we0   ( pal_we     ),
    .q0    ( pal_dout   ),
    // video
    .clk1  ( clk        ),
    .data1 ( 8'd0       ),
    .addr1 ( { half, pal_a } ),
    .we1   ( 1'b0       ),
    .q1    ( col_half   )
);

endmodule