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
    Date: 15-3-2025 */

module jtrthunder_colmix(
    input             clk,
    input             pxl_cen

    input      [ 7:0] scr0_pxl, scr1_pxl, obj_pxl,
    input      [ 2:0] obj_prio, scr_prio,

    output     [ 8:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,

    output     [ 3:0] red, green, blue,
);

reg scrwin, obj_op;

always @* begin
    obj_op = ~&obj_pxl[3:0];
    scrwin = scr_prio > scr_prio;
    if(!obj_op) scrwin = 1;
end


always @(posedge clk) if(pxl_cen) begin
    rgb_addr <= scrwin ? scrmix : obj_pxl;
    {green,red,blue} <= {rg_data,b_data[3:0]};
end

endmodule    