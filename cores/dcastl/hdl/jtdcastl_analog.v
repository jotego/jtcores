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

// Analog-stick to 4-way-digital decoder for the Soccer profiles. Ported from
// the standalone MiSTer Universal_DoCastle core this core derives from.
//
// Input format:
//   This module computes a plain threshold+hysteresis 2-axis
//   analog-to-4-way-digital decoder: axis_x/axis_y are read as SIGNED 8-bit
//   two's-complement values (right/down positive, left/up negative),
//   direction asserts at |axis| >= 32 and releases at |axis| <= 20 (a dead
//   band around the release threshold, not the assert threshold -- classic
//   Schmitt-trigger-style chatter prevention). This is generic threshold
//   logic with NO board-specific protocol content -- it does not depend on
//   anything about the docastle/Soccer PCB beyond "the input is a signed
//   X/Y analog pair in MiSTer's standard format".
//
//   jtframe's own joyana_l1..l4 / joyana_r1..r4 ports (see
//   modules/jtframe/hdl/inc/jtframe_common_ports.inc and
//   modules/jtframe/doc/inputs.md "Joysticks" section) are CONFIRMED to be
//   the exact same format: "2-complement bytes... right and bottom are
//   positive (127 max); left and top are negative (FFh min, 80h max)",
//   [7:0]=X, [15:8]=Y -- identical to this module's axis_x/axis_y split.
//   Confirmed further by tracing the signal at the target level: MiSTer's
//   own jtframe_mister.sv wires `joyana_l1` directly from hps_io's
//   `joystick_l_analog_0` with NO transformation (target/mister/hdl/
//   jtframe_mister.sv: ".joystick_l_analog_0( joyana_l1 )"), i.e. joyana_l1
//   IS joystick_l_analog_0, just renamed at the jtframe port boundary.
//
//   The decode logic is therefore reusable as-is; only the input port name
//   differs from the original core (`analog` -> `joyana`, generic for
//   whichever of joyana_l1..r4 the caller wires in).
//
// NOT solved by jtframe's own built-in analog handling, and why a
// board-local module is still needed (do not delete this and rely on
// jtframe's generic path instead):
//   jtframe_board.v / jtframe_inputs.v already do SOME analog-to-digital
//   work of their own (ana1<-joyana_l1, ana2<-joyana_l2 feed a generic
//   "32-way joystick via PWM" emulation per doc/inputs.md), but that
//   mechanism folds ONE left analog stick per player into that player's
//   single digital joystick word. It is not a fit for this board's Soccer
//   profile, which reads BOTH the left AND right analog stick per player
//   (joyana_l1+joyana_r1 for P1, joyana_l2+joyana_r2 for P2) and keeps their
//   two decoded 4-way direction
//   sets SEPARATE, later combining each with its own distinct digital
//   button-bit group (joystick_0[12:15]/joystick_1[12:15]) into two
//   independent output bytes (soccer_left_joys/soccer_right_joys) matching
//   the PCB's real two-joystick-per-player input scheme. jtframe's generic
//   single-stick PWM emulator has no dual-independent-stick-per-player mode,
//   so this board-local module stays.
//
// Caller wiring: in the standalone core the four instances of this decoder
// (p1/p2 x left/right) live in the target-level file, outside the board top,
// and their decoded direction bits are pre-combined into soccer_left_joys/
// soccer_right_joys before reaching the board. Under jtframe, joyana_l1..r4
// are exposed directly at the GAME module boundary (see
// jtframe_common_ports.inc), so the four instances and the
// soccer_left_joys/soccer_right_joys combination logic live in
// jtdcastl_game.v. This relocation is a structural consequence of
// jtframe's port boundary, not a functional change.
//
// MAME reference: none needed -- this is a MiSTer-side analog controller
// convenience decoder with no counterpart on real PCB hardware (the real
// PCB reads true analog/optical joysticks through its own interface, not
// through this digital emulation layer).

module jtdcastl_analog
(
	input         clk,
	input         reset,
	input  [15:0] joyana,     // renamed from `analog` -- wire to whichever of
	                          // joyana_l1..l4 / joyana_r1..r4 this instance
	                          // decodes (see caller-wiring note above)
	output reg    right,
	output reg    left,
	output reg    down,
	output reg    up
);

wire signed [7:0] axis_x = joyana[7:0];
wire signed [7:0] axis_y = joyana[15:8];

always @(posedge clk) begin
	if (reset) begin
		right <= 0;
		left <= 0;
		down <= 0;
		up <= 0;
	end else begin
		if (axis_x >= 8'sd32) begin
			right <= 1;
			left <= 0;
		end else if (axis_x <= -8'sd32) begin
			right <= 0;
			left <= 1;
		end else begin
			if (right && (axis_x <= 8'sd20)) right <= 0;
			if (left && (axis_x >= -8'sd20)) left <= 0;
		end

		if (axis_y >= 8'sd32) begin
			down <= 1;
			up <= 0;
		end else if (axis_y <= -8'sd32) begin
			down <= 0;
			up <= 1;
		end else begin
			if (down && (axis_y <= 8'sd20)) down <= 0;
			if (up && (axis_y >= -8'sd20)) up <= 0;
		end
	end
end

endmodule
