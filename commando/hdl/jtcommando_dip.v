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
    Date: 20-10-2019 */

`timescale 1ns/1ps

module jtcommando_dip(
    input              clk,
    input      [31:0]  status,

    output reg [ 7:0]  dipsw_a,
    output reg [ 7:0]  dipsw_b,
    // non standard:
    input              dip_flip
);

// Commando specific:
wire [1:0]    dip_upright = 2'b00;
wire          dip_level  = ~status[2];
wire [1:0]    dip_start  = ~status[4:3];
wire [1:0]    dip_lives  = ~status[6:5];
wire [1:0]    dip_price1 = 2'b00;
wire [1:0]    dip_price2 = 2'b11;
wire [2:0]    dip_bonus  = 3'b111;
wire          dip_demosnd= 1'b0;

always @(posedge clk) begin
    dipsw_a <= { dip_price1, dip_price2, dip_lives, dip_start };
    dipsw_b <= { dip_upright, dip_flip, dip_level, dip_demosnd, dip_bonus };
end

endmodule