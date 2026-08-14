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
    Date: 6-7-2025 */

module jtrungun_colmix(
    input             lrsw, pri,

    // Final pixels
    input      [ 1:0] shadow,
    input      [ 8:0] obj_pxl,
    input      [ 7:0] fix_pxl, psc_pxl,

    // frame buffer
    output     [15:0] pxl,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

localparam [ 1:0] FIX =2'b00, PSC=2'b01;
localparam [10:0] BACK=11'h7ff;
localparam [ 0:0] OBJ =1'b1;

wire        shad, fix_op, psc_op, obj_op, obj_wins;

assign fix_op     = fix_pxl[3:0]!=0 && gfx_en[0];
assign psc_op     = psc_pxl[3:0]!=0;
assign obj_op     = obj_pxl[3:0]!=0;
assign obj_wins   = (!psc_op && obj_op ) || (!pri && obj_op);
assign pxl[15:11] = {4'd0,lrsw};
assign pxl[10: 0] =  fix_op ? {FIX, fix_pxl, 1'b0} :
                   obj_wins ? {OBJ, obj_pxl, 1'b0} :
                     psc_op ? {PSC, psc_pxl, shad} : BACK;

assign shad = |shadow;

endmodule
