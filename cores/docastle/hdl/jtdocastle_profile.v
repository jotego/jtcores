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

// Per-game profile decode for the nine sets that share this core's single
// RBF. Ported from the standalone MiSTer Universal_DoCastle core this core
// derives from.
//
// What this module does:
//   Pure combinational case-decode of an 8-bit game-ID/ROM-ABI byte into
//   the profile enum (Castle/RunRun/Soccer) plus 5 per-game feature flags
//   (low_pen_priority, soccer_sprites, has_adpcm, has_joys2,
//   native_vertical) consumed elsewhere in the core (video priority mux,
//   sprite chip variant, ADPCM channel enable, 2nd joystick routing,
//   default screen orientation). Unknown game_id values deliberately clear
//   `valid`, which the game module ANDs into machine reset -- an unrecognized
//   ID holds the whole core in reset rather than running with guessed
//   defaults.
//
// Where game_id comes from:
//   jtdocastle_game.v latches byte 0 of jtframe's ROM header (JTFRAME_HEADER)
//   into `game_id`. In the source MiSTer core the same byte arrived as a
//   second, separate synthetic ioctl download (`ioctl_index==1`,
//   `ioctl_addr==0`) issued by that core's MRAs, independent of the main
//   ROM-image download. Either way it is a single ROM-ABI byte selecting
//   which of the 9 games / 3 profiles the one shared RBF is running.
//
// Why the header byte rather than jtframe's MOD byte -- two distinct jtframe
// mechanisms exist and picking the wrong one would silently misroute this
// byte:
//
//   1. core_mod / "MOD byte" (modules/jtframe/doc/core_mod.md). Also loaded
//      via an MRA `<rom index="1"><part>NN</part></rom>` entry -- the same MRA
//      convention the source core's game_id byte used, which makes it a
//      superficially tempting match. REJECTED as the destination
//      for game_id: the MOD byte's 7-8 bits have FIXED, jtframe-defined
//      meanings (bit0=vertical screen, bit1=4-way joystick, bit2=CCW
//      rotation [auto-set by `jtframe mra`], bit3=unfiltered dial, bit4=dial
//      reverse, bit5-6=blanking expansion, byte1=volume) consumed by
//      jtframe's OWN internal logic (jtframe_board.v/jtframe_sys_info.v),
//      not a free-form value the game module gets to interpret. docastle's
//      game_id is a 9-value enum selecting ROM layout/priority/ADPCM/2nd-
//      joystick/profile -- none of that has a MOD-byte bit. Reusing the MOD
//      byte would require inventing meaning for undefined bits.
//   2. JTFRAME_HEADER / mame2mra.toml `[header]` section
//      (modules/jtframe/doc/jtframe-mra.md `[header]`, doc/macros.md
//      `JTFRAME_HEADER`). This is described as bits "handled directly by
//      the core's game module" (explicitly contrasted against the MOD byte,
//      which configures jtframe itself) -- doc/core_mod.md's own wording.
//      Mechanically it is a per-set header of `JTFRAME_HEADER` bytes
//      PREPENDED to the ordinary ROM file at MRA-build time (fill/patches
//      per machine/setname in mame2mra.toml), consumed during the *same*
//      download as the main ROM image via `prog_addr`/`prog_we` while a
//      `header` qualifier is high. This matches "a byte the game module
//      itself interprets", and is what jtdocastle_game.v uses.
//
//   `game_id` is kept as this module's port name (not renamed to `core_mod`
//   or `header`) because it is a board-ABI value, not a jtframe-defined one.
//
// OPEN ITEM: jtframe also offers automatic header module generation -- a
// `registers=[]` TOML list giving named per-bit signals with per-machine
// values, which could generate this module's flag outputs directly from
// mame2mra.toml. Whether this hand-written case decode should be replaced by
// that generation is undecided and depends on mame2mra.toml being authored.
//
// OPEN ITEM: mixed-orientation, single-RBF, multi-MRA rotation is unresolved
// for this core. core_mod.md's MOD-byte bit0 (vertical screen) and bit2 (CCW
// rotation, set by `jtframe mra`) indicate jtframe has a per-MRA rotation
// override mechanism that would likely resolve it; that has not been
// exercised here.
//
// MAME reference: none -- game_id is a MiSTer-side ROM-ABI construct with no
// MAME counterpart.

module jtdocastle_profile
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
