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
    Date: 18-11-2019 */

`timescale 1ns/1ps

module jtbtiger_dip(
    input              clk,
    input      [31:0]  status,

    input              dip_pause,
    input              dip_test,
    input              dip_flip,

    output reg [ 7:0]  dipsw_a,
    output reg [ 7:0]  dipsw_b
);

wire          dip_portrait= 1'b0;
wire [1:0]    dip_lives  = ~status[20:19];
wire          dip_cont   = ~status[21];
wire          dip_demo   = ~status[18];
wire [2:0]    dip_price1 = 3'b111;
wire [2:0]    dip_price2 = 3'b111;

wire [2:0]    dip_level  = ~status[17:15];

always @(posedge clk) begin
    dipsw_a <= { dip_portrait, dip_cont, 
                 dip_demo, dip_level, dip_lives };
    dipsw_b <= { dip_test, ~dip_flip, dip_price2, dip_price1 };
end

endmodule