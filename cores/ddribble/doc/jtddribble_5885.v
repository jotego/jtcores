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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 0.1
    Date: 01-06-2026 */

// ────────────────────────────────────────────────────────────────────────────
// jtddribble_5885 — SCHEMATIC-FACING WRAPPER for a Konami video custom
// ────────────────────────────────────────────────────────────────────────────
//
// This file's job is to expose the **005885 chip's pin interface as drawn on
// the GX690 schematic** (port names: NCPE, NXCS, DBi/DBo, R[15:0], COL[4:0],
// NCSY, NYSY, etc.). Two instances are needed per core, one for each video
// layer (silkscreen designators E16 and H16 on the PCB).
//
// The wrapper itself does NOT implement any video logic. The video work is
// done by a parameterized base module (covers BOTH 005885 and 007121, chosen
// via a MODE_5885 parameter) plus its two sub-modules, all adapted from
// Jotego's jtcontra_gfx family:
//
//     jtddribble_5885_7121_gfx.v      ← parameterized top (MODE_5885 = 0/1)
//     jtddribble_5885_7121_tilemap.v  ← tilemap state machine
//     jtddribble_5885_7121_obj.v      ← sprite engine state machine
//
// Naming convention:
//   - This wrapper file uses `5885` only because it is specific to the
//     005885 instance on the GX690 PCB.
//   - The three sub-files use `5885_7121` to signal that the implementation
//     covers both chip variants via parameterization.
//
// Those files originated as a copy of Jotego's Konami 007121 implementation
// in cores/contra/hdl/. The 007121 is documented (MAME k007121.cpp) as
// "an evolution of the 005885, with more features"; the 005885 behaves like
// a SUBSET of the 007121. Phase 2 of our build plan adds a `MODE_5885`
// parameter to the gfx file with `generate` blocks that gate the 007121-only
// features off when MODE_5885 = 1. This wrapper will then instantiate the
// gfx module with `MODE_5885(1)` and translate port names accordingly.
//
// CURRENT STATUS (initial port-list shell, before the wrapper-to-gfx wiring
// is added in Phase 2):
//   - All outputs drive safe defaults (no clock generation, no graphics,
//     no interrupts) so the module compiles cleanly and can be instantiated
//     from jtddribble_video.v
//   - No internal logic. The gfx sub-modules are present in the build but
//     not yet wired here — Phase 2 will replace these stubs with a single
//     `jtddribble_5885_gfx #(.MODE_5885(1)) u_chip (...)` instantiation
//
// Design contracts (do not change without re-reading doc/005885_implementation.md):
//   * CPU clocks (NCPE, NCPQ) come from THIS chip on the real PCB. In our
//     HDL the first instance's NCPE will drive the main CPU's `cen`
//     (Option A topology — schematic-faithful). Wiring deferred to Phase 7.
//   * The chip's 8 KB VRAM (real PCB: 6264SL) and sprite framebuffer (real
//     PCB: 2× 4464 DRAMs) live INSIDE the gfx sub-module. The CPU reaches
//     them only through the chip's CPU-bus interface (A, DBi, NXCS, NRD).
//   * Two instances of this wrapper per core (one for E16, one for H16).
//
// For collaborators: pin names below are the ACTUAL pin labels on the chip's
// die package as drawn on the schematic. Pin numbers in comments refer to
// the physical package position. This is the contract for anyone wiring the
// chip into the wider core.

module jtddribble_5885 #(
    // Sprite-color PROM bypass selector. Per MAME's ddribble_state::palette()
    // init (ddribble.cpp:109-122), sprite #2 (= our chip 2 = H16) uses pens
    // $40-$13F which are looked up through the 256-byte sprite-lookup PROM
    // at I15 — so chip 2 needs BYPASS_OPROM=0 (PROM active). Chip 1 (E16)
    // only emits tile pens $10-$3F, mapped 1:1 to palette entries, so its
    // sprite output (if any) doesn't need the PROM — BYPASS_OPROM=1 keeps
    // the pass-through that has worked so far. Each instance sets this
    // explicitly via parameter override in game.v.
    parameter BYPASS_OPROM = 1,
    // Sprite-ROM-bank routing (SCHEMATIC, see gfx wrapper for the full note).
    // Each chip's sprite patterns live in a separate ROM bank/half; force the
    // sprite fetch there. Set per-instance in game.v:
    //   chip 1 (E16, gfx1 256 KB): OBJSTART=0x10000, OBJMASK=0x0FFFF
    //   chip 2 (H16, gfx2 512 KB): OBJSTART=0x20000, OBJMASK=0x1FFFF
    parameter [17:0] OBJSTART = 18'h0_0000,
    parameter [17:0] OBJMASK  = 18'h3_FFFF,
    // Scene-replay SIMFILE names. Each chip instance loads its OWN tile/sprite
    // RAM dump so chip 1 (FG) and chip 2 (BG) don't collide on one filename.
    // Defaults keep the original single-chip names (no-op for normal sims).
    parameter SIMATTR = "gfx_attr.bin",
    parameter SIMCODE = "gfx_code.bin",
    parameter SIMOBJ  = "gfx_obj.bin"
) (
    // ------------------------------------------------------------------
    // Clocks
    //   In our HDL implementation, `clk` is the JTFRAME 24 MHz reference;
    //   CK18 is a clock-enable that pulses at the 18.432 MHz rate (derived
    //   externally in jtddribble_video.v). On the real PCB CK18 would be
    //   the actual 18.432 MHz clock pin.
    // ------------------------------------------------------------------
    input              rst,
    input              clk,
    input              CK18,         // pin 1   — 18.432 MHz tick (master video clock)

    output             NCPE,         // pin 104 — E clock to main MC6809E (Option A)
    output             NCPQ,         // pin 55  — Q clock to main MC6809E
    output             NEQ,          // pin 56  — E·Q AND (also feeds 007552 PAL G2B)
    output             NCK2,         // pin 3   — buffered clock distribution

    // ------------------------------------------------------------------
    // CPU bus
    // ------------------------------------------------------------------
    input      [13:0]  A,            // pins 50,49,98,48,97,138,47,96,137,46,95,136,45,94
    input      [ 7:0]  DBi,          // pins 52,101,142,51,100,141,99,139 (CD0..CD7) — data IN
    output     [ 7:0]  DBo,          //                                            — data OUT
    input              NXCS,         // pin 54  — chip select from main-CPU address decoder
    input              NRD,          // pin 102 — read enable (= CRTRD net on PCB)
    input              NREG,         // pin 44  — register-region select
    input              NEXR,         // pin 43  — external reset input

    // ------------------------------------------------------------------
    // CPU interrupt outputs
    // ------------------------------------------------------------------
    output             NIRQ,         // pin 41  — IRQ to main CPU
    output             NNMI,         // pin 42  — NMI to main CPU
    output             NFIR,         // pin 92  — FIRQ to main CPU

    // ------------------------------------------------------------------
    // Graphics-ROM bus (to external MASK1M pattern ROMs)
    //   chip #1 (E16) reaches 2 MASK1Ms = 256 KB (= mem.yaml `gfx1`)
    //   chip #2 (H16) reaches 4 populated MASK1Ms = 512 KB (= mem.yaml `gfx2`)
    //
    // The 005885 itself only emits 16 RA pins (R[15:0]). Each MASK1M
    // however needs 17 address pins, and chip 2 spans 4 chips (2 pairs)
    // → 18-bit byte address total. On the real PCB the missing high bits
    // are generated EXTERNALLY by an LS74 flip-flop chain (B15/A10/A11
    // on schematic page 0) that latches the chip's CHARA/CHAF2 outputs:
    //     R16  = LS74 A11 Q  (latched CHAF2 path B for "page" bit)
    //     R17  = LS74 A10 Q  (latched CHAF2 path A for "pair" bit)
    //     R17N = LS74 A10 Q-bar (selects the other chip pair)
    // We expose those two bits here as RA17, RA16. Inside the wrapper the
    // base gfx module already computes an 18-bit internal rom_addr that
    // alternates between rom_scr_addr (tiles) and rom_obj_addr (sprites);
    // we just route the top 2 bits out so game.v can drive them into the
    // SDRAM gfx-region MSBs (same role as the LS74 chain's outputs).
    // ------------------------------------------------------------------
    output             RA17,         // = base_rom_addr[17]  (LS74 A10 Q on schematic)
    output             RA16,         // = base_rom_addr[16]  (LS74 A11 Q on schematic)
    output     [15:0]  R,            // 16-bit ROM address (chip's RA0..RA15)
    input      [ 7:0]  RDU,          // upper byte (8 bits)
    input      [ 7:0]  RDL,          // lower byte (8 bits)  → 16-bit graphics word per fetch

    // ------------------------------------------------------------------
    // Sync outputs (drive JAMMA video signal chain)
    // ------------------------------------------------------------------
    output             NCSY,         // pin 4   — composite sync (active low)
    output             NYSY,         // pin 59  — vertical sync (likely "NVSY" on the schematic)

    // ------------------------------------------------------------------
    // Color outputs
    //   COL[4:0]  = final 5-bit color from this chip (one of G1COL or G2COL on schematic)
    //   VCx[3:0]  = tile-color sub-bus (tile path)
    //   BCx[3:0]  = sprite-color sub-bus
    //   VCF (pins 23,76,121,158) is GROUNDED externally on this PCB → config-mode
    //   input; we tie it internally with parameter NOT a port
    // ------------------------------------------------------------------
    output     [ 4:0]  COL,
    output     [ 3:0]  VCB, VCD,
    output     [ 3:0]  BCB, BCD, BCF,

    // ==================================================================
    // JTFRAME framework I/O — NOT present on the schematic
    // ==================================================================
    // These ports do not correspond to any pin on the real 005885 chip.
    // They exist because the underlying jtddribble_5885_7121_gfx module
    // (a parameterised copy of Jotego's jtcontra_gfx, GPL3) is written
    // in JTFRAME idiomatic style, which requires:
    //   * an SDRAM clock (`clk`) separate from the slow-logic clock (`clk24`)
    //   * clock-enable pulses (`pxl_cen`, `pxl2_cen`, `cpu_cen`) on `clk`
    //     instead of physically separate high-rate clocks
    //   * a PROM-loading interface (`prog_*`) used by JTFRAME's MRA loader
    //     at boot to populate the color-lookup PROMs from SDRAM
    //   * an SDRAM ready-handshake (`rom_ok`, `rom_cs`) — real hardware
    //     has no equivalent because mask ROMs are always-ready
    //   * debug hooks (`debug_bus`, `gfx_en`, `st_dout`) for sim/CI use
    //   * a `flip` output the wider core uses to flip-screen other modules
    //
    // When the wrapper is instantiated in jtddribble_video.v, these ports
    // are wired directly to JTFRAME-supplied signals; they do not need to
    // appear in any schematic-faithful diagram of the chip itself.
    // ------------------------------------------------------------------
    // NB: `clk` is already declared in the Clocks section above (it IS
    // the JTFRAME SDRAM clock — same physical pin name shared with the
    // schematic-Clocks block to avoid two ports with different names for
    // the same wire).
    input              clk24,               // JTFRAME 24 MHz slow-logic clock
    input              pxl_cen,             // pixel-rate clock-enable on `clk`
    input              pxl2_cen,            // 2x pixel-rate clock-enable on `clk`
    input              cpu_cen,             // CPU-rate clock-enable on `clk`

    // SDRAM ready-handshake (graphics ROM fetch)
    input              rom_ok,              // SDRAM data valid for our R[]/RDU/RDL access
    output             rom_cs,              // request to JTFRAME's SDRAM controller

    // PROM-loading interface (JTFRAME MRA loader writes color-lookup PROMs)
    input      [ 8:0]  prog_addr,
    input      [ 3:0]  prog_data,
    input              prom_we,

    // Debug / framework hooks
    output             flip,                // flip-screen state to wider core
    input      [ 7:0]  debug_bus,
    input      [ 1:0]  gfx_en,
    output     [ 7:0]  st_dout,

    // ------------------------------------------------------------------
    // V1 bring-up: raw pxl_out + pxl_pal exposed for video.v
    //
    // On the real PCB the chip's color output is the 5-bit COL bus +
    // sub-buses (VCB/VCD/BCB/BCD/BCF), all of which then feed the 007327
    // palette and tilemap-LUT PROMs. Those external chips are not yet
    // implemented (Phase 4-5 work). For early bring-up we expose the
    // base's raw 7-bit pxl_out and 4-bit pxl_pal so video.v can drive
    // RGB directly as a temporary grayscale lane. This is JTFRAME-side
    // wiring, NOT schematic-faithful — will go away when the palette
    // chain is implemented.
    // ------------------------------------------------------------------
    output     [ 6:0]  pxl_out,
    output     [ 3:0]  pxl_pal
);

// =====================================================================
// PHASE 2c — instantiate the parameterised base module
// =====================================================================
// jtddribble_5885_7121_gfx has a MODE_5885 parameter (added in 2a) that
// will gate 005885-specific behaviour. We pass MODE_5885(1) here. The
// generate blocks that ACT on the parameter are still TBD (phases 3+),
// so for now the base behaves as a full 007121 internally — wrapper
// instantiation is real, but the internals don't yet match the schematic
// 005885's behaviour. Later phases narrow that gap.
//
// What works after this commit:
//   * CPU bus (A, DBi, NXCS, NRD) reaches the base via polarity translation
//   * Graphics ROM bus (R[15:0], RDU, RDL) reaches JTFRAME's SDRAM via base
//   * Base generates real sync (HS, VS) → wrapper combines to NCSY/NYSY
//   * Base generates real CPU interrupts → wrapper passes through NIRQ/NNMI/NFIR
//   * Flip-screen, rom_cs, st_dout flow from base to wrapper's JTFRAME side
//
// What's still stubbed (deferred to later phases):
//   * NCPE, NCPQ, NEQ, NCK2 — CPU clock outputs (Phase 7 generates them
//     from the base's internal timing once Option A wiring is real)
//   * VCB, VCD, BCB, BCD, BCF — per-layer color streams; the jtcontra_gfx-
//     derived base only exposes the final mixed pxl_out. Re-exposing these
//     requires changes inside the base (Phase 4-5 work)

// Internal wires that bridge base outputs we don't expose at the
// wrapper's external interface
wire        base_lhbl, base_lvbl, base_hs, base_vs;
wire [8:0]  base_hdump, base_vdump, base_vrender, base_vrender1;
wire        base_col_cs;        // 007121 palette CS — 005885 doesn't have this
wire        base_rom_obj_sel;   // 007121-specific tile-vs-obj fetch indicator
wire [17:0] base_rom_addr;      // base produces 18 bits; wrapper exposes 16
// base_pxl_out / base_pxl_pal are now directly the wrapper's pxl_out / pxl_pal
// output ports (added for V1 bring-up). COL[4:0] is still derived from
// pxl_out's lower 5 bits below.

// Polarity translation: Konami's N-prefix (active-low) → base's active-high
wire        base_cs      = ~NXCS;     // chip-select
wire        base_cpu_rnw = ~NRD;      // read strobe → R/W (R=1, W=0)

jtddribble_5885_7121_gfx #(
    .MODE_5885    ( 1 ),             // request the 005885 subset behaviour
    .BYPASS_VPROM ( 1 ),             // 005885 has no internal tile-color PROM
                                     //   (007327 handles palette externally).
                                     //   Experiment A (set to 0) confirmed
                                     //   the chip's internal vprom would be
                                     //   empty — screen went black.
    .BYPASS_OPROM ( BYPASS_OPROM ), // per chip — chip 2 needs the I15 sprite PROM
    .OBJSTART     ( OBJSTART     ), // sprite-ROM-bank word offset (SCHEMATIC)
    .OBJMASK      ( OBJMASK      ), // sprite-local address mask
    .SIMATTR      ( SIMATTR      ), // scene-replay tile-attr RAM dump (per chip)
    .SIMCODE      ( SIMCODE      ), // scene-replay tile-code RAM dump (per chip)
    .SIMOBJ       ( SIMOBJ       )  // scene-replay sprite RAM dump (per chip)
) u_chip (
    // Clocks
    .rst         ( rst              ),
    .clk         ( clk              ),
    .clk24       ( clk24            ),
    .pxl_cen     ( pxl_cen          ),
    .pxl2_cen    ( pxl2_cen         ),
    .cpu_cen     ( cpu_cen          ),
    // Video timing — VTIMER=1 (default): base PRODUCES these, wrapper consumes
    .LHBL        ( base_lhbl        ),
    .LVBL        ( base_lvbl        ),
    .HS          ( base_hs          ),
    .VS          ( base_vs          ),
    .hdump       ( base_hdump       ),
    .vdump       ( base_vdump       ),
    .vrender     ( base_vrender     ),
    .vrender1    ( base_vrender1    ),
    // Flip + debug
    .flip        ( flip             ),
    .debug_bus   ( debug_bus        ),
    .gfx_en      ( gfx_en           ),
    .st_dout     ( st_dout          ),
    // PROM loading
    .prog_addr   ( prog_addr        ),
    .prog_data   ( prog_data        ),
    .prom_we     ( prom_we          ),
    // CPU bus (with polarity translations explained above)
    .cs          ( base_cs          ),
    .cpu_rnw     ( base_cpu_rnw     ),
    .addr        ( A                ),
    .cpu_dout    ( DBi              ),
    .dout        ( DBo              ),
    .cpu_irqn    ( NIRQ             ),    // both active-low — direct
    .cpu_nmin    ( NNMI             ),    // both active-low — direct
    .cpu_firqn   ( NFIR             ),    // both active-low — direct
    // External 007327 palette CS — internal wire only (005885 doesn't drive)
    .col_cs      ( base_col_cs      ),
    // Graphics-ROM SDRAM access
    .rom_addr    ( base_rom_addr    ),
    .rom_data    ( {RDU, RDL}       ),    // wrapper has split bytes; base wants combined
    .rom_ok      ( rom_ok           ),
    .rom_cs      ( rom_cs           ),
    .rom_obj_sel ( base_rom_obj_sel ),
    // Color outputs (base produces 7+4; wrapper exposes only lower 5 in COL.
    // For V1 bring-up the full 7+4 also escape via the new output ports.)
    .pxl_out     ( pxl_out          ),
    .pxl_pal     ( pxl_pal          )
);

// ---------------------------------------------------------------------
// Wrapper output adapters — drive schematic-named ports from base wires
// ---------------------------------------------------------------------
assign R     = base_rom_addr[15:0];   // chip's own RA0..RA15
assign RA16  = base_rom_addr[16];      // LS74-equivalent extension (was discarded pre-2026-06-03)
assign RA17  = base_rom_addr[17];      // LS74-equivalent extension
assign COL   = pxl_out[4:0];          // discard top 2 bits (007121-only attribute extras)
assign NCSY  = base_hs & base_vs;     // composite sync: 0 when EITHER H- or V-sync asserted
assign NYSY  = base_vs;               // vertical sync direct (both active-low)

// ---------------------------------------------------------------------
// Still-stubbed outputs
// ---------------------------------------------------------------------
// CPU clock outputs — Phase 7 will generate these from the base's
// internal CPU clock-enable once the Option A wiring is real
assign NCPE = 1'b0;
assign NCPQ = 1'b0;
assign NEQ  = 1'b0;
assign NCK2 = 1'b0;

// Per-layer color streams — exist on the real 005885 chip but the
// jtcontra_gfx-derived base only exposes final mixed pxl_out
assign VCB  = 4'b0;
assign VCD  = 4'b0;
assign BCB  = 4'b0;
assign BCD  = 4'b0;
assign BCF  = 4'b0;

endmodule
