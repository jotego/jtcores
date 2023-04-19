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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-3-2021 */

module jts16_colmix(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,

    input              preLHBL,
    input              preLVBL,

    // CPU interface
    input              pal_cs,
    input      [11:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    input      [10:0]  pal_addr,
    input              shadow,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,
    output             LVBL,
    output             LHBL
);

wire [ 1:0] we;
wire [15:0] pal;
wire [14:0] rgb;

assign we = ~dswn & {2{pal_cs}};
assign { red, green, blue } = rgb;

wire [4:0] rpal, gpal, bpal;

assign rpal  = { pal[ 3:0], pal[12] };
assign gpal  = { pal[ 7:4], pal[13] };
assign bpal  = { pal[11:8], pal[14] };

jtframe_dual_ram16 #(
    .AW        (11          ),
    .SIMFILE_LO("pal_lo.bin"),
    .SIMFILE_HI("pal_hi.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1  ( pal_addr  ),
    .data1  (           ),
    .we1    ( 2'b0      ),
    .q1     ( pal       )
);

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

reg [14:0] gated;

always @(*) begin
    gated = (shadow & ~pal[15]) ? { dim(rpal), dim(gpal), dim(bpal) } :
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
    .rgb_out    ( rgb[14:0] )
);

endmodule