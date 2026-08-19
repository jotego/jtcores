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

// Top-level game module for the Universal Do! Castle hardware family (nine
// sets across three board profiles, one RBF).
//
// It replaces the board-level top of the standalone MiSTer Universal_DoCastle
// core this core derives from, plus the parts of that core's target-level file
// which jtframe's game-module boundary absorbs (analog-stick decode,
// cabinet-byte assembly, pause, reset composition). Inter-module wiring that
// is not part of the jtframe boundary change is carried over unchanged from
// the source core: the main<->sub comm latch + main WAIT flip-flop, the
// main->spritecpu sprite staging port, the spritecpu->CF37201 doorway, the
// CF37201 pin-level DRAM interface into the video module, the CRTC register
// bus, the sub_irq_n M1/IORQ-acknowledge latch, the watchdog, and the audio
// mix order.
//
// ===========================================================================
// MEMORY BOUNDARY: GENERATED, NOT RAW
// ===========================================================================
// This core has a cfg/mem.yaml, so JTFRAME_MEMGEN is set and this module's
// `` `include "jtframe_game_ports.inc" `` expands the GENERATED mem_ports.inc,
// not the raw jtframe_mem_ports.inc SDRAM boundary. Hand-wiring ba0..ba3 here
// would reference ports that do not exist. Evidence:
//
//   * modules/jtframe/doc/sdram.md:171 -- "When a mem.yaml file exists,
//     jtframe automatically declares the JTFRAME_MEMGEN macro."
//   * modules/jtframe/src/jtframe/macros/macros.go:115-117 --
//     `mem_managed := is_mem_managed(core) ... if mem_managed {
//      Set("JTFRAME_MEMGEN", "") }`. It is never written in macros.def by
//     hand: neither cores/flstory/cfg/macros.def nor cores/castle/cfg/
//     macros.def contains it, yet both cores' game.v files use generated
//     per-bus names (flstory: main_cs/main_addr/main_data/main_ok; castle:
//     cen24/cen12/ram_addr/ram_we/ram_dout).
//   * macros.go:377-385 -- with JTFRAME_MEMGEN set, GAMETOP becomes
//     `jtdcastl_game_sdram`, an AUTO-GENERATED wrapper (template
//     modules/jtframe/hdl/inc/game_sdram.v, header: "automatically generated
//     by JTFRAME / Do not modify it / Do not add it to git"). THAT wrapper
//     owns the whole raw bank protocol -- it instantiates jtframe_rom_Nslots
//     per bank and drives ba0_addr/ba_rd/ba_dst/ba_dok/ba_rdy/ba_ack/
//     ba0_dsn/prog_* itself, and instantiates this module inside it.
//   * modules/jtframe/src/jtframe/mem/mem.go:515-577 (add_game_ports) -- when
//     the game.v contains `` `include "jtframe_game_ports.inc" ``, jtframe
//     writes cores/docastle/hdl/mem_ports.inc from the ports.v template.
//
// This file is therefore written against the generated per-bus contract,
// derived line-by-line from modules/jtframe/hdl/inc/ports.v against
// cfg/mem.yaml. Two knock-on consequences, both deliberate:
//
//   (a) cen_mclk / cen_cpu are INPUTS, generated in the wrapper by
//       jtframe_gated_cen from mem.yaml's `clocks:` block -- NOT generated
//       here with jtframe_frac_cen. ports.v emits
//       `input {{ .OutStr }}` for every clocks: output, and
//       mem/clocks.go:83 rewrites base `clk48` to `clk` when not in SDRAM96
//       mode, so both enables land in this module's own `clk` domain.
//       Instantiating jtframe_frac_cen here as well would duplicate them.
//   (b) cfg/mem.yaml's `audio:` block is commented out (with the reasoning in
//       that file) so this module keeps the plain `snd`/`sample` ports and
//       owns the mix, as the source core's board top did.
//
// ===========================================================================
// GENERATED PORT LIST THIS FILE USES (from ports.v + cfg/mem.yaml)
// ===========================================================================
//   input                     cen_mclk, cen_cpu, cen_384k, cen_48k
//   output signed [15:0]      snd            output  sample
//   input  [21:0] prog_addr   input [7:0] prog_data   input prog_we
//   input  [ 1:0] prog_ba     input [25:0] ioctl_addr input prom_we
//   input         header      (JTFRAME_HEADER=8 is set in macros.def)
//   input         ioctl_ram, ioctl_cart
//   BRAM (explicit ports, mem.go:1084-1120):
//     output [8:0] spritecpu_addr   input [7:0] spritecpu_data
//     output [8:0] cprom_addr       input [7:0] cprom_data
//   SDRAM buses (ba0: main/sub/adpcm, ba1: gfx1, ba2: gfx2):
//     output [15:0] main_addr   output main_cs   input [7:0] main_data   input main_ok
//     output [13:0] sub_addr    output sub_cs    input [7:0] sub_data    input sub_ok
//     output [15:0] adpcm_addr  output adpcm_cs  input [7:0] adpcm_data  input adpcm_ok
//     output [13:0] gfx1_addr   output gfx1_cs   input [7:0] gfx1_data   input gfx1_ok
//     output [16:0] gfx2_addr   output gfx2_cs   input [7:0] gfx2_data   input gfx2_ok
//
// ===========================================================================
// KNOWN LIMITATIONS / OPEN ITEMS
// ===========================================================================
//
// -- SDRAM / memory boundary --
//
// S1. The generated per-bus port names and widths listed above were derived
//     by reading ports.v's templates against cfg/mem.yaml. Regenerate
//     mem_ports.inc and diff it against that list when mem.yaml changes.
//
// S2. gfx1_cs / gfx2_cs ARE TIED HIGH, AND gfx1_ok / gfx2_ok ARE IGNORED.
//     This is a genuine design gap, not a wiring detail.
//     jtdcastl_video.v (and jtdcastl_pcb_sprite.v inside it) carry the
//     source core's BRAM assumption of fixed 1-cycle graphics-ROM latency: the
//     tile fetch is combinational-address/registered-data every pixel, and the
//     sprite line-buffer state machine uses a hard-coded ST_GREQ -> ST_GWAIT
//     -> ST_GUSE 3-state delay with no ready qualifier. Under SDRAM those
//     fetches will sometimes return stale bytes.
//
//     The contract being violated is stated in
//     modules/jtframe/hdl/sdram/jtframe_romrq.v:19-22: "The best use case is
//     with addr_ok going down and up for each addr change but it works too
//     with addr_ok permanently high AS LONG AS ADDR INPUT IS NOT CHANGED
//     UNTIL THE DATA_OK SIGNAL IS PRODUCED. If the requester cannot guarantee
//     that, it should toggle addr_ok for each request." Tying *_cs high (as
//     here) selects the second mode, whose precondition the sprite state
//     machine breaks: it re-loads line_gfx_addr in ST_GUSE and leaves
//     ST_GWAIT after a fixed single cycle, regardless of gfx2_ok.
//
//     A one-line `ST_GWAIT: if(gfx2_ok)` is NOT a sufficient fix.
//     jtframe_romrq's OKLATCH parameter (default 1, jtframe_romrq.v:38-41)
//     makes data_ok "high for one clock cycle after the input address"
//     changes, so a naive ok test can pass on a STALE ok from the previous
//     fetch and latch the wrong byte -- the same bug class, hidden behind code
//     that looks correct. Closing this correctly requires waveform evidence.
//
//     Two recommended fixes:
//       - toggle gfx2_cs per request (jtframe_romrq's own recommended mode
//         for requesters that move the address), or gate ST_GWAIT on a
//         freshly-cleared ok; verify against a waveform either way.
//       - move gfx1 out of SDRAM entirely: it is a fixed 16 kB on all nine
//         sets and fits in M10K as a third `bram:` entry. This is
//         config-only (mem.yaml + macros.def + mame2mra.toml region starts;
//         the generator auto-computes BRAM offsets as PROM_START+accumulated
//         size -- see the generated jtdcastl_game_sdram.v's
//         u_range_spritecpu/u_range_cprom pair) and restores tiles to the
//         exact 1-cycle latency this RTL was written for, with no risk to the
//         decap-derived video logic. It only fixes tiles; gfx2 (up to 128 kB)
//         must stay in SDRAM.
//
// S3. adpcm_cs IS TIED TO `has_adpcm` AND adpcm_ok IS IGNORED.
//     jtdcastl_adpcm.v has no cs/ok ports at all. Its address only advances
//     on the 384 kHz MSM5205 nibble tick, so SDRAM latency is very likely
//     hidden -- but that is not verified, and a bank-0 collision with the two
//     Z80 program fetches could in principle push a fetch past the tick.
//     Needs either an ok qualifier added to that module or a measured
//     worst-case bank-0 latency argument.
//
// S4. main_cs / sub_cs are outputs of jtdcastl_main.v / jtdcastl_sub.v
//     (the existing decode wire exposed as a port; the decode expression is
//     unchanged). Not yet verified: whether jtframe_sysz80's internal
//     jtframe_z80_romwait tolerates the same rom_cs being used simultaneously
//     as the SDRAM slot request. That is the normal jtcores pattern (flstory
//     does exactly this) but it has not been simulated for this core.
//
// S5. spritecpu / cprom BRAM. spritecpu_data is fed to
//     jtdcastl_spritecpu's rom_q with rom_ok tied 1'b1 (BRAM has no ok).
//     cprom_addr is {1'b0, colmix pal_addr} -- mem.yaml declares 9 address
//     bits (512 B) while the colour decode only produces 8
//     ({colour[4:0],pen[2:0]}), reproducing the source core's own
//     `.prom_addr({1'b0,prom_addr})`. Whether the 9th bit is ever meaningful
//     on the larger colour PROMs has not been established.
//
// S6. prog_addr / prog_data / prog_we / prog_ba / ioctl_addr / prom_we /
//     ioctl_ram / ioctl_cart are all accepted but only `header`-qualified
//     prog_* is used (game-ID capture, see G1). If any per-set ROM
//     re-ordering turns out to be needed, it belongs in mame2mra.toml, not
//     here.
//
// -- game ID / profile --
//
// G1. Game-ID / profile select. `game_id` is captured from byte 0 of
//     jtframe's ROM header (`header && prog_we && prog_addr[2:0]==0`), the
//     mechanism modules/jtframe/doc/core_mod.md describes as "handled
//     directly by the core's game module"; JTFRAME_HEADER=8 is set in
//     cfg/macros.def. The producing end is mame2mra.toml's `[header]`
//     section, which assigns 0x00..0x08 per set and fills unassigned header
//     bytes with 0xff rather than 0x00. That fill value matters: 0x00 decodes
//     as a valid profile (Mr. Do's Castle), so a zero fill would let a
//     missing or wrong header boot the wrong game silently, whereas 0xff hits
//     jtdcastl_profile's `default:` arm, clears `valid`, and holds the core
//     in reset via `game_id_ok`. Generated MRAs carry the expected
//     `00 FF FF FF FF FF FF FF`-style header part per set.
//
//     Desk-checked only: the capture timing on this side -- that the header
//     byte is latched at the offset assumed here -- has not been simulated.
//     jtframe's automatic per-bit header generation (`registers=[]`) could
//     also replace jtdcastl_profile.v wholesale; that is an open design
//     choice, not a defect.
//
// -- clocking / video timing --
//
// C1. cen_mclk / cen_cpu come from mem.yaml's `clocks:` block, i.e. from
//     JTFRAME_MCLK (the SDRAM clock) -- nominally 48.000 MHz, whereas the
//     source core ran the identical logic from a 49.152 MHz PLL. Both target
//     rates are exact ratios of 48 MHz, so those two enables are exact.
//
//     Two submodule dividers that would otherwise have run ~2.4% off under
//     48 MHz were converted to mem.yaml `clocks:` outputs the same way:
//     jtdcastl_adpcm.v's /128 counter became cen_384k (48,000,000/125 =
//     384,000 Hz exactly) and jtdcastl_audio_filter.v's /1024 counter
//     became cen_48k (48,000,000/1000 = 48,000 Hz exactly). Both arrive as
//     inputs to this module. See cfg/mem.yaml and those two files.
//
// C2. OPEN. ce_pix is driven from jtframe's `pxl_cen` (JTFRAME_PXLCLK=6 makes
//     pxl_cen/pxl2_cen inputs). The source core used a fixed /10 of
//     49.152 MHz = 4.9152 MHz, chosen for a jitter-free HSYNC edge.
//     jtframe's pxl_cen comes from JTFRAME_PLL, which for this core is still
//     the placeholder `jtframe_pll4914` -- a preset that does not exist yet.
//     Until that PLL is generated, the pixel rate is undefined and no video
//     timing claim can be made.
//
// C3. `sample` is produced by a local /1000 divider off clk (~48 kHz at
//     48 MHz). The board has no equivalent output; jtframe wants a sample
//     strobe when the game owns its audio chain. The rate is a plausible
//     default, not a measured board value.
//
// -- inputs --
//
// I1. CABINET POLARITY. jtframe's joystick/coin/cab_1p/service lines are
//     taken as ACTIVE LOW (evidence: cores/flstory/hdl/jtflstory_cab.v pads
//     with 2'b11 and uses NOEXTRA=4'b1111). The source core inverted
//     ACTIVE-HIGH hps_io bits to build the same bytes, so the inversions
//     cancel and the jtframe bits are used directly. Verified by construction
//     below, not by simulation.
//
// I2. OPEN. system byte bits 2 and 1. The source core drove them from two
//     separate MiSTer buttons (service_credit = joystick[16], service_mode =
//     joystick[10]). jtframe offers `service` and `dip_test`; the mapping
//     service_credit->service, service_mode->dip_test is unconfirmed. Check
//     against MAME's docastle.cpp SYSTEM port.
//
// I3. OPEN CHOICE -- soccer second joystick digital path. The source core's
//     soccer_right_joys OR'd the analog right-stick decode
//     with digital bits joystick_0[15:12] / joystick_1[15:12] (spare high
//     bits of that SAME player's own 16-bit MiSTer joystick word). With
//     JTFRAME_BUTTONS=2 joystick1/joystick2 are only [5:0] wide with no
//     spare bits, so that exact mechanism has no home under jtframe.
//     joystick3/joystick4 -- otherwise entirely idle in this 2-player-only
//     core -- are OR'd into soccer_right_joys as P1's/P2's second-stick
//     digital fallback (see the p1_r_*/p2_r_* wires and soccer_right_joys
//     below for the precedent discussion: the one other jtcores
//     two-sticks-per-player core, kchamp, packs its second stick into the
//     SAME joystick1/joystick2 word via a wider JTFRAME_BUTTONS instead, and
//     only uses joystick3/joystick4 for its cross-cabinet `link_joys` mode;
//     every other jtcores core wiring joystick3/joystick4 treats them as
//     genuine player-3/player-4 inputs). Neither precedent is an exact
//     match, and jtframe does not document a dedicated per-player
//     second-stick digital mechanism, so this is the best-supported option,
//     not a confirmed jtframe convention. It still needs mame2mra.toml/cfgstr
//     work (same dependency as G1) to route a real second controller onto
//     joystick3/joystick4 in an MRA.
//
// -- video / colour --
//
// V1. KNOWN LIMITATION -- duplicated colour path. jtdcastl_colmix.v is the
//     RGB source. It needs the pre-PROM tile pen / tile colour / sprite pixel,
//     which jtdcastl_video.v computes internally, so three additive output
//     taps (mix_tile_pen / mix_tile_color / mix_sprite_pixel) were added to
//     that module. Consequence: jtdcastl_video.v's OWN prom_addr/prom_q/
//     r/g/b path is now unused duplicated logic. It is left in place; a later
//     cleanup should remove one of the two copies so they cannot drift apart.
//     video.prom_q is fed the same cprom_data so the two stay consistent
//     meanwhile.
//
// V2. colmix blanks RGB to black outside LHBL&LVBL. The source core did not
//     blank at this stage. Kept, because it is jtframe's colmix convention,
//     but it is a difference from the source core and will show up in any
//     frame-exact MAME diff.
//
// V3. OPEN. `dip_flip` is driven from the sub CPU's TMS1025-latched
//     `flipscreen`. JTFRAME_OSD_FLIP is not set, so jtframe expects the game
//     to output it. Whether jtframe's downstream rotation/flip handling wants
//     the raw board flip bit here is unconfirmed.
//
// V4. pcb_framebuffer is tied 0 and pcb_cursor_irq is tied 0, matching the
//     source core's shipped defaults. The CF37201 framebuffer renderer stays
//     instantiated but unreachable, because it has never been confirmed
//     against a real PCB (see jtdcastl_pcb_sprite.v).
//
// ===========================================================================

module jtdcastl_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// ---------------------------------------------------------------------------
// Board-option constants. Same values the source core hard-wires.
// ---------------------------------------------------------------------------
localparam PCB_FIDELITY     = 1'b1; // watchdog + sprite-CPU/CF37201 real timing
localparam PCB_AUDIO_FILTER = 1'b1; // AC-coupled 8302 output stage model
localparam PCB_FRAMEBUFFER  = 1'b0; // CF37201 alternate renderer: OFF (see V4)
localparam PCB_CURSOR_IRQ   = 1'b0; // CRTC CURSOR-sourced IRQ research mode: OFF

wire pause = ~dip_pause;

// ---------------------------------------------------------------------------
// Game ID / profile.  See flagged item G1 -- THIS SOURCE IS UNRESOLVED.
// ---------------------------------------------------------------------------
reg  [7:0] game_id;
reg        game_id_ok;

// TODO UNRESOLVED -- placeholder wiring, not a confirmed jtframe mechanism.
// Captures byte 0 of the JTFRAME_HEADER=8 ROM header. The consuming end
// (jtdcastl_profile) is right; the PRODUCING end (mame2mra.toml [header]
// writing 0x00..0x09 per set) does not exist yet, so today this always reads
// 0x00 = Mr. Do's Castle for every one of the nine sets. Do not treat a
// booting core as evidence this works.
always @(posedge clk) begin
    if( rst ) begin
        game_id    <= 8'h00;
        game_id_ok <= 0;
    end else if( header && prog_we && prog_addr[2:0]==3'd0 ) begin
        game_id    <= prog_data;
        game_id_ok <= 1;
    end
end

wire       profile_valid, low_pen_priority, soccer_sprites,
           has_adpcm, has_joys2, native_vertical;
wire [1:0] profile;

jtdcastl_profile u_profile(
    .game_id            ( game_id           ),
    .valid              ( profile_valid     ),
    .profile            ( profile           ),
    .low_pen_priority   ( low_pen_priority  ),
    .soccer_sprites     ( soccer_sprites    ),
    .has_adpcm          ( has_adpcm         ),
    .has_joys2          ( has_joys2         ),
    .native_vertical    ( native_vertical   )
);

// ---------------------------------------------------------------------------
// Reset composition and watchdog. Carried over from the source core.
// ---------------------------------------------------------------------------
wire        watchdog_kick;
reg  [23:0] watchdog_count;
reg         watchdog_reset;
wire        base_reset        = rst | ~profile_valid | ~game_id_ok;
wire        machine_reset_raw = base_reset | watchdog_reset;
wire        machine_reset;

jtframe_rst_sync u_rst_sync(
    .rst        ( machine_reset_raw ),
    .clk        ( clk               ),
    .rst_sync   ( machine_reset     )
);

always @(posedge clk) begin
    watchdog_reset <= 0;
    if( base_reset || pause || !PCB_FIDELITY || watchdog_kick )
        watchdog_count <= 0;
    else if( cen_cpu ) begin
        if( watchdog_count >= 24'd11999999 ) begin
            watchdog_count <= 0;
            watchdog_reset <= 1;
        end else watchdog_count <= watchdog_count + 1'd1;
    end
end

// ---------------------------------------------------------------------------
// Cabinet inputs.  jtframe delivers ACTIVE-LOW bits (see flagged item I1), so
// the inversions the source core applied to hps_io's active-high words
// cancel out and the bits are placed directly into the board's byte order.
//
//   docastle joys byte  = {p2_down,p2_left,p2_up,p2_right,
//                          p1_down,p1_left,p1_up,p1_right}, active low
//   jtframe joystickN   = {b2,b1,up,down,left,right},       active low
//                          (JTFRAME_JOY_RLDU, JTFRAME_BUTTONS=2)
// ---------------------------------------------------------------------------
wire [7:0] standard_joys = { joystick2[2], joystick2[1], joystick2[3], joystick2[0],
                             joystick1[2], joystick1[1], joystick1[3], joystick1[0] };
wire [7:0] game_buttons  = { cab_1p[1], 1'b1, joystick2[5], joystick2[4],
                             cab_1p[0], 1'b1, joystick1[5], joystick1[4] };
// SYSTEM[5]=COIN1, SYSTEM[4]=COIN2 (MAME's input table). Bits 2/1 mapping is
// open item I2.
wire [7:0] game_system   = { 2'b11, coin[0], coin[1], 1'b1, service, dip_test, 1'b1 };

// Active-high copies for the Soccer OR-combination below, which the source
// core performed on active-high signals before one final inversion.
wire p1_right =~joystick1[0], p1_left=~joystick1[1],
     p1_down  =~joystick1[2], p1_up  =~joystick1[3];
wire p2_right =~joystick2[0], p2_left=~joystick2[1],
     p2_down  =~joystick2[2], p2_up  =~joystick2[3];

// Soccer profile second-stick DIGITAL fallback -- see open item I3 for the
// full reasoning behind this choice. The source core's soccer_right_joys OR'd the
// analog right-stick decode with digital bits joystick_0[15:12] /
// joystick_1[15:12], i.e. SPARE HIGH BITS of that SAME player's own 16-bit
// MiSTer joystick word. jtframe's joystick1/joystick2 are only
// `JTFRAME_BUTTONS+3:0` = 6 bits wide (JTFRAME_BUTTONS=2, cfg/macros.def)
// with no spare bits, so that exact mechanism has no home here.
//
// BEST-SUPPORTED BUT UNCONFIRMED CHOICE: joystick3 and
// joystick4 are used below as P1's and P2's second-stick digital fallback.
// docastle is a 2-player-only game, so joystick3/joystick4 -- the two extra
// joystick ports jtframe unconditionally provides (jtframe_common_ports.inc:
// `joystick1, joystick2, joystick3, joystick4`) -- are otherwise completely
// idle in this core (they were in the file's own `_unused` bus before this
// fix). Two real jtcores precedents were checked and neither is a clean
// match:
//   - cores/kchamp (Karate Champ, the one other jtcores game with two
//     joysticks per player on a single cabinet) packs its second stick into
//     the SAME player's own joystick1/joystick2 word by raising
//     JTFRAME_BUTTONS (see jtkchamp_main.v `ctrl_1p`/`ctrl_2p`), and only
//     reaches for joystick3/joystick4 in its `link_joys` mode -- a
//     *different physical cabinet* linked over a cable, not a same-cabinet
//     second stick. Following that precedent literally would mean raising
//     JTFRAME_BUTTONS core-wide (from 2 to >=6), which reshuffles the
//     joystick1/joystick2 bit layout for every one of the other eight
//     profiles sharing this one core/RBF, not just Soccer -- a much larger
//     blast radius for a fallback path that already has an analog primary.
//   - Every other jtcores core found wiring joystick3/joystick4
//     (aliens/cps1/riders/shouse/simson/track/twin16/...) treats them as
//     genuine PLAYER 3 / PLAYER 4 inputs on a real multi-player cabinet, not
//     as a second stick for players 1/2.
// Neither precedent is a perfect match, and jtframe's own docs
// (modules/jtframe/doc/inputs.md) do not document a dedicated "second
// digital stick per player" mechanism. This wiring is the best-supported
// option found (zero-macro-change, additive-only, uses genuinely otherwise-
// idle ports, same JTFRAME_JOY_RLDU bit order already used for
// joystick1/joystick2) but it is NOT a confirmed jtframe convention -- it
// also still needs mame2mra.toml/cfgstr work (out of scope here, same as
// item G1) to actually route a real second controller onto joystick3/
// joystick4 for a 2-player cabinet. Flagged explicitly per the task; revisit
// if real jtframe/mame2mra.toml guidance surfaces a documented mechanism.
wire p1_r_right=~joystick3[0], p1_r_left=~joystick3[1],
     p1_r_down =~joystick3[2], p1_r_up  =~joystick3[3];
wire p2_r_right=~joystick4[0], p2_r_left=~joystick4[1],
     p2_r_down =~joystick4[2], p2_r_up  =~joystick4[3];

// Four analog decoders, relocated here from the source core's target level
// (see jtdcastl_analog.v). Left stick = player's primary 4-way,
// right stick = the Soccer profile's second joystick.
wire p1_la_right, p1_la_left, p1_la_down, p1_la_up;
wire p2_la_right, p2_la_left, p2_la_down, p2_la_up;
wire p1_ra_right, p1_ra_left, p1_ra_down, p1_ra_up;
wire p2_ra_right, p2_ra_left, p2_ra_down, p2_ra_up;

jtdcastl_analog u_ana_1l(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_l1 ),
    .right  ( p1_la_right ), .left( p1_la_left ),
    .down   ( p1_la_down  ), .up  ( p1_la_up   )
);

jtdcastl_analog u_ana_2l(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_l2 ),
    .right  ( p2_la_right ), .left( p2_la_left ),
    .down   ( p2_la_down  ), .up  ( p2_la_up   )
);

jtdcastl_analog u_ana_1r(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_r1 ),
    .right  ( p1_ra_right ), .left( p1_ra_left ),
    .down   ( p1_ra_down  ), .up  ( p1_ra_up   )
);

jtdcastl_analog u_ana_2r(
    .clk    ( clk       ), .reset ( rst       ), .joyana( joyana_r2 ),
    .right  ( p2_ra_right ), .left( p2_ra_left ),
    .down   ( p2_ra_down  ), .up  ( p2_ra_up   )
);

wire soccer_mode = has_joys2;   // set only by the two Soccer profile IDs

// Left-hand joystick: digital d-pad OR'd with the left analog stick, exactly
// as the source core's soccer_left_joys.
wire [7:0] soccer_left_joys = ~{
    p2_down|p2_la_down, p2_left|p2_la_left, p2_up|p2_la_up, p2_right|p2_la_right,
    p1_down|p1_la_down, p1_left|p1_la_left, p1_up|p1_la_up, p1_right|p1_la_right };

// Right-hand joystick: analog stick OR'd with the joystick3/joystick4
// digital fallback, mirroring soccer_left_joys' OR pattern above and the source
// core's soccer_right_joys OR. See open item I3 for the full reasoning
// behind sourcing the digital half from joystick3/joystick4.
wire [7:0] soccer_right_joys = ~{
    p2_r_down|p2_ra_down, p2_r_left|p2_ra_left, p2_r_up|p2_ra_up, p2_r_right|p2_ra_right,
    p1_r_down|p1_ra_down, p1_r_left|p1_ra_left, p1_r_up|p1_ra_up, p1_r_right|p1_ra_right };

wire [7:0] joys_to_core  = soccer_mode ? soccer_right_joys : standard_joys;
wire [7:0] joys2_to_core = soccer_mode ? soccer_left_joys  : 8'hff;
wire [7:0] dsw1 = dipsw[ 7:0];
wire [7:0] dsw2 = dipsw[15:8];

// ---------------------------------------------------------------------------
// Main <-> sub communication: one bidirectional latch plus the ASYMMETRIC main
// WAIT flip-flop (only the main CPU ever stalls on it). Carried over from the
// source core, and consistent with the WAIT-handshake asymmetry finding
// recorded in jtdcastl_sub.v's header.
// ---------------------------------------------------------------------------
reg  [7:0] comm_latch;
reg        main_wait;
wire [7:0] main_comm_dout, sub_comm_dout;
wire       main_comm_start, main_comm_write, sub_comm_access, sub_comm_write;

always @(posedge clk) begin
    if( machine_reset ) begin
        comm_latch <= 0;
        main_wait  <= 0;
    end else begin
        if( main_comm_write ) comm_latch <= main_comm_dout;
        if( sub_comm_write  ) comm_latch <= sub_comm_dout;
        if( main_comm_start ) main_wait  <= 1;
        if( sub_comm_access ) main_wait  <= 0;
    end
end

// ---------------------------------------------------------------------------
// Shared buses between the three CPUs, the CF37201 and the video pipeline.
// ---------------------------------------------------------------------------
wire [ 8:0] spr_addr;
wire [ 7:0] spr_din;
wire        spr_we;
wire [ 9:0] video_addr, color_addr;
wire [ 7:0] video_din, color_din, video_q, color_q;
wire        video_we, color_we;
wire [ 4:0] crtc_reg;
wire [ 7:0] crtc_data;
wire        crtc_we;
wire        sub_nmi_req, flipscreen;
wire        main_irq_n, sub_irq_req, sprite_nmi_req;
wire [ 8:0] sprite_copy_addr;
wire [ 7:0] sprite_copy_data;
wire        sprite_copy_we;
wire [10:0] cf_addr;
wire [ 7:0] cf_data;
wire        cf_we, cf_irq_req, cf_irq_ack;
wire [ 7:0] cf_dram_addr;
wire [15:0] cf_dram_address;
wire        cf_dram_strobe, cf_dram_column;
wire [ 7:0] cf_dram_y, cf_dram_x;
wire [ 4:0] cf_palette;
wire        cf_flip_x, cf_flip_y, cf_plus_one, cf_serial_invert;
wire        cf_busy, cf_overrun;
wire [ 7:0] cf_reg2;
wire [ 8:0] h_count, v_count;
wire        crtc_cursor, renderer_busy, renderer_overrun;
wire [ 7:0] adpcm_status, adpcm_data_cpu;
wire        adpcm_wr;
wire signed [11:0] adpcm_sound;
wire signed [15:0] psg_audio;
wire [15:0] main_pc, sub_pc, sprite_pc;
wire [ 3:0] psg_ready;
wire        main_m1_n, main_iorq_n, sub_m1_n, sub_iorq_n;
wire [ 3:0] mix_tile_pen;
wire [ 4:0] mix_tile_color;
wire [ 9:0] mix_sprite_pixel;
wire [ 7:0] pal_addr;
wire        adpcm_busy, adpcm_strobe;
wire [17:0] adpcm_nibble;

// Sub-CPU interrupt: set by the CRTC's MA6 edge, cleared on the sub CPU's own
// M1+IORQ acknowledge, as on the board.
reg  sub_irq_n;
wire sub_iack = ~sub_m1_n & ~sub_iorq_n;

always @(posedge clk) begin
    if( machine_reset ) sub_irq_n <= 1;
    else begin
        if( sub_iack    ) sub_irq_n <= 1;
        if( sub_irq_req ) sub_irq_n <= 0;
    end
end

/* verilator tracing_on */
// ---------------------------------------------------------------------------
// Main CPU
// ---------------------------------------------------------------------------
jtdcastl_main u_main(
    .rst            ( machine_reset     ),
    .clk            ( clk               ),
    .ce_cpu         ( cen_cpu           ),
    .pause          ( pause             ),
    .profile        ( profile           ),
    .irq_n          ( main_irq_n        ),
    // ROM -- SDRAM bank 0, bus `main`
    .rom_q          ( main_data         ),
    .rom_addr       ( main_addr         ),
    .rom_cs         ( main_cs           ),
    .rom_ok         ( main_ok           ),
    // sub CPU mailbox
    .comm_latch     ( comm_latch        ),
    .comm_dout      ( main_comm_dout    ),
    .comm_start     ( main_comm_start   ),
    .comm_write     ( main_comm_write   ),
    .comm_wait_n    ( ~main_wait        ),
    // sprite staging latch, read back by the sprite/protection CPU
    .sprite_addr    ( spr_addr          ),
    .sprite_din     ( spr_din           ),
    .sprite_we      ( spr_we            ),
    // tile / colour RAM
    .video_addr     ( video_addr        ),
    .video_din      ( video_din         ),
    .video_dout     ( video_q           ),
    .video_we       ( video_we          ),
    .color_addr     ( color_addr        ),
    .color_din      ( color_din         ),
    .color_dout     ( color_q           ),
    .color_we       ( color_we          ),
    // ADPCM control port (Soccer profile only)
    .adpcm_status   ( adpcm_status      ),
    .adpcm_wr       ( adpcm_wr          ),
    .adpcm_data     ( adpcm_data_cpu    ),
    // HD6845S register bus
    .crtc_reg       ( crtc_reg          ),
    .crtc_data      ( crtc_data         ),
    .crtc_we        ( crtc_we           ),
    .sub_nmi_req    ( sub_nmi_req       ),
    .watchdog_kick  ( watchdog_kick     ),
    // debug
    .cpu_addr_debug ( main_pc           ),
    .m1_n_debug     ( main_m1_n         ),
    .iorq_n_debug   ( main_iorq_n       )
);

// ---------------------------------------------------------------------------
// Sub / sound CPU (also carries the four SN76489A PSGs)
// ---------------------------------------------------------------------------
jtdcastl_sub u_sub(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_cpu         ( cen_cpu           ),
    .ce_psg         ( cen_cpu           ),
    .pause          ( pause             ),
    .profile        ( profile           ),
    .irq_n          ( sub_irq_n         ),
    .nmi_req        ( sub_nmi_req       ),
    // ROM -- SDRAM bank 0, bus `sub`
    .rom_q          ( sub_data          ),
    .rom_addr       ( sub_addr          ),
    .rom_cs         ( sub_cs            ),
    .rom_ok         ( sub_ok            ),
    // main CPU mailbox
    .comm_latch     ( comm_latch        ),
    .comm_dout      ( sub_comm_dout     ),
    .comm_access    ( sub_comm_access   ),
    .comm_write     ( sub_comm_write    ),
    // TMS1025 input multiplexer
    .dsw1           ( dsw1              ),
    .dsw2           ( dsw2              ),
    .joys           ( joys_to_core      ),
    .joys2          ( joys2_to_core     ),
    .buttons        ( game_buttons      ),
    .system         ( game_system       ),
    .flipscreen     ( flipscreen        ),
    // audio
    .audio          ( psg_audio         ),
    // debug
    .cpu_addr_debug ( sub_pc            ),
    .m1_n_debug     ( sub_m1_n          ),
    .iorq_n_debug   ( sub_iorq_n        ),
    .psg_ready_debug( psg_ready         )
);

// ---------------------------------------------------------------------------
// 8301 sprite / protection CPU. Its 512-byte program ROM is a BRAM block
// (mem.yaml `bram: spritecpu`, prom: true) -- no ok handshake exists, so
// rom_ok is tied high. See flagged item S5.
// ---------------------------------------------------------------------------
jtdcastl_spritecpu u_spritecpu(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_cpu         ( cen_cpu           ),
    .pause          ( pause             ),
    .pcb_fidelity   ( PCB_FIDELITY      ),
    .nmi_req        ( sprite_nmi_req    ),
    .cf_irq_req     ( cf_irq_req        ),
    // staging latch written by the main CPU
    .main_addr      ( spr_addr          ),
    .main_data      ( spr_din           ),
    .main_we        ( spr_we            ),
    // ROM -- BRAM
    .rom_q          ( spritecpu_data    ),
    .rom_addr       ( spritecpu_addr    ),
    .rom_ok         ( 1'b1              ),
    // first-phase copy (observed only)
    .copy_addr      ( sprite_copy_addr  ),
    .copy_data      ( sprite_copy_data  ),
    .copy_we        ( sprite_copy_we    ),
    // second phase: the CF37201 doorway
    .cf_addr        ( cf_addr           ),
    .cf_data        ( cf_data           ),
    .cf_we          ( cf_we             ),
    .cf_irq_ack     ( cf_irq_ack        ),
    .cpu_addr_debug ( sprite_pc         )
);

/* verilator tracing_off */
// ---------------------------------------------------------------------------
// CF37201N (TI TAL004) custom sprite chip
// ---------------------------------------------------------------------------
jtdcastl_cf37201 u_cf37201(
    .clk            ( clk               ),
    .reset          ( machine_reset     ),
    .ce_mclk        ( cen_mclk          ),
    .bus_we         ( cf_we             ),
    .bus_addr       ( cf_addr[1:0]      ),
    .bus_data       ( cf_data           ),
    .frame_parity   ( v_count[0]        ),
    .irq_ack        ( cf_irq_ack        ),
    .irq_req        ( cf_irq_req        ),
    .dram_addr      ( cf_dram_addr      ),
    .dram_address   ( cf_dram_address   ),
    .dram_strobe    ( cf_dram_strobe    ),
    .dram_column    ( cf_dram_column    ),
    .dram_y         ( cf_dram_y         ),
    .dram_x         ( cf_dram_x         ),
    .palette        ( cf_palette        ),
    .flip_x         ( cf_flip_x         ),
    .flip_y         ( cf_flip_y         ),
    .plus_one       ( cf_plus_one       ),
    .serial_invert  ( cf_serial_invert  ),
    .busy           ( cf_busy           ),
    .overrun        ( cf_overrun        ),
    .reg2_debug     ( cf_reg2           )
);

/* verilator tracing_on */
// ---------------------------------------------------------------------------
// Video: HD6845S CRTC, tile/colour/sprite RAM, sprite line buffers and the
// CF37201 alternate framebuffer renderer.
//
// Graphics ROMs come from SDRAM bank 1 (gfx1, tiles) and bank 2 (gfx2,
// sprites) with their cs tied high and their ok IGNORED -- flagged item S2,
// the single biggest known correctness gap in this integration.
// ---------------------------------------------------------------------------
jtdcastl_video u_video(
    .clk                ( clk               ),
    .reset              ( machine_reset     ),
    .ce_pix             ( pxl_cen           ),
    .cursor_irq_mode    ( PCB_CURSOR_IRQ    ),
    .pcb_framebuffer    ( PCB_FRAMEBUFFER   ),
    .flipscreen         ( flipscreen        ),
    .low_pen_priority   ( low_pen_priority  ),
    .soccer_sprites     ( soccer_sprites    ),
    // CPU-side RAM ports
    .video_cpu_addr     ( video_addr        ),
    .video_cpu_din      ( video_din         ),
    .video_cpu_we       ( video_we          ),
    .video_cpu_q        ( video_q           ),
    .color_cpu_addr     ( color_addr        ),
    .color_cpu_din      ( color_din         ),
    .color_cpu_we       ( color_we          ),
    .color_cpu_q        ( color_q           ),
    .sprite_cpu_addr    ( spr_addr          ),
    .sprite_cpu_din     ( spr_din           ),
    .sprite_cpu_we      ( spr_we            ),
    // C000-C1FF is the physical 512-byte sprite doorway. C432 is the
    // protection/CF control latch and must never corrupt sprite RAM.
    .pcb_sprite_addr    ( cf_addr[8:0]      ),
    .pcb_sprite_din     ( cf_data           ),
    .pcb_sprite_we      ( cf_we && (cf_addr < 11'h200) ),
    // CF37201 pin-level DRAM interface
    .cf_dram_address    ( cf_dram_address   ),
    .cf_dram_strobe     ( cf_dram_strobe    ),
    .cf_dram_column     ( cf_dram_column    ),
    .cf_dram_y          ( cf_dram_y         ),
    .cf_dram_x          ( cf_dram_x         ),
    .cf_palette         ( cf_palette        ),
    .cf_flip_x          ( cf_flip_x         ),
    .cf_flip_y          ( cf_flip_y         ),
    .cf_plus_one        ( cf_plus_one       ),
    .cf_serial_invert   ( cf_serial_invert  ),
    // graphics ROMs
    .char_addr          ( gfx1_addr         ),
    .char_q             ( gfx1_data         ),
    .sprite_gfx_addr    ( gfx2_addr         ),
    .sprite_gfx_q       ( gfx2_data         ),
    // colour PROM: this module's own copy of the decode is dead in the
    // jtframe integration (flagged item V1); jtdcastl_colmix drives the
    // real cprom_addr. prom_q is fed the same data so both stay consistent.
    .prom_addr          (                   ),
    .prom_q             ( cprom_data        ),
    // CRTC register bus
    .crtc_reg           ( crtc_reg          ),
    .crtc_data          ( crtc_data         ),
    .crtc_we            ( crtc_we           ),
    // dead RGB path -- see flagged item V1
    .r                  (                   ),
    .g                  (                   ),
    .b                  (                   ),
    .HS                 ( HS                ),
    .VS                 ( VS                ),
    .LHBL               ( LHBL              ),
    .LVBL               ( LVBL              ),
    // colour-mix taps into jtdcastl_colmix
    .mix_tile_pen       ( mix_tile_pen      ),
    .mix_tile_color     ( mix_tile_color    ),
    .mix_sprite_pixel   ( mix_sprite_pixel  ),
    // interrupts
    .main_irq_n         ( main_irq_n        ),
    .sub_irq_req        ( sub_irq_req       ),
    .sprite_nmi_req     ( sprite_nmi_req    ),
    // debug
    .h_count_debug      ( h_count           ),
    .v_count_debug      ( v_count           ),
    .cursor_debug       ( crtc_cursor       ),
    .renderer_busy_debug( renderer_busy     ),
    .renderer_overrun_debug( renderer_overrun )
);

// ---------------------------------------------------------------------------
// Colour mixer: tile/sprite priority + the 3/3/2-bit weighted resistor PROM
// DAC, truncated losslessly to JTFRAME_COLORW=3 per channel.
// ---------------------------------------------------------------------------
jtdcastl_colmix u_colmix(
    .rst                ( machine_reset     ),
    .clk                ( clk               ),
    .pxl_cen            ( pxl_cen           ),
    .lvbl               ( LVBL              ),
    .lhbl               ( LHBL              ),
    .low_pen_priority   ( low_pen_priority  ),
    .tile_pen           ( mix_tile_pen      ),
    .tile_color         ( mix_tile_color    ),
    .sprite_pixel       ( mix_sprite_pixel  ),
    .pal_addr           ( pal_addr          ),
    .pal_dout           ( cprom_data        ),
    .red                ( red               ),
    .green              ( green             ),
    .blue               ( blue              ),
    .debug_bus          ( debug_bus         ),
    .gfx_en             ( gfx_en            )
);

// mem.yaml declares cprom with 9 address bits; the decode only produces 8,
// exactly as the source core's `.prom_addr({1'b0,prom_addr})`. See item S5.
assign cprom_addr = { 1'b0, pal_addr };

/* verilator tracing_off */
// ---------------------------------------------------------------------------
// MSM5205 ADPCM (Indoor / American Soccer only).
// adpcm_cs is held while the profile enables the channel; adpcm_ok is ignored.
// See flagged item S3.
// ---------------------------------------------------------------------------
jtdcastl_adpcm u_adpcm(
    .clk                ( clk               ),
    .reset              ( machine_reset     ),
    .pause              ( pause             ),
    .enabled            ( has_adpcm         ),
    .cen_384k           ( cen_384k          ),
    .control_wr         ( adpcm_wr          ),
    .control_data       ( adpcm_data_cpu    ),
    .status             ( adpcm_status      ),
    .rom_addr           ( adpcm_addr        ),
    .rom_q              ( adpcm_data        ),
    .sound              ( adpcm_sound       ),
    .busy_debug         ( adpcm_busy        ),
    .nibble_pos_debug   ( adpcm_nibble      ),
    .nibble_strobe_debug( adpcm_strobe      )
);

// ---------------------------------------------------------------------------
// SDRAM slot requests that no submodule owns. See flagged items S2 and S3.
// ---------------------------------------------------------------------------
assign gfx1_cs  = 1'b1;
assign gfx2_cs  = 1'b1;
assign adpcm_cs = has_adpcm;

// ---------------------------------------------------------------------------
// Audio. Mix order as on the board:
//   * jtdcastl_sub already sums the four SN76489As and scales by 8.
//   * MAME's MSM5205 stream is signal/4096, low two bits masked for the
//     physical 10-bit DAC, routed at 0.40 -> gain 3.20 in signed-16 units.
//     13/4 = 3.25 is the nearest compact fixed-point gain, +0.135 dB off.
//   * clamp, then the AC-coupled 8302 output-stage IIR model.
// ---------------------------------------------------------------------------
wire signed [17:0] psg_mix      = {{2{psg_audio[15]}}, psg_audio};
wire signed [11:0] adpcm_dac    = { adpcm_sound[11:2], 2'b00 };
wire signed [17:0] adpcm_scaled = $signed(adpcm_dac) * 18'sd13;
wire signed [17:0] adpcm_mix    = adpcm_scaled >>> 2;
wire signed [18:0] full_mix     = {psg_mix[17],psg_mix} + {adpcm_mix[17],adpcm_mix};
reg  signed [15:0] mixed_audio;
wire signed [15:0] filtered_audio;

always @(*) begin
    if     ( full_mix >  19'sd32767 ) mixed_audio =  16'sh7fff;
    else if( full_mix < -19'sd32768 ) mixed_audio = -16'sd32768;
    else                              mixed_audio =  full_mix[15:0];
end

jtdcastl_audio_filter u_audio_filter(
    .clk        ( clk               ),
    .reset      ( machine_reset     ),
    .enable     ( PCB_AUDIO_FILTER  ),
    .cen_48k    ( cen_48k           ),
    .sample_in  ( mixed_audio       ),
    .sample_out ( filtered_audio    )
);

// Pixel clock enables. The board runs the pixel rate at MCLK/2, so both come
// from the same mem.yaml generator entry.
assign pxl2_cen = cen_mclk;
assign pxl_cen  = cen_pxl;

assign snd = (machine_reset || pause) ? 16'sd0 : filtered_audio;

// `sample` strobe. The board has no equivalent; ~48 kHz from a /1000 divider
// off clk. See item C3.
reg [9:0] sample_cnt;
reg       sample_r;

always @(posedge clk) begin
    if( rst ) begin
        sample_cnt <= 0;
        sample_r   <= 0;
    end else begin
        sample_r <= 0;
        if( sample_cnt==10'd999 ) begin
            sample_cnt <= 0;
            sample_r   <= 1;
        end else sample_cnt <= sample_cnt + 1'd1;
    end
end

assign sample = sample_r;

// ---------------------------------------------------------------------------
// Miscellaneous jtframe outputs
// ---------------------------------------------------------------------------
assign dip_flip = flipscreen;   // flagged item V3

reg [7:0] st_mux;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        2'd0: st_mux <= game_id;
        2'd1: st_mux <= { 3'd0, game_id_ok, profile_valid, native_vertical, profile };
        2'd2: st_mux <= { renderer_overrun, renderer_busy, cf_overrun, cf_busy,
                          adpcm_busy, main_wait, watchdog_reset, crtc_cursor };
        2'd3: st_mux <= cf_reg2;
    endcase
end

assign debug_view = st_mux;

// Signals kept for traceability/debug but not consumed by any jtframe port.
wire _unused = &{ 1'b0, main_pc, sub_pc, sprite_pc, psg_ready, main_m1_n,
                  main_iorq_n, sprite_copy_addr, sprite_copy_data,
                  sprite_copy_we, cf_dram_addr, cf_flip_x, cf_flip_y,
                  cf_plus_one, cf_serial_invert, cf_palette, h_count,
                  adpcm_nibble, adpcm_strobe, gfx1_ok, gfx2_ok, adpcm_ok,
                  joyana_l3, joyana_l4, joyana_r3,
                  joyana_r4, dial_x, dial_y, snd_en, snd_vol, status,
                  dipsw[31:16], dip_fxlevel, tilt, prog_ba, prom_we,
                  ioctl_addr, ioctl_ram, ioctl_cart, rst24, clk24, rst96,
                  clk96, pxl2_cen, cab_1p[3:2], coin[3:2] };

endmodule
