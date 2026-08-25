/*
	This file is derived from JTFRAME.
	JTFRAME program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JTFRAME program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Author: Olivier Scherler.  Twitter: @oscherler
	Version: 1.0
	Date: 20-04-2021
*/

//================================================================================
//  Multi-bit generic flip-flop with global set, clr, and clock signals.
//  
//  Based on jtframe_ff.
//================================================================================

`default_nettype none

module bus_ff #( parameter W=1 ) (
	input          clk,
	input          rst,
	input          trig,
	input  [W-1:0] d,

	output [W-1:0] q,
	output [W-1:0] q_n
);

reg         trig_prev;
reg [W-1:0] state;

always @( posedge clk ) begin
	if( rst ) begin
		state <= {W{1'b0}};
		trig_prev <= 1'b1;
	end else begin
		if( trig & ~trig_prev ) begin
			state <= d;
		end

		trig_prev <= trig;
	end
end

assign q   = state;
assign q_n = ~state;

endmodule
