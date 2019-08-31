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

module jtgunsmoke_dip(
    input           clk,
    input   [31:0]  status,
    // non standard:
    input           dip_pause,
    input           dip_test,

    output  [ 7:0]  dipsw_a,
    output  [ 7:0]  dipsw_b
);

wire       dip_upright   = 1'b0;
wire       dip_demosnd   = 1'b0;
wire       dip_continue  = 1'b1;
wire [2:0] dip_price     = ~3'b0;
reg  [1:0] dip_level;
reg  [1:0] dip_bonus     = 2'b01;
wire       dip_lives     = 1'b0;

// play level
always @(posedge clk)
    case( status[17:16] )
        2'b00: dip_level <= ~2'b01; // normal
        2'b01: dip_level <= ~2'b00; // easy
        2'b10: dip_level <= ~2'b10; // hard
        2'b11: dip_level <= ~2'b11; // very hard
    endcase


assign dipsw_a = {dip_test, dip_pause, dip_level, dip_upright, dip_lives, dip_bonus };
assign dipsw_b = {dip_demosnd, dip_continue, 2'b11, dip_price };

endmodule