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
	Author: LMN-san.           Twitter: @Lmn_Sama
	Author: Olivier Scherler.  Twitter: @oscherler
	Version: 1.0
	Date: 06-05-2021
*/

//================================================================================
//  N-Bit Bidirectional Universal Shift Register
//  
//  Based on jt74194 from jt74.v.
//================================================================================

`default_nettype none

module lmn74194_nbit #( parameter N=4 )
(
	input      [N-1:0] D,    // parallel input, N bits
	input      [  1:0] S,    // mode select
	input              mclk, // main clock
	input              cen,  // clock enable
	input              clr,  // clear, active high
	input              R,    // right feed
	input              L,    // left feed
	output reg [N-1:0] Q     // parallel output, N bits
);

always @( posedge mclk ) begin
	if( clr ) begin
		Q <= {N{1'b0}};
	end else if( cen ) begin
		case( S ) // mode select
			2'b10: Q <= { L, Q[N-1:1] }; // feed from left
			2'b01: Q <= { Q[N-2:0], R }; // feed from right
			2'b11: Q <= D;               // parallel load
		endcase
	end
end

endmodule
