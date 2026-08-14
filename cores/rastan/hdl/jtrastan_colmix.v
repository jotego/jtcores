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
    Date: 2-4-2022 */

module jtrastan_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,
    input           opwolf,
    input           rbisland,

    output   [11:1] palram_addr,
    input    [15:0] palram_video_data,

    input           preLHBL,
    input           preLVBL,
    output          LHBL,
    output          LVBL,

    input    [10:0] scr0_pxl,
    input    [10:0] scr1_pxl,
    input    [ 7:0] obj_pxl,
    input    [ 2:0] obj_pal,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en
);

wire [14:0] pal_rgb;
reg  [10:0] pal_addr;
wire        scr1_blank, obj_blank;

assign scr1_blank = scr1_pxl[3:0]==0 || !gfx_en[0];
assign obj_blank  =  obj_pxl[3:0]==0 || !gfx_en[3];
assign palram_addr = pal_addr;
assign pal_rgb    = opwolf ? {palram_video_data[3:0],palram_video_data[12],
                              palram_video_data[7:4],palram_video_data[13],
                              palram_video_data[11:8],palram_video_data[14]} : palram_video_data[14:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pal_addr <= 0;
    end else if(pxl_cen) begin
        if( (opwolf || rbisland) && !scr1_blank )
            pal_addr <= scr1_pxl;
        else if( !obj_blank )
            pal_addr <= { obj_pal, obj_pxl };
        else if( !scr1_blank )
            pal_addr <= scr1_pxl;
        else
            pal_addr <= gfx_en[1] ? scr0_pxl : 11'd0;
    end
end

jtframe_blank #(
    .DLY( 4),
    .DW (15)
) u_dly(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .preLHBL    ( preLHBL           ),
    .preLVBL    ( preLVBL           ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .preLBL     (                   ),
    .rgb_in     ( pal_rgb           ),
    .rgb_out    ( {blue,green,red}  )
);

endmodule
