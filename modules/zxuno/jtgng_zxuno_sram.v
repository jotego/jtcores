/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 8-2-2019 */

module jtgng_zxuno_sram(
    input             clk,
    input             cen24,
    input             cen12,
    input      [19:0] game_addr16,
    output     [20:0] game_addr8,
    input      [ 7:0] sram_data,
    output reg [15:0] sram_data16
);

reg lsb;
reg [7:0] last;

assign game_addr8[20:1] = game_addr16[19:0];
assign game_addr8[0]    = lsb;

always @(posedge clk) if(cen24) begin
    lsb  <= ~cen12;
    last <= sram_data;
    if( cen12 ) sram_data16 <= { sram_data, last };
end

endmodule // jtgng_zxuno_sram