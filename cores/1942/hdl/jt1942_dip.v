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

module jt1942_dip(
    input              clk,
    input      [31:0]  status,

    input              dip_pause,
    input              dip_test,
    input              dip_flip,

    output reg [ 7:0]  dipsw_a,
    output reg [ 7:0]  dipsw_b
);

// Commando specific:
wire          dip_upright = 1'b0;
wire [1:0]    dip_bonus   = ~status[17:16];
wire [1:0]    dip_level   = ~status[21:20];
wire [1:0]    dip_lives   = ~status[19:18];
wire [2:0]    dip_price   = 3'b111;
`ifdef VULGUS
wire          dip_demosnd = status[20];
wire          dip_demomsc = status[21];
`endif

always @(posedge clk) begin
    `ifdef VULGUS
        dipsw_a <= { {2{dip_price}}, dip_lives };
        dipsw_b <= { dip_upright, dip_bonus,
            dip_demosnd, dip_demomsc, 2'b11 };
    `else // 1942
        dipsw_a <= { dip_lives, dip_bonus, dip_upright, dip_price };
        dipsw_b <= { dip_pause, dip_level, 1'b1, dip_test, 3'd7   };
    `endif
end

endmodule