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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_profile
(
	input      [7:0] game_id,  // ROM-header byte 0, NOT jtframe's core_mod
	output reg       valid,
	output reg [1:0] profile,
	output reg       low_pen_priority,
	output reg       soccer_sprites,
	output reg       has_adpcm,
	output reg       has_joys2,
	output reg       native_vertical
);

localparam [1:0] PROFILE_CASTLE = 2'd0;
localparam [1:0] PROFILE_RUNRUN = 2'd1;
localparam [1:0] PROFILE_SOCCER = 2'd2;

always @(*) begin
	valid = 1'b1;
	profile = PROFILE_CASTLE;
	low_pen_priority = 1'b0;
	soccer_sprites = 1'b0;
	has_adpcm = 1'b0;
	has_joys2 = 1'b0;
	native_vertical = 1'b0;

	case (game_id)
		8'h00: begin // Mr. Do's Castle
			native_vertical = 1'b1;
		end
		8'h01: begin // Mr. Do! vs. Unicorns
			native_vertical = 1'b1;
		end
		8'h02: begin // Do! Run Run
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
		end
		8'h03: begin // Mr. Do's Wild Ride
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
		end
		8'h04: begin // Jumping Jack
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
			native_vertical = 1'b1;
		end
		8'h05: begin // Kick Rider
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
		end
		8'h06: begin // Super Pierrot
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
		end
		8'h07: begin // Indoor Soccer
			profile = PROFILE_SOCCER;
			low_pen_priority = 1'b1;
			soccer_sprites = 1'b1;
			has_adpcm = 1'b1;
			has_joys2 = 1'b1;
		end
		8'h08: begin // American Soccer
			profile = PROFILE_SOCCER;
			low_pen_priority = 1'b1;
			soccer_sprites = 1'b1;
			has_adpcm = 1'b1;
			has_joys2 = 1'b1;
		end
		8'h09: begin // Do! Run Run set 2 (board-sequence oracle)
			profile = PROFILE_RUNRUN;
			low_pen_priority = 1'b1;
		end
		default: begin
			valid = 1'b0;
			profile = PROFILE_CASTLE;
		end
	endcase
end

endmodule
