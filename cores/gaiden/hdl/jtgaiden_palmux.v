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
    Date: 2-3-2025 */

module jtgaiden_palmux(
    input               clk,
    input        [ 2:0] st,
    input        [ 7:0] txt_pxl, scr2_pxl,
    input        [ 8:0] scr1_pxl,
    input        [10:0] obj_pxl,

    input        [ 4:0] sel, sel2,
    output reg   [12:1] pal_addr,
    input        [15:0] pal_dout,
    output reg   [11:0] main, other
);

`include "jtgaiden_colmix.vh"

reg [ 4:0] amuxsel=SEL_NONE;

always @* begin
    case(amuxsel)
        SEL_TXT:  pal_addr = {TEXT, txt_pxl};
        SEL_SCR1: pal_addr = {SCR1, scr1_pxl[7:0]};
        SEL_SCR2: pal_addr = {SCR2, scr2_pxl};
        SEL_OBJ:  pal_addr = {OBJ,  obj_pxl[7:0]};
        default:  pal_addr = FILL;
    endcase
end

always @(posedge clk) begin
    case(st)
        1: amuxsel <= sel;
        3: begin
            main    <= pal_dout[11:0];
            amuxsel <= sel2;
        end
        5: begin
            other <= pal_dout[11:0];
        end
    endcase
end

endmodule