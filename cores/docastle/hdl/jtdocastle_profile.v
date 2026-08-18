// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_profile.sv, decode logic
// unchanged, not yet compiled or simulated against real jtframe tooling
// (Docker toolchain was down for the whole of this port attempt).
//
// This module is NOT superseded by jtframe -- ported as-is per task
// instruction. What follows documents exactly what was, and was not,
// resolved about how `game_id` reaches this module under jtframe.
//
// What the original module does (unchanged in this port):
//   Pure combinational case-decode of an 8-bit game-ID/ROM-ABI byte into
//   the profile enum (Castle/RunRun/Soccer) plus 5 per-game feature flags
//   (low_pen_priority, soccer_sprites, has_adpcm, has_joys2,
//   native_vertical) consumed elsewhere in the core (video priority mux,
//   sprite chip variant, ADPCM channel enable, 2nd joystick routing,
//   default screen orientation). Unknown game_id values deliberately clear
//   `valid`, which docastle_core.sv ANDs into machine reset -- i.e. an
//   unrecognized ID holds the whole core in reset rather than running with
//   guessed defaults. That behaviour is preserved unchanged here.
//
// Where game_id currently comes from (mrdo, pre-port):
//   NOT from this module, and NOT from docastle_rom.sv either (see
//   PORTING_NOTES.md finding for docastle_rom.sv). It is captured in
//   docastle_core.sv itself, from a SECOND, separate synthetic ioctl
//   download that mrdo's MRAs issue: `ioctl_download && ioctl_wr &&
//   (ioctl_index==8'd1) && (ioctl_addr==0)` latches ioctl_dout into an
//   8-bit `game_id` register (docastle_core.sv lines ~67-75), completely
//   independent of the ioctl_index==0 main ROM-image download that
//   docastle_rom.sv consumes. This is the "RTL ABI byte" the README and
//   PORTING_NOTES.md refer to -- one extra <rom index="1"> entry per MRA,
//   carrying a single byte that selects which of the 9 games/3 profiles is
//   loaded into the one shared RBF.
//
// What jtframe mechanism this should connect to -- INVESTIGATED, NOT
// CONFIRMED, do not trust the port below without re-checking against real
// jtframe tooling:
//   Two distinct jtframe mechanisms were found and are NOT the same thing --
//   picking the wrong one would silently misroute this byte:
//
//   1. core_mod / "MOD byte" (modules/jtframe/doc/core_mod.md). Also loaded
//      via an MRA `<rom index="1"><part>NN</part></rom>` entry -- structurally
//      the same MRA convention mrdo's own game_id byte already uses, which
//      makes it a superficially tempting match. REJECTED as the destination
//      for game_id: the MOD byte's 7-8 bits have FIXED, jtframe-defined
//      meanings (bit0=vertical screen, bit1=4-way joystick, bit2=CCW
//      rotation [auto-set by `jtframe mra`], bit3=unfiltered dial, bit4=dial
//      reverse, bit5-6=blanking expansion, byte1=volume) consumed by
//      jtframe's OWN internal logic (jtframe_board.v/jtframe_sys_info.v),
//      not a free-form value the game module gets to interpret. docastle's
//      game_id is a 9-value enum selecting ROM layout/priority/ADPCM/2nd-
//      joystick/profile -- none of that has a MOD-byte bit. Reusing the MOD
//      byte would require inventing meaning for undefined bits, exactly the
//      kind of guess the task says not to make.
//   2. JTFRAME_HEADER / mame2mra.toml `[header]` section
//      (modules/jtframe/doc/jtframe-mra.md `[header]`, doc/macros.md
//      `JTFRAME_HEADER`). This is described as bits "handled directly by
//      the core's game module" (explicitly contrasted against the MOD byte,
//      which configures jtframe itself) -- doc/core_mod.md's own wording.
//      Mechanically it is a per-set header of `JTFRAME_HEADER` bytes
//      PREPENDED to the ordinary ROM file at MRA-build time (fill/patches
//      per machine/setname in mame2mra.toml), consumed during the *same*
//      download as the main ROM image via `prog_addr`/`prog_we` while a
//      `header` qualifier is high (`if (prog_addr==0 && prog_we && header)
//      mycfg <= prog_data;` per the doc's own example) -- structurally
//      DIFFERENT from mrdo's current separate ioctl_index==1 download.
//      jtframe also offers "automatic header module generation" -- a
//      `registers=[]` TOML list giving named per-bit signals with
//      per-machine values, which could auto-generate something like this
//      module's flag outputs directly from mame2mra.toml without hand
//      Verilog at all. This is the mechanism that best matches "a byte the
//      game module itself interprets", and is the leading candidate, but:
//        - mame2mra.toml is explicitly out of scope for this porting task
//          (PORTING_NOTES.md deviation #5 already flagged this as
//          deferred, not designed).
//        - Whether docastle_profile's job should become the hand-written
//          case-decode below (fed by a single JTFRAME_HEADER byte laid out
//          manually in `[header]`) or be replaced ENTIRELY by jtframe's
//          automatic per-bit `registers=[]` generation is not decided.
//        - The exact `header/prog_addr/prog_we` signal names and timing at
//          the game-module boundary were not confirmed by running
//          `jtframe files`/`jtframe mem` (Docker down for this attempt).
//
//   Net: `game_id` is kept as this module's port name (not renamed to
//   `core_mod` or `header` or any jtframe-specific name) precisely because
//   neither candidate wiring was confirmed. Wire this port up only after
//   mame2mra.toml's `[header]` section is authored and cross-checked
//   against real jtframe codegen output -- see PORTING_NOTES.md "Remaining
//   work" item 5.
//
// This also bears on the still-open JTFRAME_VERTICAL/rotation question
// already recorded in PORTING_NOTES.md ("Mixed-orientation, single-RBF,
// multi-MRA rotation is unresolved") -- core_mod.md's MOD-byte bit0
// ("vertical screen... the same RBF can switch between horizontal and
// vertical games by using the MOD byte") and bit2 ("CCW rotation, set by
// jtframe mra") are new evidence *suggesting* jtframe has a real per-MRA
// rotation-override mechanism already, which would resolve that open
// question favourably -- but this draft does NOT claim that question
// resolved; it is recorded as new supporting evidence for whoever picks
// that question up, not a re-litigation of it here.
//
// MAME reference: none -- game_id is an mrdo/MiSTer-side ROM-ABI construct
// with no MAME counterpart, unchanged from the original module's own scope.

module jtdocastle_profile
(
	input      [7:0] game_id,  // see header note above: source TBD, NOT core_mod
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
