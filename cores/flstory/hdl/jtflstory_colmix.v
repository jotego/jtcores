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
    Date: 22-11-2024 */

module jtflstory_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             lvbl,
    input             lhbl,
    input      [ 1:0] bank,

    output     [ 9:0] pal_addr,
    input      [15:0] pal_dout,

    input       [1:0] scr_prio, obj_prio,
    input       [7:0] scr_pxl, obj_pxl,
    output reg  [3:0] red, green, blue
);

localparam [1:0] SCR = 2'b00,
                 OBJ = 2'b01;

reg  [7:0] amux;
reg        pal_sel;
wire       prio_dout, obj_op;
reg  [1:0] scrprio_l, objprio_l, st;
reg  [7:0] scrpxl_l,  objpxl_l;

assign pal_addr  = { bank, pal_sel ? amux : {objprio_l, scrprio_l, objpxl_l[3:0]} };
assign obj_op    = objpxl_l[3:0]!=4'hf;
assign prio_dout = pal_dout[12];

always @(posedge clk) begin
    st <= st<<1;
    if( st[1] ) begin
        amux    <= (obj_op & prio_dout) ? objpxl_l : scrpxl_l;
        pal_sel <= 1;
    end
    if( pxl_cen ) begin
        {scrprio_l, scrpxl_l} <= {scr_prio, scr_pxl};
        {objprio_l, objpxl_l} <= {obj_prio, obj_pxl};
        {blue,green,red} <= lvbl && lhbl ? pal_dout[11:0] : 12'd0;
        st      <= 1;
        pal_sel <= 0;
    end
end

endmodule    