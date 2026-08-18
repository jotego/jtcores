// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_audio_filter.sv, pure
// relocation onto the jtdocastle_ naming convention. No logic, timing, or
// port changed; no signal renamed. Not yet compiled or simulated against
// real jtframe tooling (Docker toolchain was down for the whole of this
// port attempt).
//
// FIX (2026-08-18): the module's own hand-rolled 49.152 MHz/1024 divider
// (`div`/`ce_audio = &div`) was correct for the ORIGINAL board's 49.152 MHz
// PLL but wrong once relocated under jtframe's 48.000 MHz clk48 base
// (48/1024 = 46.875 kHz, which also detunes both Q16 pole coefficients
// below). Removed the local `div` counter entirely; added an input port
// `cen_48k`, sourced from cfg/mem.yaml's clocks: block as an exact
// 48,000,000/1000 = 48,000 Hz mem.yaml-generated cen (same mechanism as
// cen_mclk/cen_cpu), and wired it straight into `ce_audio` in place of the
// local divider's output. See cfg/PORTING_NOTES.md.
//
// jtframe mem.yaml audio-generator redundancy check (the real open question
// for this file, per the task): read modules/jtframe/doc/audio.md and the
// "Audio Connections" / mem.yaml schema section of modules/jtframe/doc/
// jtframe-mem.md, and cross-checked against cores/docastle/cfg/mem.yaml's
// existing `audio:` draft (rsum/pre placeholders, see that file's header
// comment and cfg/PORTING_NOTES.md deviation #3).
//
// CONCLUSION: keep this as a standalone hand-written post-mix module. Do
// NOT try to fold it into mem.yaml's generated audio path. Reasoning:
//
//   1. mem.yaml's per-channel/global `rc:` filter mechanism is documented
//      (jtframe-mem.md "Audio Connections") as taking REAL schematic
//      resistor/capacitor component values (e.g. `rc: [{r: 1k, c: 33n}]`)
//      and computing the pole coefficients FROM them. This project has no
//      such schematic measurement for docastle's output stage -- mem.yaml's
//      own header comment and PORTING_NOTES.md deviation #3 already say so
//      explicitly ("No real audio RC/rsum values... no stated component
//      values to carry over"). This file's two IIR poles (the ~1.5 Hz HP/
//      AC-coupling pole at Q16 coefficient 65523/65536, and the ~12 kHz LP
//      speaker-rolloff pole at Q16 coefficient 51911/65536) are *already-
//      computed* magic coefficients with no backing R/C pair on record.
//      Reverse-engineering fake R/C values that happen to produce these
//      same coefficients just to satisfy the generator's input shape would
//      be fabricating schematic evidence that doesn't exist -- exactly the
//      kind of dishonest-pass shortcut this project's rules forbid. If real
//      component values are ever measured from the 8302 audio board, THEN
//      re-deriving this as generator-driven `rc:` entries becomes honest
//      and worth doing; not before.
//   2. Structurally, this module runs on the ALREADY-SUMMED 16-bit post-mix
//      signal (`sample_in`) as a single two-stage cascade (HP then LP) with
//      one shared `enable`/`reset`. jtframe's documented generator pieces
//      don't obviously match that shape: `dcrm` (jtframe_dcrm, the closest
//      analogue to the HP/AC-coupling stage -- "IIR filter to remove the DC
//      value of a signal") is documented as a PER-CHANNEL key in the
//      `channels:` list, not a post-mix stage; the LP `rc:` pole mechanism
//      is documented per-channel or as a single top-level `audio.rc` pole,
//      not as a second stage chained after a `dcrm`-style DC-removal stage.
//      Nothing in jtframe-mem.md's schema shows a documented "channel dcrm
//      + top-level rc in series" combination equivalent to what this module
//      does in one block.
//   3. Net effect: even setting aside the missing R/C provenance from point
//      1, the generator's documented building blocks don't cleanly express
//      this specific two-pole post-mix cascade as one generated stage today.
//
// So: this module stays hand-written and is expected to remain a genuine
// post-mix stage in the eventual jtdocastle_game.v audio chain (after
// mem.yaml's channel summing, whatever that resolves to), not something the
// mem.yaml `audio:` section can currently subsume. This is a conclusion,
// not a guess -- re-open it only if real 8302 board R/C measurements turn
// up, at which point re-deriving genuine `rc:`/`dcrm:` entries would be the
// correct (and honest) simplification.
//
// PCB reference: the 8302 audio schematic (unchanged from the original
// module's own header) -- four equal 1.5k PSG feeds already summed
// upstream; this stage models the AC-coupled MB3730 path at 48 kHz.
module jtdocastle_audio_filter
(
	input clk, input reset, input enable,
	// UNVERIFIED, matches established cen_mclk/cen_cpu convention: generated
	// by cfg/mem.yaml's clocks: block (48,000,000/1000 = 48,000 exactly),
	// same jtframe_gated_cen mechanism as cen_mclk/cen_cpu. Replaces the
	// module's own hand-rolled /1024 divider -- see fix note in the file
	// header.
	input cen_48k,
	input signed [15:0] sample_in,
	output signed [15:0] sample_out
);

wire ce_audio = cen_48k;
reg signed [31:0] x_prev, hp_state, lp_state;
reg signed [15:0] result;
wire signed [31:0] x_extended = {{16{sample_in[15]}},sample_in};
reg [2:0] filter_step;
reg signed [31:0] hp_delta_pipe, hp_next_pipe, lp_delta_pipe, lp_next_pipe;
reg signed [63:0] hp_product_pipe, lp_product_pipe;

always @(posedge clk) begin
	if (reset) begin
		filter_step <= 0;
		x_prev <= 0; hp_state <= 0; lp_state <= 0; result <= 0;
		hp_delta_pipe <= 0; hp_product_pipe <= 0; hp_next_pipe <= 0;
		lp_delta_pipe <= 0; lp_product_pipe <= 0; lp_next_pipe <= 0;
	end else begin
		// The complete IIR update still occurs once per 48 kHz sample.  Breaking
		// its two multiplies and clamp into short stages avoids a false need for
		// all of that arithmetic to settle in one 49.152 MHz clock period.
		if (ce_audio && filter_step == 0) begin
			x_prev <= x_extended;
			hp_delta_pipe <= x_extended - x_prev;
			hp_product_pipe <= hp_state * 32'sd65523; // 1.5 Hz HP pole, Q16
			filter_step <= 1;
		end else begin
			case (filter_step)
			3'd1: begin
				hp_next_pipe <= hp_delta_pipe + $signed(hp_product_pipe[47:16]);
				filter_step <= 2;
			end
			3'd2: begin
				lp_delta_pipe <= hp_next_pipe - lp_state;
				filter_step <= 3;
			end
			3'd3: begin
				lp_product_pipe <= lp_delta_pipe * 32'sd51911; // about 12 kHz LP, Q16
				filter_step <= 4;
			end
			3'd4: begin
				lp_next_pipe <= lp_state + $signed(lp_product_pipe[47:16]);
				hp_state <= hp_next_pipe;
				filter_step <= 5;
			end
			3'd5: begin
				lp_state <= lp_next_pipe;
				if (lp_next_pipe > 32'sd32767) result <= 16'sh7fff;
				else if (lp_next_pipe < -32'sd32768) result <= -16'sd32768;
				else result <= lp_next_pipe[15:0];
				filter_step <= 0;
			end
			default: filter_step <= 0;
			endcase
		end
	end
end
assign sample_out = enable ? result : sample_in;
endmodule
