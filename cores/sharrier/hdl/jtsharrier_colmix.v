/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Chris Watson (niknak)
    Version: 1.0
    Date: 8-8-2026 */

// Palette and colour output, CPU sheet 5/6. The palette RAM is external, so
// pal_data lands one pxl_cen after pal_addr -- what the jtframe_blank delay is
// sized for.

module jtsharrier_colmix(
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

// SHADE from 315-5171, sheet 6/7.
always @(*) begin
    gated = (shadow & ~pal_data[15]) ? { dim(rpal), dim(gpal), dim(bpal) } :
                                       {     rpal,      gpal,      bpal  };
    if( !video_en ) gated = 0;
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
