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
    Date: 27-10-2024 */

module jtwc_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input      [ 6:0] obj,
    input      [ 7:0] fix,
    input      [ 7:0] scr,

    output reg [ 9:0] pal_addr,
    input      [15:0] pal_dout,

    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue,

    input      [ 3:0] gfx_en
);

localparam [2:0] OBJ = 3'b010;
localparam [1:0] SCR = 2'b10,
                 FIX = 2'b00;

wire obj_opaque = gfx_en[3] && obj[3:0]!=0;
wire fix_opaque = gfx_en[0] && fix[3:0]!=0;

always @(posedge clk) begin
    pal_addr = obj_opaque ? {OBJ,obj} :
               fix_opaque ? {FIX,fix} : {SCR,scr};
    if(pxl_cen) {blue,green,red} <= pal_dout[11:0];
end

endmodule
