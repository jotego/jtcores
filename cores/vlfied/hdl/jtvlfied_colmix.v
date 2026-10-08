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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 7-8-2026 */

/*  Palette is xBGR-555, driven by the TC0070RGB RGB mixer module.
    The bitmap sits behind the PC090OJ sprites.    */

module jtvlfied_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,

    output reg [12:0] pal_addr,
    input      [15:0] pal_data,

    input           preLHBL,
    input           preLVBL,
    output          LHBL,
    output          LVBL,

    input    [11:0] fb_pxl,
    input    [ 7:0] obj_pxl,
    input    [ 3:0] obj_pal,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en
);

localparam OBJ=1'b1, BCK=1'b0;
wire        obj_blank;

assign obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];

always @(posedge clk) if(pxl_cen) begin
    if( !obj_blank )
        pal_addr <= { OBJ, obj_pal, obj_pxl };
    else
        pal_addr <= gfx_en[0] ? { BCK, fb_pxl } : 13'd0;
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
    .rgb_in     ( pal_data[14:0]    ),
    .rgb_out    ( {blue,green,red}  )
);

endmodule
