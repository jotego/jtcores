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
    Date: 21-8-2019 */

`timescale 1ns/1ps

module jtbiocom_dip(
    input              clk,
    input      [31:0]  status,

    input              dip_pause,
    input              dip_test,
    input              dip_flip,

    output reg [ 7:0]  dipsw_a,
    output reg [ 7:0]  dipsw_b
);

// Bionic Commando specific: 20-16
wire          dip_upright = 1'b1;
wire [1:0]    dip_level  = ~status[18:17];
wire [1:0]    dip_lives  = ~status[20:19];
wire [2:0]    dip_price1 = 3'b000;
wire [2:0]    dip_price2 = 3'b000;
wire [1:0]    dip_bonus  = ~status[16:15];

always @(posedge clk) begin
    dipsw_a <= { dip_pause, dip_level, dip_bonus, dip_upright, dip_lives };
    dipsw_b <= { dip_flip^1'b1, dip_test, dip_price2, dip_price1 };
end

endmodule