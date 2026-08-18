/*  This file is part of JT12.

    JT12 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: March, 9th 2017
	*/

`timescale 1ns / 1ps

/*

	input sampling rate must be the same as clk frequency
    interpolate input signal accordingly to get the
    right sampling rate.
	
	Refer to sigmadelta.ods to see how the internal width (int_w)
	was determined.

*/

module jt12_dac2 #(parameter width=11)
(
	input	clk,
    input	rst,
    input	signed [width-1:0] din,
    output	reg dout
);

localparam int_w = width+5;

reg [int_w-1:0] y, error, error_1, error_2;

wire [width-1:0] undin = { ~din[width-1], din[width-2:0] };

always @(*) begin
	y = undin + { error_1, 1'b0} - error_2;
	dout = ~y[int_w-1];
	error = y - {dout, {width{1'b0}}};
end

always @(posedge clk)
	if( rst ) begin
		error_1 <= {int_w{1'b0}};
		error_2 <= {int_w{1'b0}};
	end else begin
		error_1 <= error;
		error_2 <= error_1;
	end

endmodule
