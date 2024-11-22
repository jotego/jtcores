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

    output reg [ 9:0] pal_addr,
    input      [15:0] pal_dout,

    input       [7:0] scr_pxl,
    input       [7:0] obj_pxl,
    output      [3:0] red,
    output      [3:0] green,
    output      [3:0] blue
);

localparam [1:0] SCR = 2'b00,
                 OBJ = 2'b01;

always @(posedge clk) begin
end

endmodule    