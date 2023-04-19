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
    Date: 14-12-2019 */


module jtdd_dip(
    input              clk,
    input      [31:0]  status,

    input              dip_pause,
    input              dip_test,
    input              dip_flip,
    output             turbo,

    output reg [ 7:0]  dipsw_a,
    output reg [ 7:0]  dipsw_b
);

wire          dip_upright = 1'b0;
wire [1:0]    dip_level   = status[17:16];
wire          dip_demosnd = status[18];
wire          dip_kick    = status[24];    // only in DD2
wire [1:0]    dip_bonus   = status[20:19]; // Timer setting in DD2
wire [1:0]    dip_lives   = status[22:21]; // Lives in DD2 but different values
assign turbo              = status[23];
wire [2:0]    dip_price1  = ~3'b0;
wire [2:0]    dip_price2  = ~3'b0;


always @(posedge clk) begin
    dipsw_a <= { dip_flip, dip_upright, dip_price2, dip_price1 };
    // the meaning for some bits in DD2 in dipsw_b is different:
    dipsw_b <= { dip_lives, dip_bonus, dip_kick, dip_demosnd, dip_level };
end

endmodule