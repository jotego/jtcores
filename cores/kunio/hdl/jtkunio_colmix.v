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
    Date: 21-5-2022 */

module jtkunio_colmix(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             LHBL,
    input             LVBL,

    input      [ 4:0] char_pxl,
    input      [ 5:0] scr_pxl,
    input      [ 4:0] obj_pxl,

    input             pal_cs,
    input             cpu_wrn,
    input      [ 8:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] pal_dout,

    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

reg  [ 7:0] pal_a;
wire [ 7:0] col_half;
reg         half;
reg  [ 3:0] nr,ng,nb;
wire        char_blank, obj_blank, pal_we;

assign pal_we     = pal_cs & ~cpu_wrn;
assign obj_blank  = obj_pxl[2:0]==0 || !gfx_en[3];
assign char_blank = char_pxl[2:0]==0 || !gfx_en[0];

// wire [3:0] sorted;

// jtframe_sort u_sort(
//     .debug_bus  ( {5'd0, debug_bus[2:0]} ),
//     .busin      ( {1'b0, obj_pxl[2:0]}   ),
//     .busout     ( sorted                 )
// );

always @(posedge clk) begin
    half <= ~half;
    if( pxl_cen ) begin
        half <= 0;
        { red, green, blue } <= (!LVBL || !LHBL ) ? 12'd0 : { nr, ng, nb };
        pal_a[7:6] <= { char_blank, obj_blank & char_blank };
        pal_a[5:0] <= !char_blank ? { 1'b0, char_pxl } :
                      !obj_blank  ? { 1'b0,  obj_pxl } :
                      gfx_en[1]   ? scr_pxl : 6'd0;
    end
    if( half )
        { ng, nr } <= col_half;
    else
        nb <= col_half[3:0];
end

jtframe_dual_ram #(.AW(9),.SIMFILE("pal.bin")) u_dual_ram (
    // CPU
    .clk0  ( clk        ),
    .data0 ( cpu_dout   ),
    .addr0 ( cpu_addr   ),
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