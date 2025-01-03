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
    Date: 1-1-2025 */

module jtgaiden_scroll_adder(
    input             clk,
    input      [15:0] din,
    input      [ 1:0] dsn,
    input             wr_n,
    input             cs,
    input             short_en,
    input             long_en,
    output reg [15:0] scroll
);

reg  [ 7:0] short;
reg  [15:0] long;

always @(posedge clk) begin
    scroll <= long - {8'd0,short};
   if( cs && short_en && !wr_n && !dsn[0] ) short      <= din[7:0];
   if( cs && long_en  && !wr_n && !dsn[0] ) long[ 7:0] <= din[7:0];
   if( cs && long_en  && !wr_n && !dsn[0] ) long[15:8] <= din[15:8];
end

endmodule