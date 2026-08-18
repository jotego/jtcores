// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_adpcm.sv, relocated as-is
// onto jtframe's module-naming convention, not yet compiled or simulated
// against real jtframe tooling (Docker toolchain was down for the whole of
// this port attempt).
//
// FIX (2026-08-18): the module's own hand-rolled 49.152 MHz/128 divider was
// correct for the ORIGINAL board's 49.152 MHz PLL but wrong once relocated
// under jtframe's 48.000 MHz clk48 base (48/128 = 375 kHz, -2.4% off the
// real 384 kHz MSM5205 input clock). Removed the local `cen_div`/`ce_384k`
// counter entirely; added an input port `cen_384k`, sourced from
// cfg/mem.yaml's clocks: block as an exact 48,000,000/125 = 384,000 Hz
// mem.yaml-generated cen (same mechanism as cen_mclk/cen_cpu), and wired it
// straight into the jt5205 `.cen()` port (ANDed with `!pause`, preserving
// the original pause-gating behaviour). See cfg/PORTING_NOTES.md.
//
// jt5205 port-list check (the one real integration risk this file carries):
// the task flagged that mrdo vendors its own copy of jt5205 at
// mrdo/rtl/jt5205/jt5205.v, while this jtcores clone has a REAL
// modules/jt5205 git submodule (confirmed present via
// cores/docastle/cfg/files.yaml's existing `jt5205:` empty block, which
// follows the same "module supplies its own files.yaml" pattern as
// jt007232/jt051649/jtopl2 in cores/castle/cfg/files.yaml). The submodule's
// working tree was NOT checked out in this clone (modules/jt5205 is an
// uninitialized git submodule -- only a .git gitlink file present, no
// working files), so the comparison below was done read-only against the
// submodule's pinned commit content (`git -C modules/jt5205 show
// HEAD:hdl/jt5205.v`, commit cd3cb83 "new jtframe file layout") rather than
// a checked-out file, without running `git submodule update` or otherwise
// touching git state.
//
// RESULT: the two jt5205.v files are IDENTICAL at the port/parameter level.
// Same module name (jt5205), same port order/names/widths/directions
// (rst, clk, cen /* direct_enable */, sel[1:0], din[3:0], sound (signed
// [11:0]), sample, irq, vclk_o, plus the JT5205_DEBUG-gated debug ports),
// same parameter names and defaults (INTERPOL=0, VCLK_CEN=1). The only
// difference is mrdo's vendored copy has its explanatory comments stripped
// (e.g. the "s pin" port comment, the Chun Li/SF2 INTERPOL rationale, the
// "irq active even during rst" note) -- purely cosmetic, zero functional or
// timing difference. So the instantiation below is an unmodified carry-over
// of docastle_adpcm.sv's original `decoder` instance; there is no port-list
// divergence to reconcile. Flagging this explicitly per the task instead of
// silently assuming identity.
//
// Everything else in this file -- the MSM5205 control-latch edge semantics
// (D7 falling stops / D6 falling starts, start-wins-on-simultaneous-edge
// per MAME's idsoccer_state), the D1:D0 4x0x4000-byte/0x8000-nibble bank
// select, the high-nibble-before-low-nibble ROM nibble sequencing, and the
// 49.152 MHz/128 = 384 kHz MSM5205 input-clock divider -- is UNCHANGED
// logic, only re-hosted under the jtdocastle_ module name. No signal was
// renamed; the port list is identical to docastle_adpcm.sv's.
//
// MAME reference: src/mame/universal/docastle.cpp idsoccer_state ADPCM
// handling (unchanged from the original module's own header).
//
// NOT YET WIRED: this module is not yet instantiated from a jtdocastle_game.v
// (that top-level game module doesn't exist in this draft -- see
// cores/docastle/cfg/PORTING_NOTES.md "Remaining work" item 1). jtdocastle_
// main.v already exposes the CPU-side adpcm_status/adpcm_wr/adpcm_data ports
// this module's control_data/control_wr/status ports are expected to
// connect to, and cfg/mem.yaml's sdram.banks `adpcm` bus (ba0, 16-bit
// addr_width, offset ADPCM_OFFSET) is expected to supply rom_addr/rom_q --
// neither connection is made here, consistent with this module being a pure
// building-block relocation, not a wired-up top.
module jtdocastle_adpcm
(
	input               clk,
	input               reset,
	input               pause,
	input               enabled,
	input               control_wr,
	input         [7:0] control_data,
	output        [7:0] status,

	// UNVERIFIED, matches established cen_mclk/cen_cpu convention: generated
	// by cfg/mem.yaml's clocks: block (48,000,000/125 = 384,000 exactly),
	// same jtframe_gated_cen mechanism as cen_mclk/cen_cpu. Replaces the
	// module's own hand-rolled /128 divider -- see fix note below.
	input               cen_384k,

	output       [15:0] rom_addr,
	input         [7:0] rom_q,

	output signed [11:0] sound,
	output              busy_debug,
	output       [17:0] nibble_pos_debug,
	output              nibble_strobe_debug
);

reg [7:0] control;
reg idle;
reg [17:0] nibble_pos;
reg [17:0] nibble_end;

wire stop_edge = control_wr && control[7] && !control_data[7];
wire start_edge = control_wr && control[6] && !control_data[6];
wire [17:0] selected_start = {1'b0,control_data[1:0],15'b0};

assign status = idle ? 8'h00 : 8'h80;
assign busy_debug = !idle;
assign nibble_pos_debug = nibble_pos;
assign rom_addr = nibble_pos[16:1];

// Fix (2026-08-18): the board's exact 384 kHz MSM5205 input clock used to be
// derived here as 49.152 MHz / 128, correct only for the original PCB's PLL.
// jtframe's base clock is 48.000 MHz, so that same /128 divider produced
// 375 kHz instead (-2.4%). Now sourced directly from cfg/mem.yaml's
// cen_384k (an exact 48,000,000/125 = 384,000 Hz integer division) instead
// of a local counter. `pause` gating moves to the consumer (the jt5205
// .cen() port already ANDs with idle/enabled via .rst(), so it is applied
// the same way here).
wire ce_384k = cen_384k && !pause;

wire [3:0] adpcm_din = nibble_pos[0] ? rom_q[3:0] : rom_q[7:4];
wire vclk_irq;
wire sample_unused;
wire vclk_unused;

jt5205 #(.INTERPOL(0), .VCLK_CEN(1)) decoder
(
	.rst(reset | idle | !enabled),
	.clk(clk),
	.cen(ce_384k),
	.sel(2'd2),
	.din(adpcm_din),
	.sound(sound),
	.sample(sample_unused),
	.irq(vclk_irq),
	.vclk_o(vclk_unused)
);

assign nibble_strobe_debug = vclk_irq && !idle && enabled;

always @(posedge clk) begin
	if (reset || !enabled) begin
		control <= 0;
		idle <= 1;
		nibble_pos <= 0;
		nibble_end <= 0;
	end else begin
		// Reset on the master clock immediately after the final valid nibble.
		if (!idle && (nibble_pos >= nibble_end))
			idle <= 1;

		if (vclk_irq && !idle && !pause)
			nibble_pos <= nibble_pos + 1'd1;

		if (control_wr) begin
			if (stop_edge)
				idle <= 1;

			// This is intentionally after stop so a simultaneous pair of
			// falling edges follows MAME's start-wins ordering.
			if (start_edge) begin
				nibble_pos <= selected_start;
				nibble_end <= selected_start + 18'h08000;
				idle <= 0;
			end

			control <= control_data;
		end
	end
end

wire _unused = sample_unused | vclk_unused;

endmodule
