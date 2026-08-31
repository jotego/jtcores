/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-8-2026 */

// Palette and colour output, CPU sheet 5/6. The palette RAM is external, so
// pal_data lands one pxl_cen after pal_addr -- what the jtframe_blank delay is
// sized for.

module jtsharrier_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              video_en,
    input              preLHBL,
    input              preLVBL,

    input      [15:0]  pal_data,
    input              shadow,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,
    output             LVBL,
    output             LHBL
);

wire [ 4:0] rpal, gpal, bpal;
wire [14:0] rgb;
reg  [14:0] gated;

// Resistor ladder RA9-RA12, sheet 5/6.
assign rpal = { pal_data[ 3:0], pal_data[12] };
assign gpal = { pal_data[ 7:4], pal_data[13] };
assign bpal = { pal_data[11:8], pal_data[14] };

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

// /KILL sampled once per frame, at the start of active video. The board gates
// per pixel and un-blanks mid-scanline; this is a deliberate simplification,
// taken because our CPU reaches the write ~50 lines earlier in the frame.
// Reset to 0, the value Quartus powers these up at: hardware is unchanged and
// simulation stops driving x onto RGB before the first vertical edge.
reg lvbl_l, kill_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lvbl_l <= 0;
        kill_l <= 0;
    end else if( pxl_cen ) begin
        lvbl_l <= preLVBL;
        if( preLVBL & ~lvbl_l ) kill_l <= video_en;
    end
end

// SHADE from 315-5171, sheet 6/7.
always @(*) begin
    gated = (shadow & ~pal_data[15]) ? { dim(rpal), dim(gpal), dim(bpal) } :
                                       {     rpal,      gpal,      bpal  };
    if( !kill_l ) gated = 0;
end

jtframe_blank #(.DLY(2),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( gated     ),
    .rgb_out    ( rgb       )
);

assign { red, green, blue } = rgb;

endmodule
