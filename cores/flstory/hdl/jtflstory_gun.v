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
    Date: 28-2-2025 */

module jtflstory_gun(
    input            clk,
                     gunx_cs, guny_cs, trcrt_cs,
    input      [8:0] gun_x, gun_y,

    output reg [7:0] gun_dout
);

    reg [7:0] gunadj_x, gunadj_y;

    always @(posedge clk) begin
        if(trcrt_cs) begin
            gunadj_x <= gun_x[7:0];
            gunadj_y <= gun_y[7:0];
        end
        gun_dout <= gunx_cs ? gunadj_x :
                    guny_cs ? gunadj_y : 8'h01;
    end
endmodule