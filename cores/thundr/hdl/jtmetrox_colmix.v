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
    Date: 25-5-2025 */

module jtmetrox_colmix(
    input             clk,
    input             pxl_cen,
    input      [ 8:0] hdump, vdump,

    input      [10:0] scr0_pxl, obj_pxl,
    input      [ 2:0] scr0_prio, obj_prio,
    input      [ 8:0] txt_pxl,

    output reg [10:0] rgb_addr,
    input      [ 7:0] bg_data, r_data,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 3:0] red, green, blue
);

localparam [2:0] ALPHA=7;
localparam [3:0] OALPHA=15;
localparam [1:0] OBJ=2'b01;

wire       txt_op, obj_op;

assign txt_op = txt_pxl[1:0]!= ALPHA[1:0] && gfx_en[0];
assign obj_op = obj_pxl[3:0]!=OALPHA      && gfx_en[3];

always @(posedge clk) if(pxl_cen) begin
    rgb_addr <= txt_op ? {txt_pxl[8:2],2'd0,txt_pxl[1:0]} :
                (obj_op && obj_prio>=scr0_prio) ? obj_pxl : scr0_pxl;
    {blue,green,red} <= {bg_data,r_data[3:0]};
end

endmodule
