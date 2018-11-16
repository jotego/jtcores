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
    Date: 27-10-2017 */

`timescale 1ns / 1ps

module jtgng_sh #(parameter width=5, stages=24 )
(
	input 							clk,
	input		[width-1:0]			din,
   	output		[width-1:0]			drop
);

reg [stages-1:0] bits[width-1:0];

genvar i;
generate
	for (i=0; i < width; i=i+1) begin: bit_shifter
		always @(negedge clk) begin
			if( stages> 1 )
				bits[i] <= {bits[i][stages-2:0], din[i]};
			else
				bits[i] <= din[i];
		end
		assign drop[i] = bits[i][stages-1];
	end
endgenerate

endmodule
