# docastle jtframe cfg/ draft -- porting notes

Status: **desk-check draft only**. Nothing in `cores/docastle/cfg/` has been
run through `jtframe files`, `jtframe mem`, `jtframe mra`, `jtsim`, or any
Docker/jtcore CLI step. The toolchain was not confirmed working before this
task started, and none of it was invoked here per the task instructions. RTL
was not copied; only the four `cfg/` files were written, closely modeled on
`cores/flstory/cfg/` and cross-checked against `cores/castle/cfg/` for
clock-pattern syntax only.

Ground truth used throughout: `scripts/romsets.json`,
`rtl/docastle_core.sv`, `rtl/docastle_main.sv`, `rtl/docastle_sub.sv`,
`rtl/docastle_spritecpu.sv`, `rtl/docastle_rom.sv`, `rtl/docastle_video.sv`
(colour PROM decode), `Universal_DoCastle.sv` (joystick bit order), `README.md`
and `rtl/THIRD_PARTY.md`, all in `D:\Arcade\AI\aCORES\mrdo`.

## Files written

- `cores/docastle/cfg/macros.def`
- `cores/docastle/cfg/mem.yaml`
- `cores/docastle/cfg/files.yaml`
- `cores/docastle/cfg/reg.yaml`
- `cores/docastle/cfg/PORTING_NOTES.md` (this file)

## ROM-bank-to-mem.yaml mapping decision (the core judgment call)

7 real ROM regions from `scripts/romsets.json`, against jtframe's 1-4 SDRAM
bank limit (`sdram.banks` must contain 1-4 banks; each bank can carry several
offset-selected buses sharing one physical SDRAM port, per
`modules/jtframe/doc/jtframe-mem.md`):

| Region | Size (max, across all 9 sets) | Confirmed width in docastle_rom.sv | Destination |
|---|---|---|---|
| maincpu | 64 KB | `main_rom[0:65535]`, `main_addr[15:0]` | SDRAM ba0, bus `main` |
| subcpu | 16 KB | `sub_rom[0:16383]`, `sub_addr[13:0]` | SDRAM ba0, bus `sub` (offset) |
| adpcm | 64 KB slot (Soccer profile only, others zero-filled) | `adpcm_rom[0:65535]`, `adpcm_addr[15:0]` | SDRAM ba0, bus `adpcm` (offset) |
| gfx1 (tiles/chars) | 16 KB, fixed on every set | `char_rom[0:16383]`, `char_addr[13:0]` | SDRAM ba1, bus `gfx1` |
| gfx2 (sprites) | 128 KB slot | `sprite_gfx_rom[0:131071]`, `sprite_gfx_addr[16:0]` | SDRAM ba2, bus `gfx2` |
| spritecpu | 512 B, **identical CRC32 `2747ca77` on all 9 sets** | `sprite_cpu_rom[0:511]`, addr 9-bit | BRAM, `prom: true` |
| proms (colour) | 256-512 B | `color_prom[0:511]`, `prom_addr[8:0]` | BRAM, `prom: true` |

Rationale:

- **Bank grouping follows bandwidth, not just region count**, the same
  principle flstory and castle both apply, just landing on a different split
  because the hardware is different:
  - flstory groups **3** program ROMs (main+sub+user1, all CPU-fetch-rate
    consumers) onto one bus/bank via `offset:` params, and gives its
    (higher-bandwidth, continuously streamed) `snd` region and its combined
    `scr`+`obj` graphics region their own banks.
  - castle keeps `main` alone on ba0, groups its **3** sound-related buses
    (`snd`+`pcma`+`pcmb`) onto ba1, and gives each of `gfx1`/`gfx2` (its
    highest-bandwidth, per-pixel graphics fetch paths) a dedicated bank.
  - docastle: `main`+`sub`+`adpcm` are grouped onto ba0 for the *same reason*
    flstory groups main+sub+user1 -- all three are low, roughly
    CPU-instruction-fetch-rate (or slower: ADPCM is a serial nibble-rate
    consumer) bandwidth users, so time-sharing one physical SDRAM port via
    offset addressing is the correct call. `gfx1` (tiles) and `gfx2`
    (sprites) each get a dedicated bank because both are per-pixel/per-line
    graphics fetch paths -- `gfx2` in particular is read continuously by the
    CF37201 sprite chip on every active scanline, the same bandwidth argument
    castle uses to split its own gfx1/gfx2 onto separate banks.
  - Net result: **3 of the 4 available banks used** (ba0, ba1, ba2), ba3
    left free. This is a deliberate choice, not an oversight -- neither
    template maxes out at 4 banks either, and there is no region here that
    needs a 4th independent port.
- **spritecpu and the colour PROM go to BRAM, not SDRAM**, following the
  exact precedent of flstory's own `mcu` BRAM block (an MC6805 program ROM,
  `prom: true`, tiny and instruction-fetch-rate). spritecpu's content is
  small (512 B) and, notably, **byte-for-byte identical across every one of
  the 9 romsets.json sets** (crc32 `2747ca77` on all of them) -- it behaves
  like a fixed lookup PROM in practice even though MAME calls the region
  `spritecpu`. The colour PROM is the conventional "PROMs go to BRAM" case
  every jtcores core follows.
- All BRAM/SDRAM `addr_width` values were **cross-checked directly against
  the depth of the corresponding array in `rtl/docastle_rom.sv`**
  (`main_rom[0:65535]`, `sub_rom[0:16383]`, `sprite_cpu_rom[0:511]`,
  `char_rom[0:16383]`, `sprite_gfx_rom[0:131071]`, `adpcm_rom[0:65535]`,
  `color_prom[0:511]`), not just the JSON slot sizes, and both sources agree
  exactly in every case.

### SDRAM offset macros (`SUB_START`, `ADPCM_START`, `JTFRAME_BA1_START`,
`JTFRAME_BA2_START`, `JTFRAME_PROM_START`)

The literal byte values chosen (`0x20000`, `0x30000`, `0x40000`, `0x48000`,
`0x68000`) are **placeholders with generous headroom**, not derived from any
real constraint beyond "large enough not to overlap the previous region's
real content, small enough to look sane". They deliberately mirror flstory's
own `SUB_START=0x20000` / `USER1_START=0x30000` / `JTFRAME_BA1_START=0x40000`
numbers where the analogous structural role lines up (bank0's second and
third offset-selected bus, and the bank0->bank1 boundary) -- this is a
coincidence of applying the same "round numbers, generous margin" convention
to a similarly-shaped bank0, not a claim that the exact addresses are
meaningful. **These must be re-validated once `jtframe mem`/`jtframe files`
can actually run** -- the tooling may reject, warn on, or silently
mis-layout an unchecked hand-picked address map.

## Deviations from the flstory template, and why

1. **Clock base: `clk48` instead of a bespoke system PLL.** flstory's
   `clocks:` map key is the bare `clk` base (its own custom-frequency system
   clock, selected via its `JTFRAME_PLL=jtframe_pll6144`). docastle's
   current RTL (`docastle_core.sv`) runs everything from one hand-built
   49.152 MHz PLL and derives 9.828 MHz (`ce_mclk`) and 4 MHz (`ce_cpu`) via
   `jtframe_frac_cen` ratios 819/4096 and 125/1536. Checking the arithmetic:
   both target rates are **exact** integer ratios of the *standard* jtframe
   48 MHz system clock too (`9,828,000 = 48,000,000 * 819/4000`, exactly;
   `4,000,000 = 48,000,000 / 12`, exactly) -- so this draft uses `clk48`
   instead of inventing a new bespoke system PLL, matching the majority
   convention in jtcores and losing zero precision. This is the single
   biggest structural deviation from directly copying flstory, and it is
   evidence-grounded (the ratio check above), not a guess.
2. **Audio channel `module:` names are unverified.** flstory's audio
   channels all reference modules with real jtcores packaging (`jt5232`).
   docastle's four SN76489A channels would want `module: jt89`, but **jt89
   has no `modules/jt89` directory anywhere in this jtcores clone** (checked
   directly) -- whether mem.yaml's audio-channel generator even accepts an
   unregistered module name is unknown. Written as a best-guess placeholder,
   flagged inline in `mem.yaml`, not as a confirmed working config. `jt5205`
   (ADPCM) by contrast IS a real, present jtcores module, so that channel
   entry is on firmer ground.
3. **No real audio RC/rsum values.** flstory's `audio:` section carries
   measured-or-estimated resistor values per channel/PCB variant (with
   inline comments admitting some are guesses, e.g. "r is a guess, must
   measure 051671"). No such measurement exists anywhere in the mrdo repo
   for docastle's output stage -- `rtl/docastle_audio_filter.sv` implements
   the AC-coupling/rolloff behaviour as a digital IIR approximation with no
   stated component values to carry over. `rsum: 1k` / `pre: 1.0` in the
   draft are placeholders, not evidence-backed numbers, and should not be
   trusted for actual gain-staging until real schematic values are found or
   measured.
4. **`ports:` section omitted.** flstory adds an explicit `bus_addr` port
   (feeding `jtframe_wait_on_shared.v`). docastle's real main/sub handshake
   is a single bidirectional comm latch plus a `main_wait` flip-flop
   (`docastle_core.sv` lines ~213-231), not a shared-RAM address window --
   structurally similar in spirit to what `jtframe_wait_on_shared.v` solves,
   but not proven to be the same shape. Left out of `mem.yaml` for this
   draft; flagged in `files.yaml` as a candidate dependency to revisit once
   the actual game module gets written.
5. **No `[header]`-driven per-game variant encoding worked out.**
   flstory's `mame2mra.toml [header]` section encodes PCB/variant flags
   (MCU present, bank count, coin polarity, etc.) into `JTFRAME_HEADER` bytes
   that the RTL reads at runtime. docastle already has an equivalent
   mechanism (`docastle_core.sv`'s `game_id` register, loaded from a
   synthetic `ioctl_index==1` download, decoded by `docastle_profile`), but
   translating the *existing* mechanism into jtframe's header-byte
   convention (vs. keeping the current synthetic-ROM-index approach) is not
   attempted here -- `mame2mra.toml` itself is explicitly out of scope for
   this draft per the task.
6. **`reg.yaml` machine list is flat, not clone-grouped.** flstory's
   `reg.yaml` lists parent machines only (bronx, nycaptor, onna34ro, rumba,
   flstory, victnine), because its MAME driver has a clone family (colt is a
   clone of bronx, etc.). `scripts/romsets.json` records docastle's 9 sets
   as independent top-level entries with no parent/clone relationship
   recorded, so this draft's `reg.yaml` lists all 9 flat. This should be
   double-checked against MAME's actual `docastle.cpp` driver metadata
   (parent/clone tags), not just the mrdo ROM slot table, before trusting it
   completely -- `scripts/romsets.json` records ROM layout, not MAME family
   topology.
7. **`[mist]` section kept only for structural parity.** Copied verbatim
   from flstory. mrdo's own README states this core targets MiSTer only
   (DE10-Nano/Cyclone V); MiST support was never a goal of the existing
   core. Kept visible rather than silently dropped, flagged as
   probably-removable.

## Open questions / assumptions (full list)

- ~~**Pixel-clock PLL does not exist yet.** Real pixel clock is 4.914 MHz
  (9.828 MHz / 2, per README). `modules/jtframe/target/mister/hdl/` only
  ships `pll5369`, `pll6144`, `pll6293`, `pll6671`, `pll7000` as MiSTer
  pixel-clock presets (checked directly) -- none match. `JTFRAME_PLL=
  jtframe_pll4914` in `macros.def` is a placeholder name for a preset that
  does not exist and would need to be generated with jtframe's PLL tooling
  once the toolchain is confirmed working.~~ **RESOLVED, this claim was
  wrong** -- it conflated the pixel clock with `JTFRAME_PLL`'s actual job
  (selecting the *system* clock preset). `jtframe_pll6144` already provides
  docastle's real 49.152 MHz system clock to -86.9 ppm, closer than this
  codebase's own accepted pixel-clock tolerance. Full re-derivation and
  math in the "JTFRAME_PLL resolution" section below; `macros.def` now sets
  `JTFRAME_PLL=jtframe_pll6144`. Struck through rather than deleted so the
  original (incorrect) reasoning stays visible.
- **`JTFRAME_PXLCLK=6` is a guess.** jtframe's macro only supports two
  classes, "6" or "8" (`modules/jtframe/doc/macros.md`); 4.914 MHz is well
  under both, "6" was picked as the closer class but this is not verified
  against jtframe's actual video-timing-helper requirements.
- **Mixed-orientation, single-RBF, multi-MRA rotation is unresolved.** This
  core ships 3 physical PCB rotations (vertical-CCW for
  docastle/douni/jjack, horizontal for the rest) across one RBF via
  per-game MRA. `JTFRAME_VERTICAL` is documented as a single core-wide
  compile-time macro. Whether jtframe expects/supports per-MRA rotation
  override with no RTL involvement (as mrdo's own hand-authored MRAs
  already do successfully today) is not confirmed against jtframe
  specifically -- flagged, not resolved, in `macros.def`.
- **Colour path is an asymmetric 3/3/2-bit weighted-resistor PROM, not a
  uniform-width palette.** Confirmed directly in `rtl/docastle_video.sv`:
  `r` uses PROM bits [7:5] with weights 0x23/0x4b/0x91, `g` uses bits [4:2]
  with the same weights, `b` uses bits [1:0] with weights 0x52/0xad --
  classic MAME-style RRRGGGBB resistor DAC, not a jtframe-style N-bit-per-
  channel palette RAM. `JTFRAME_COLORW` (default 4, uniform per channel)
  does not naturally fit this. flstory and castle both solve an analogous
  problem with a dedicated colour-mix module (`jtflstory_colmix.v`,
  `jtcastle_colmix.v`); docastle will very likely need a
  `jtdocastle_colmix.v` doing the exact resistor-weighted sum shown above,
  rather than routing through a generic jtframe palette macro. This belongs
  in the future `hdl/` port, not in `cfg/`, but is recorded here since it
  affects how `JTFRAME_COLORW` should (or should not) be set.
- **`jtframe_wait_on_shared.v` fit for the main/sub WAIT handshake is
  unconfirmed** (see deviation #4 above).
- **Audio channel module names (`jt89`) and gain-staging values are
  unverified placeholders** (see deviations #2 and #3 above).
- **`reg.yaml` flat machine list vs. MAME clone topology is unchecked**
  (see deviation #6 above).
- **`[header]`/`JTFRAME_HEADER` reconciliation with the existing
  `game_id`/`docastle_profile` mechanism is deferred**, not designed (see
  deviation #5 above).
- **The exact byte offsets in `SUB_START`/`ADPCM_START`/`JTFRAME_BA1_START`/
  `JTFRAME_BA2_START`/`JTFRAME_PROM_START` are unvalidated placeholders**
  with generous headroom, not verified against jtframe's actual address-map
  checker (see "SDRAM offset macros" above).
- **`JTFRAME_RATE=59.659`** comes directly from the README's stated measured
  refresh rate; this has not been cross-checked against `jtframe`'s own
  rate-tolerance requirements (`JTFRAME_SKIP_RATE_TEST` exists for cores
  needing software-programmed video counters -- docastle's CRTC is
  register-programmable per-game via the HD6845, so this may end up needing
  that macro too; not evaluated here).

## Known, explicitly out-of-scope gap: jt89 packaging

Per the task's explicit instruction: jt89 (the SN76489A PSG core) has **no**
jtcores module (`modules/jt89` does not exist, confirmed by search). This
draft treats it as core-local HDL that will live under
`cores/docastle/hdl/` (e.g. a future `jtdocastle_jt89.v`), picked up
automatically by the `docastle: get: "*.v"` wildcard in `files.yaml` rather
than a dedicated `jt89:` top-level block. Packaging jt89 as a proper
top-level jtcores submodule (mirroring how `jt5205` already is one) is
**future work, not part of this draft**.

## Remaining work not covered by this draft

1. **Game-module rewiring.** Port `docastle_main.sv` / `docastle_sub.sv` /
   `docastle_spritecpu.sv` / `docastle_video.sv` / `docastle_cf37201.sv` /
   `docastle_crtc.sv` / `docastle_adpcm.sv` / `docastle_profile.sv` into a
   `jtdocastle_game.v`-rooted module tree under `cores/docastle/hdl/`,
   matching the `jtflstory_*.v` / `jtcastle_*.v` file-naming and
   module-boundary conventions.
2. **CPU rewiring to jtframe_z80 / jtframe_z80wait.** Replace the direct
   `T80se` instantiations in the three CPU modules with jtframe's Z80
   wrapper(s), consistent with `files.yaml`'s `jtframe_z80.yaml` reference.
3. **Video signal renaming to LHBL/LVBL** (and general jtframe video-port
   convention alignment) in place of the current `hblank`/`vblank` naming.
4. **`jtdocastle_colmix.v`** implementing the resistor-weighted 3/3/2 PROM
   RGB mix (see "Open questions" above) -- likely needed before any real
   video output can be validated.
5. **`mame2mra.toml`** -- explicitly deferred per the task; needs the full
   DIP-switch-per-set treatment (9 sets, `dsw1`/`dsw2` defaults already
   recorded per-set in `scripts/romsets.json`, but not yet transcribed into
   `[dipsw]` TOML), the `[header]` byte-encoding reconciliation noted above,
   and the `[ROM] regions`/`order` table matching the bank layout drafted in
   this `mem.yaml`.
6. **`ver/` scene authoring.** Nine `ver/<setname>/` directories, each
   needing a real `reg.cab` input script (this draft's `reg.yaml` only
   declares that each one will reference `reg.cab`, it does not author any
   of the 9 files).
7. **jt89 submodule packaging** (see dedicated section above) -- optional
   but recommended before this core is considered fully "real jtframe"
   rather than "jtframe with one core-local vendor IP block".
8. **Running the actual jtframe tooling** once Docker/jtcore is confirmed
   working: `jtframe files`, `jtframe mem` (regenerate/validate `mem.yaml`
   against the real address map and bank/BRAM rules), and eventually
   `jtsim`/`jtcore` builds. Every address, offset, and module-name
   placeholder in this draft needs to survive that pass before being
   trusted.

## JTFRAME_PLL resolution -- corrects the earlier "no matching preset exists" claim

Status: **resolved**, evidence-checked. `cfg/macros.def` previously set
`JTFRAME_PLL=jtframe_pll4914`, a non-existent placeholder module, with a
comment claiming none of the shipped MiSTer PLL presets
(`pll5369`/`pll6144`/`pll6293`/`pll6671`/`pll7000`, later also found:
`pll7159`) matched docastle's ~4.914 MHz pixel clock. That claim was based
on a conflation this note corrects: **`JTFRAME_PLL` selects the preset for
the single system/game clock ("clk"/"clk48"), not a preset that must itself
emit the pixel rate.**

Re-derived from primary sources, not guessed:

- **mrdo's real PLL is single-domain.** `rtl/pll.v` / `rtl/pll/pll_0002.v`
  (mrdo repo) instantiate one `altera_pll` from a 50 MHz reference with
  `output_clock_frequency1("49.152000 MHz")` -- this is `clk_sys`, the ONE
  clock every CPU, PSG and the CRTC run from. There is no separate PLL tap
  for the pixel clock.
- **The pixel clock is derived, not PLL-native, on both the original board
  and the port.** `docastle_core.sv:125-129` (mrdo) generates `ce_pix` via a
  fixed `/10` clock-enable divider off `clk_sys` (49.152/10 = 4.9152 MHz,
  the comment there itself calls this "only 0.0244% above the nominal 4.914
  MHz raster clock" and ships it as accurate). Confirmed unchanged in the
  port: `hdl/jtdocastle_crtc.v` takes `ce_pix` as an **input** port (line
  21), it does not generate a pixel rate internally and nothing in jtframe
  needs to natively emit 4.914 MHz for this core to work.
- **`modules/jtframe/doc/clocks.md` documents exactly the needed base rate as
  an existing, previously-shipped preset**, not a gap: the JTFRAME_PLL table
  lists `jtframe_pll6144 | 18.43200 (crystal) | 49.152 (base clock) | 6.144
  (pixel clock) | JTKICKER, JTTWIN16, JTFROUND, JTSHOUSE, JTVIGIL`. Its
  "game module input clocks" table confirms `clk`=`clk48`=49.152 MHz for
  this preset (vs. 48 MHz default), `clk24`=24.576, `clk96`=98.304 -- i.e.
  this preset was built by jtframe's own authors for boards needing exactly
  docastle's 49.152 MHz rate, and is already used on real hardware by five
  other cores.
- **Preset .v files are plain, hand-readable Quartus `altera_pll`
  instantiations**, not opaque wizard-only binaries: checked
  `modules/jtframe/target/mister/hdl/pll6144/pll/pll_0002.v` directly --
  human-readable `.output_clock_frequency0("49.147727 MHz")` etc. strings.
  The outer `pll6144/pll.v` wrapper exposes `outclk_0..outclk_5`;
  `modules/jtframe/target/mister/hdl/jtframe_emu.sv:259-264` wires
  `outclk_0`->`clk48`, `outclk_1`->`clk48sh` (SDRAM-shifted twin),
  `outclk_2`->`clk24`, `outclk_4`/`outclk_5`->`clk96`/`clk96sh`. So the real,
  Quartus-computed base clock for `jtframe_pll6144` is **49.147727 MHz**
  (the "49.152" in clocks.md's table is the design target, not the
  fractional-N-rounded actual).

**Deviation math (same method docastle_core.sv's own comment uses --
`(actual-nominal)/nominal`, expressed as "above/below nominal"):**

| Quantity | Actual | Nominal (real PCB) | Deviation |
|---|---|---|---|
| System/game clock (`clk`/`clk48`, `jtframe_pll6144`) | 49.147727 MHz | 49.152 MHz | -0.008693% (-86.9 ppm) |
| Derived `ce_pix` = clk/10 | 4.9147727 MHz | 4.914 MHz | +0.015724% |
| (for comparison) original bespoke 49.152 MHz PLL's own `/10` | 4.9152 MHz | 4.914 MHz | +0.024420% (this codebase's own already-accepted bar) |

`jtframe_pll6144`'s system-clock error (86.9 ppm) is about **2.8x tighter**
than the 244 ppm precision bar `docastle_core.sv` itself already treats as
accurate enough to ship on real hardware. Carried through the same `/10`
pixel derivation, `jtframe_pll6144`'s `ce_pix` (4.9147727 MHz, +0.0157%) is
even closer to the 4.914 MHz nominal raster clock than the original
hand-tuned 49.152 MHz PLL's own derived pixel clock (+0.0244%). No new PLL
preset needs to be authored; `jtframe_pll6144` is not just "close enough,"
it is a better match to nominal than the number this project already
accepts as PCB-accurate.

**Action taken:** `cfg/macros.def` now sets `JTFRAME_PLL=jtframe_pll6144`
with the frequency/deviation math cited inline. `JTFRAME_CLK48` was checked
and left unset -- docastle needs only the single `clk` domain (everything
derives from clock enables off one clock, per the mrdo original), and
`clocks.md`'s table confirms `clk`==`clk48` already for this preset when
`JTFRAME_SDRAM96` is not defined, so a separate `clk48` port would be
redundant.

**Correction to "Deviations from the flstory template" item 1 above:** that
earlier note justified using `clk48` by checking that docastle's CPU/PSG
clock-enable ratios (`ce_mclk`=9.828 MHz, `ce_cpu`=4 MHz) are exact integer
ratios of jtframe's **default** 48.000 MHz system clock too. That check is
arithmetically correct but incomplete -- it did not account for the CRTC's
`/10` pixel-clock derivation, which is NOT ratio-tolerant the same way: at a
literal 48.000 MHz base, `ce_pix` would be 4.8 MHz, a **-2.32%** deviation
from the 4.914 MHz nominal raster clock, far outside the 0.0244% bar this
codebase already treats as its accuracy floor, and enough to visibly
mistime HSYNC on a real CRT. The default 48 MHz preset is the wrong choice
for docastle specifically because of the pixel/raster path, even though the
CPU-side ratios alone looked fine; `jtframe_pll6144`'s 49.147727 MHz base
is the correct pick once the raster-timing constraint is included, not
`clk48` in the generic/default sense that note implied.

**Still open, unaffected by this resolution:** `JTFRAME_PXLCLK=6` in
`macros.def` (see "Open questions" below) governs jtframe's own
auto-generated `pxl_cen`/`pxl2_cen` output-port helper, which this core does
NOT use -- docastle generates its own `ce_pix` internally via the `/10`
divider described above and jtdocastle_crtc.v takes `ce_pix` as an input.
Whether `JTFRAME_PXLCLK` is actually consumed by anything in this core's
build path (vs. being dead/inapplicable configuration) was not
re-investigated as part of this PLL task and remains a follow-up.

## Three-module assessment: docastle_analog / docastle_rom / docastle_profile

Follow-up desk-check task: read all three files in full, decide port-as-is
vs. superseded-by-jtframe-mechanism per module, with evidence. Same
toolchain-down caveat as everything else in this file -- nothing below was
compiled or run.

### 1. `docastle_analog.sv` -> ported as-is: `hdl/jtdocastle_analog.v`

**Decision: reusable as-is, only a port-source rename** (task's first
option). What the module actually computes: signed 8-bit X/Y two's-
complement axes, direction asserts at `|axis| >= 32`, releases at
`|axis| <= 20` (Schmitt-trigger-style hysteresis band, not a plain
deadzone). No board/protocol-specific content -- purely a generic threshold
decoder.

Evidence the format is identical to jtframe's own analog port:
- `modules/jtframe/doc/inputs.md` "Joysticks" section documents
  `joyana_l1..l4`/`joyana_r1..r4` as "2-complement bytes... right and
  bottom are positive (127 max); left and top are negative (FFh min, 80h
  max)", `[7:0]`=X, `[15:8]`=Y -- exactly `docastle_analog.sv`'s
  `axis_x`/`axis_y` split, byte for byte.
- Traced to the target level for certainty, not just doc text:
  `modules/jtframe/target/mister/hdl/jtframe_mister.sv` wires
  `.joystick_l_analog_0( joyana_l1 )` etc. directly, no transform -- i.e.
  `joyana_l1` IS `joystick_l_analog_0` (the exact MiSTer hps_io signal
  `docastle_analog` already reads today), just renamed at jtframe's port
  boundary.

Why jtframe's own analog handling does NOT replace this module: 
`jtframe_inputs.v`/`jtframe_board.v` already fold ONE left analog stick per
player into that player's digital joystick word (a generic "32-way
joystick via PWM" single-stick emulation, `ana1<-joyana_l1`,
`ana2<-joyana_l2`). docastle's Soccer profile reads BOTH left AND right
analog sticks per player and keeps their two decoded 4-way outputs
*separate* (see `Universal_DoCastle.sv` `p1_left_analog`/`p1_right_analog`/
`p2_left_analog`/`p2_right_analog` instances and the
`soccer_left_joys`/`soccer_right_joys` combination that follows) -- a
dual-independent-stick-per-player scheme jtframe's generic single-stick
path has no mode for. Board-local module stays.

Caller-wiring gap flagged in the new file's header, not yet acted on: under
mrdo today the 4 analog-decoder instances and the joystick-byte combination
logic live in `Universal_DoCastle.sv`, *outside* `docastle_core.sv`. Under
jtframe, `joyana_l1..r4` land directly at the *game module* boundary
(`jtframe_common_ports.inc`), so that instantiation + combination logic
needs to move into `jtdocastle_game.v` itself -- a structural relocation,
not a functional change, and not yet implemented.

### 2. `docastle_rom.sv` -> fully superseded, no port drafted

**Decision: entire file's function is superseded by `mem.yaml` codegen +
BRAM. No piece of it needs a new home in the jtframe port.**

Checked directly, not assumed: `docastle_rom.sv` contains exactly two
things -- (a) `ioctl_index==0`-gated address-range decode/write-routing
into 7 fixed-offset regions, and (b) 7 BRAM arrays with registered read
ports. Nothing else. In particular, **game-ID/profile decode is NOT
computed in this file** -- grepped for `game_id` inside it: zero matches.

Where game_id actually lives (confirmed in `docastle_core.sv`, not
`docastle_rom.sv`): a *separate* register fed by a *second, independent*
synthetic download, `ioctl_download && ioctl_wr && (ioctl_index==8'd1) &&
(ioctl_addr==0)` (`docastle_core.sv` lines ~67-75) -- structurally
unrelated to the `ioctl_index==0` main-ROM-image path `docastle_rom.sv`
handles. So the task's conditional ("if game_id decode is inside
docastle_rom.sv itself, that piece needs to migrate") does not apply here:
it was never in this file to begin with. game_id capture belongs to
`docastle_core.sv`'s future `jtdocastle_game.v` port, and its *consumer*
(`docastle_profile.sv`) is handled in section 3 below; `docastle_rom.sv`
itself contributes nothing further.

Cross-checked against the already-drafted `cfg/mem.yaml`: all 7 regions
(`main`, `sub`, `adpcm`, `gfx1`, `gfx2`, `spritecpu`, `cprom`) are already
present there with `addr_width` values matching `docastle_rom.sv`'s array
depths exactly (see the ROM-bank mapping table earlier in this file). No
gap.

### 3. `docastle_profile.sv` -> ported as-is: `hdl/jtdocastle_profile.v`

**Decision: port the case-decode logic unchanged (per task instruction),
input-port source explicitly left unresolved** -- do not trust the `game_id`
port wiring in the new file without further work.

What was investigated: two distinct, non-interchangeable jtframe
mechanisms could plausibly carry a per-game-variant byte, and picking the
wrong one silently misroutes it:

1. **`core_mod`/MOD byte** (`modules/jtframe/doc/core_mod.md`, read in
   full for this task). Loaded via the *same* MRA `<rom index="1">`
   convention mrdo's own game_id byte already uses -- superficially
   tempting. **Rejected**: its 7-8 bits are fixed, jtframe-owned meanings
   (vertical screen, 4-way joystick, CCW rotation, dial filter/reverse,
   blanking expansion, volume) consumed by jtframe's own internal logic,
   not a free-form value the game module interprets. docastle's 9-value
   game_id has no matching MOD-byte bit; forcing it in would mean
   inventing meaning for undefined bits -- exactly the guess the task says
   not to make.
2. **`JTFRAME_HEADER`/`mame2mra.toml [header]`** (`doc/jtframe-mra.md`,
   `doc/macros.md`). Explicitly documented as bits "handled directly by
   the core's game module" (core_mod.md's own contrast against the MOD
   byte) -- the better structural match for what `docastle_profile.sv`
   does. Mechanically different from today's mechanism though: a
   `JTFRAME_HEADER`-byte header *prepended to the main ROM file itself*
   at MRA-build time, consumed via `prog_addr`/`prog_we`/`header` during
   the *same* download as the ROM image -- not mrdo's current second,
   independent `ioctl_index==1` download. jtframe also offers automatic
   per-bit header-module generation (`registers=[]` in `[header]`), which
   could plausibly replace this hand-written module's case-decode
   entirely rather than just feed it -- an open design choice, not just an
   open wiring detail.

   Both of these were out of reach for this task specifically because
   `mame2mra.toml` is explicitly out of scope (already flagged as deferred
   in deviation #5 above) -- so the *destination* end of this wiring can't
   be built yet either. `game_id` was therefore kept as the port name in
   `jtdocastle_profile.v` (not renamed to `core_mod` or `header`) so the
   TODO stays visible rather than silently implying a resolved connection.

New evidence for the still-open JTFRAME_VERTICAL/rotation question (see
"Open questions" above) -- **not a resolution, just recorded for whoever
picks that question up next**: `core_mod.md`'s MOD-byte bit 0 is described
as "vertical screen... the same RBF can switch between horizontal and
vertical games by using the MOD byte", and bit 2 "CCW rotation" is "set by
`jtframe mra`" (i.e. computed automatically per set, not hand-authored).
This is evidence jtframe may already have a working per-MRA
rotation-override mechanism for exactly this core's mixed-rotation,
multi-MRA-per-core situation (docastle/douni/jjack ROT270, the rest ROT0)
-- but it was not verified end-to-end (does `jtframe mra` derive CCW
correctly per set from MAME driver metadata for this driver; does one RBF
really tolerate JTFRAME_VERTICAL toggling per MRA at runtime the way this
core needs), so the open question in this file stays open, now with a
concrete mechanism name to go check first.

## Two integration-gap fixes (2026-08-18)

Follow-up task: the integration agent's final report on the `jtdocastle_game.v`
pass (see that file's own flagged items C1 and I3) named two real gaps left
by relocating mrdo's RTL onto jtframe's port boundary. Both are fixed now.
Same toolchain-down caveat as everything else in this file -- neither fix was
compiled or simulated; both are desk-checked against the arithmetic/precedent
evidence below.

### Fix 1: ADPCM / audio-filter clock dividers were still 49.152 MHz-based

**Problem.** `hdl/jtdocastle_adpcm.v` and `hdl/jtdocastle_audio_filter.v` were
pure relocations of `mrdo/rtl/docastle_adpcm.sv` and
`mrdo/rtl/docastle_audio_filter.sv`, including those files' own hand-rolled
clock-enable dividers: a `/128` counter for the 384 kHz MSM5205 input clock,
and a `/1024` counter (`&div`) for the 48 kHz IIR update rate. Both divisors
are only correct against the *original PCB's* 49.152 MHz PLL
(49,152,000/128 = 384,000 exactly; 49,152,000/1024 = 48,000 exactly). Once
relocated under jtframe's `clk48` base -- 48.000 MHz, per `cfg/mem.yaml`'s
existing `cen_mclk`/`cen_cpu` entries, aliased to plain `clk` inside the game
module (`mem/clocks.go` rewrites base `clk48` to `clk` when
`JTFRAME_SDRAM96` is not set) -- those same divisors land at 48,000,000/128 =
375,000 Hz and 48,000,000/1024 = 46,875 Hz: both **-2.4%** off, and the
audio-filter error also detunes the module's two Q16 IIR pole coefficients
(the 1.5 Hz HP/AC-coupling pole and the ~12 kHz LP speaker-rolloff pole),
since those coefficients were computed assuming a 48 kHz update rate.

**Fix.** 48,000,000/125 = 384,000 Hz and 48,000,000/1000 = 48,000 Hz are both
*exact* integer divisions of the real 48 MHz base -- no precision lost, same
"exact ratio of 48 MHz" argument deviation #1 already used to justify moving
`ce_mclk`/`ce_cpu` onto `clk48` in the first place. Two new `cfg/mem.yaml`
`clocks: clk48:` outputs were added, `cen_384k` (freq 384000) and `cen_48k`
(freq 48000), using the exact same generator mechanism as the existing
`cen_mclk`/`cen_cpu` entries (`jtframe_gated_cen`, landing as plain module
INPUTS once mem.yaml is regenerated by real tooling):

- `hdl/jtdocastle_adpcm.v`: removed the internal `cen_div`/`ce_384k` counter
  entirely; added an input port `cen_384k`; the jt5205 `.cen()` port is now
  driven by `cen_384k && !pause` (preserving the original divider's
  pause-gating behaviour, now applied to the incoming cen instead of gating
  the counter itself).
- `hdl/jtdocastle_audio_filter.v`: removed the internal `div`/`ce_audio=&div`
  counter entirely; added an input port `cen_48k`; `ce_audio` is now `cen_48k`
  directly.
- `hdl/jtdocastle_game.v`: `cen_384k`/`cen_48k` added to the module's derived
  port-list comment (same category/place as `cen_mclk`/`cen_cpu`, same
  "UNVERIFIED, matches established convention" caveat -- no codegen was run
  to confirm the exact generated port names/widths) and wired down into the
  `u_adpcm`/`u_audio_filter` instances' new `cen_384k`/`cen_48k` ports.
  Flagged item C1 updated to record the fix instead of the gap.

All three touched files' header comments were updated in place with a dated
FIX note pointing back here.

### Fix 2: Soccer profile's right-stick digital fallback

**Problem.** mrdo's `Universal_DoCastle.sv` built `soccer_right_joys` by
OR-ing the analog right-stick decode with digital bits `joystick_0[15:12]` /
`joystick_1[15:12]` -- the SPARE HIGH BITS of that player's own single
16-bit MiSTer joystick word, a fallback so a plain digital pad still drives
the Soccer profile's second stick even with no analog input connected. That
OR was dropped in the `jtdocastle_game.v` integration pass: jtframe's
`joystick1`/`joystick2` are only `` `JTFRAME_BUTTONS+3:0 `` wide
(`jtframe_common_ports.inc`) -- 6 bits with `JTFRAME_BUTTONS=2`
(`cfg/macros.def`) -- with no spare high bits, so mrdo's exact mechanism has
no home under jtframe, and the right stick was left analog-only (flagged
item I3 in `jtdocastle_game.v`'s header).

**Investigation.** jtframe provides four joystick ports unconditionally
(`joystick1..joystick4`) plus four independent left/right analog-stick pairs
per player (`joyana_l1..l4`/`joyana_r1..r4`, already confirmed identical in
format to mrdo's `joystick_l_analog_*`/`joystick_r_analog_*` and already
correctly wired to four `jtdocastle_analog` instances in `jtdocastle_game.v`
-- only the *digital* fallback path was missing). `modules/jtframe/doc/
inputs.md` documents the four joysticks and the four analog-stick pairs but
does **not** document any dedicated "second digital stick per player"
mechanism. Two real jtcores precedents were checked
(`grep -rl "joystick3\|joystick4" cores/*/hdl/*.v`):

- `cores/kchamp` (Karate Champ) is the one other jtcores game with two
  joysticks per player on a single cabinet (movement stick + attack stick).
  Its non-link-mode convention packs the second stick into the SAME
  player's own `joystick1`/`joystick2` word, by declaring a wider
  `JTFRAME_BUTTONS` (4, vs. docastle's 2) so the stick's 4 direction bits
  land in what would otherwise be spare button-position bits
  (`jtkchamp_main.v`: `ctrl_1p = { joystick1[7:4], joystick1[2],
  joystick1[3], joystick1[1:0] }`). kchamp only reaches for
  `joystick3`/`joystick4` in its separate `link_joys` mode, which is a
  *different physical cabinet* linked over a cable for a 2-cabinet VS game
  -- not a same-cabinet second stick.
- Every other jtcores core wiring `joystick3`/`joystick4`
  (`aliens`, `cps1`, `riders`, `shouse`, `simson`, `track`, `twin16`, ...)
  treats them as genuine PLAYER 3 / PLAYER 4 inputs on a real multi-player
  cabinet.

Neither precedent is an exact match for "one 2-player cabinet, each player
has two sticks, no link mode". Following kchamp's literal precedent (raise
`JTFRAME_BUTTONS`) would reshuffle the `joystick1`/`joystick2` bit layout
core-wide, affecting all nine docastle-family profiles sharing this one
RBF/game module, not just the two Soccer sets -- a much larger blast radius
than the fallback path being restored actually warrants (the right stick
already has an analog primary; only the digital fallback was missing).

**Fix chosen (best-supported, explicitly flagged as unverified).**
`joystick3`/`joystick4` -- otherwise completely idle in this core (docastle
is 2-player only; they were already sitting in the file's own `_unused` bus)
-- are now OR'd into `soccer_right_joys` as P1's and P2's right-stick digital
fallback, using the same `JTFRAME_JOY_RLDU` bit order (`[0]`=right,
`[1]`=left, `[2]`=down, `[3]`=up) already used for `joystick1`/`joystick2`'s
primary stick:

```
wire p1_r_right=~joystick3[0], p1_r_left=~joystick3[1],
     p1_r_down =~joystick3[2], p1_r_up  =~joystick3[3];
wire p2_r_right=~joystick4[0], p2_r_left=~joystick4[1],
     p2_r_down =~joystick4[2], p2_r_up  =~joystick4[3];

wire [7:0] soccer_right_joys = ~{
    p2_r_down|p2_ra_down, p2_r_left|p2_ra_left, p2_r_up|p2_ra_up, p2_r_right|p2_ra_right,
    p1_r_down|p1_ra_down, p1_r_left|p1_ra_left, p1_r_up|p1_ra_up, p1_r_right|p1_ra_right };
```

This is zero-macro-change (does not touch `JTFRAME_BUTTONS` or any other
profile's input layout), additive-only, and mirrors `soccer_left_joys`'
existing OR-with-digital-fallback pattern exactly. It is **not** a confirmed
jtframe convention -- explicitly flagged as such in `jtdocastle_game.v`'s
header (updated flagged item I3) and inline at the `p1_r_*`/`p2_r_*` wire
declarations -- and it still needs `mame2mra.toml`/cfgstr work (same
already-deferred caveat as flagged item G1) to actually route a real second
physical controller onto `joystick3`/`joystick4` for a 2-player cabinet in
an MRA. Revisit if real jtframe/mame2mra.toml guidance turns up a documented
"second digital stick per player" mechanism that supersedes this choice.

## `cfg/mame2mra.toml` authoring pass (2026-08-18)

Status: **desk-check draft only, same as every other file in `cfg/`.** Never
run through `jtframe mra`, Docker, or any jtcore CLI step -- not invoked in
this task per instruction. Written from `modules/jtframe/doc/jtframe-mra.md`
(the TOML spec, read in full), `cores/flstory/cfg/mame2mra.toml` (closest
structural precedent: 6-machine family, hand-decoded `[header]` game-ID
table) and `cores/castle/cfg/mame2mra.toml` (closest SDRAM-bank-count
precedent, and the source of the "every non-first ROM region needs its own
`start=` macro" rule used below). Ground truth for game content:
`D:\Arcade\AI\aCORES\mrdo\scripts\generate_mras.ps1`, `romsets.json`,
`rtl\docastle_profile.sv`, and the existing `releases\*.mra` files, all in
the mrdo repo. This closes out "Remaining work" item 5 from the top of this
file -- `mame2mra.toml` now exists -- but does **not** claim the underlying
`[header]`/`game_id` wiring is verified end-to-end; see the honest
assessment below.

### The blocking discovery: `doc/mame.xml` has zero docastle.cpp entries

Checked directly before writing anything: `grep -c docastle
D:\Arcade\AI\aCORES\JT\real\doc\mame.xml` returns `0`. Per
`modules/jtframe/doc/jtframe-mra.md`'s own description ("Each repository is
meant to have a reduced mame.xml file... as part of the source file
committed in git"), this file only carries entries for cores already added
to this jtcores clone -- docastle isn't one yet, so there is **no real MAME
driver metadata available in this session at all**: not DIP switch names or
bit layouts, not the true clone/parent family tree, not the full list of
sets MAME's docastle.cpp actually defines. This shaped nearly every
decision below; each one is flagged against it individually rather than
silently assumed away.

### `[parse]`: 9 independent entries, no `parents=` guess made

Per the task's explicit instruction, no parent/clone relationship was
guessed. `scripts/romsets.json`'s own `"parent"` field (`docastle`->
`docastle`, `douni`->`docastle`, `spiero`->`dorunrun`, `asoccer`->
`idsoccer`, etc.) is `generate_mras.ps1`'s **display/folder grouping** for
the `<parent>` MRA tag only -- there is no evidence it reflects a real MAME
`cloneof` relationship, and copying it into `[parse].parents` would have
been exactly the kind of guess the task says not to make. All 9 sets are
left as independent `sourcefile=["docastle.cpp"]` entries; `jtframe mra`
will derive any real clone grouping automatically once `doc/mame.xml`
actually has docastle.cpp data (a `parents=[]` override is only needed when
a parent set lives *outside* the selected sourcefile, which cannot apply
here).

Also flagged, not resolved: the real MAME docastle.cpp driver almost
certainly defines more sets than these 9 curated ones (known history of
clone/bootleg variants for both the Castle and Run Run families). Once
`doc/mame.xml` is regenerated for this sourcefile, every matching machine
gets an MRA unless excluded via `skip.Setnames`, and this draft cannot
populate that list correctly without seeing the real set list. A bare
`skip.Bootlegs=true` was added as a low-risk default; the rest is an open
follow-up, stated as such in the TOML's own `[parse]` comment.

### `[dipsw]`: full `extra=[]` transcription, not `rename=`/`offset=`

`modules/jtframe/doc/jtframe-mra.md`'s `[dipsw]` mechanisms (`rename`,
`offset`, `defaults`, `extra`) are designed to **adjust** a DIP table
`jtframe mra` already parsed from MAME source via `mame.xml` -- not to
author one from nothing. Since `doc/mame.xml` has no docastle.cpp entries
(see above), there is currently nothing for `rename=`/`offset=` to adjust,
so the chosen design is `[dipsw].extra=[]`: every line from
`generate_mras.ps1`'s `Get-DipLines`/`Get-CommonCoinDips`/
`Get-SoccerCoinDips` functions transcribed mechanically (MRA's `bits=`/
`ids=` attribute pair maps directly onto TOML's `extra[].bits`/
`extra[].options`), one `extra` entry per machine per dip line: 9 machines'
worth of game-specific dip lines (7 or 8 per machine, varying with
`Get-DipLines`' per-set branch -- docastle/douni/jjack/idsoccer/asoccer have
7, dorunrun/spiero/dowild/kickridr have 8, each always ending in the 4-bit
Coin B / Coin A pair) plus one shared 2-bit Difficulty entry per machine =
76 total `extra` entries, confirmed by parsing the finished TOML with
Python's `tomllib` (`len(data['dipsw']['extra']) == 76`). `[dipsw].defaults=[]`
pins each set's exact
`dsw1,dsw2` default byte pair straight from `romsets.json` (`df,ff` for the
7 non-Soccer sets, `ff,ff` for `idsoccer`/`asoccer`).

**This is explicitly flagged as a temporary choice in the TOML's own
comment block, not a final answer.** Once `doc/mame.xml` is regenerated
with real docastle.cpp data, `jtframe mra` will *also* auto-derive DIP
switches from MAME's own `PORT_DIPNAME`/`PORT_DIPSETTING` definitions for
these machines. If (as is likely, since DIP bit positions are fixed by real
hardware and `generate_mras.ps1` was almost certainly itself transcribed
from MAME source) those bit positions match what's encoded here, the
`extra=[]` entries will **duplicate** the auto-derived table in the
generated MRA -- a real correctness bug that must be caught and fixed by
converting this section to `rename=`/`defaults=` only, once the tooling can
actually run and show what MAME's own parse produces. This tradeoff (full,
self-contained, verifiably-faithful-to-`generate_mras.ps1` fidelity *today*,
at the cost of a known required reconciliation step *later*) was chosen
deliberately over leaving the DIP table effectively empty (`rename=`/
`defaults=` alone, with nothing yet to rename/default) until that
regeneration happens.

### `[header]`: the actual fix for the game-ID hazard, with byte table

This is the section the task centred on, so the full byte-value table and
its cross-check are given here.

**The hazard, restated precisely.** `hdl/jtdocastle_profile.v` (ported
unchanged from `rtl/docastle_profile.sv`, confirmed by direct diff of the
`case (game_id)` block -- identical) decodes `game_id=8'h00` as a **valid**
profile (Mr. Do's Castle, `native_vertical=1`). `hdl/jtdocastle_game.v`
(lines 286-301) captures byte 0 of the `JTFRAME_HEADER=8` ROM header into
`game_id`/`game_id_ok` via `header && prog_we && prog_addr[2:0]==3'd0`, with
`game_id` reset to `8'h00` and `game_id_ok` to `0` beforehand. Before this
TOML pass, nothing in `cfg/` ever wrote real per-set values into that
header region -- so every generated MRA would have shipped a header whose
byte 0 either came from jtframe's own unconfigured default (undocumented in
this draft's available references) or, worst case, `0x00`, which decodes as
a **perfectly valid** Mr. Do's Castle profile rather than failing loudly.
That is the exact "missing/wrong header boots the WRONG GAME silently"
hazard flagged in both `jtdocastle_profile.v`'s header comment (item G1) and
this file's deviation #5 / "Remaining work" item 5.

**The fix has two parts, both now in `cfg/mame2mra.toml`'s `[header]`
section:**

1. **`data=[]` writes the correct byte 0 for every one of the 9 sets.**
2. **`fill=0xff`, not the more common `fill=0` (flstory uses `fill=0`).**
   This is the load-bearing half of the fix, not just documentation: `0x00`
   is a *valid* `game_id` in the decoder (Mr. Do's Castle), so filling any
   unassigned header byte/machine with `0x00` would silently reproduce
   the exact hazard this section exists to close. `0xff` falls into the
   decoder's `default:` arm, which clears `valid` and (via
   `base_reset = rst | ~profile_valid | ~game_id_ok` in
   `jtdocastle_game.v`, confirmed unchanged from `docastle_core.sv`'s own
   `base_reset` term) holds the **entire core in reset** rather than
   booting any game at all. This also covers the `[parse]` gap noted above:
   if `doc/mame.xml` regeneration surfaces extra docastle.cpp machines
   beyond these 9 that slip through without an explicit `data` entry, they
   get `0xff` (held in reset) instead of `0x00` (silently Mr. Do's Castle).

**The byte-value table, cross-checked directly against
`hdl/jtdocastle_profile.v`'s `case (game_id)` statement, which is itself
confirmed identical to the original `rtl/docastle_profile.sv`:**

| Set | Header byte 0 | `jtdocastle_profile.v` case arm | Flags set |
|---|---|---|---|
| `docastle` (Mr. Do's Castle) | `0x00` | `8'h00` | `native_vertical` |
| `douni` (Mr. Do! vs. Unicorns) | `0x01` | `8'h01` | `native_vertical` |
| `dorunrun` (Do! Run Run) | `0x02` | `8'h02` | `PROFILE_RUNRUN`, `low_pen_priority` |
| `dowild` (Mr. Do's Wild Ride) | `0x03` | `8'h03` | `PROFILE_RUNRUN`, `low_pen_priority` |
| `jjack` (Jumping Jack) | `0x04` | `8'h04` | `PROFILE_RUNRUN`, `low_pen_priority`, `native_vertical` |
| `kickridr` (Kick Rider) | `0x05` | `8'h05` | `PROFILE_RUNRUN`, `low_pen_priority` |
| `spiero` (Super Pierrot) | `0x06` | `8'h06` | `PROFILE_RUNRUN`, `low_pen_priority` |
| `idsoccer` (Indoor Soccer) | `0x07` | `8'h07` | `PROFILE_SOCCER`, `low_pen_priority`, `soccer_sprites`, `has_adpcm`, `has_joys2` |
| `asoccer` (American Soccer) | `0x08` | `8'h08` | `PROFILE_SOCCER`, `low_pen_priority`, `soccer_sprites`, `has_adpcm`, `has_joys2` |
| *(unused)* | -- | `8'h09` | `PROFILE_RUNRUN`, `low_pen_priority` (spare "Do! Run Run set 2" slot; no romsets.json set claims it) |
| any other value, incl. the `fill=0xff` default | -- | `default:` | `valid=0` -> core held in reset |

Every row 0x00-0x08 matches `romsets.json`'s own per-set `"id"` field
exactly (`docastle`=0 ... `asoccer`=8) -- the byte table above is not a new
assignment, it is the same numbering `docastle_core.sv`'s original synthetic
`ioctl_index==1` download already used, now re-expressed as the byte 0 of a
`JTFRAME_HEADER` header instead of a second independent download. This is
the intended behavioural-equivalence point: same 9 values, same decode
logic, different delivery mechanism.

**Honesty about what this does and does NOT resolve:**

- **Resolves:** the specific hazard named in the task -- "jtframe's generic
  auto-header default... dangerously defaulting to profile 0 / Mr. Do's
  Castle on a missing/zero header." With `fill=0xff` and all 9 sets given
  explicit `data` bytes, no code path in this design produces a *silent*
  wrong-game boot; the only failure mode left is a *loud* one (core held in
  reset).
- **Does NOT resolve:** whether the `header`/`prog_addr`/`prog_we` signal
  names and byte-boundary timing `jtdocastle_game.v` assumes (`header &&
  prog_we && prog_addr[2:0]==3'd0` for byte 0) are actually what real
  `jtframe files`/`jtframe mem` codegen produces at the game-module
  boundary for `JTFRAME_HEADER=8` -- this was investigated by
  `jtdocastle_profile.v`'s own header comment against
  `modules/jtframe/doc/jtframe-mra.md`'s worked example
  (`if(prog_addr==0 && prog_we && header) mycfg <= prog_data;`) and against
  flstory's own `[header].data` convention, both consistent with what's
  written here, but **neither was confirmed by actually running the
  toolchain**. This TOML supplies the correct *content*; whether it lands
  on the wire the way `jtdocastle_game.v` expects is unverified until
  `jtframe mra` + `jtframe mem`/`jtframe files` can actually run together.
- **Does NOT resolve:** whether jtframe's automatic per-bit header-module
  generation (`[header].registers=[]`, mentioned in the TOML spec and in
  `jtdocastle_profile.v`'s own header comment as "the mechanism that best
  matches... could auto-generate something like this module's flag outputs
  directly from `mame2mra.toml` without hand Verilog at all") should
  *replace* `jtdocastle_profile.v`'s hand-written case-decode entirely,
  rather than just feed it a byte as done here. The hand-decode-plus-single-
  byte approach was chosen because it is a direct, checkable, zero-guesswork
  port of the original `docastle_profile.sv` logic (task instruction: port
  the case-decode unchanged); switching to `registers=[]` would mean
  re-deriving each of the 5 per-game flags from scratch inside TOML syntax,
  a larger, independently-riskier redesign not attempted here.

Net: the game-ID hazard's **silent-wrong-game** failure mode is closed by
this pass (assuming the header timing assumption above holds); the
**correct-wiring-confirmed-by-running-the-tool** question is still open,
exactly as `jtdocastle_profile.v`'s own header already said it would be
until `mame2mra.toml` existed. It now exists; the next required step is
running it.

### `[buttons]`: `JTFRAME_BUTTONS=2` forces 2 names per machine

`generate_mras.ps1`'s old MRA-authoring convention only ever advertised ONE
"real" action button (`<num_buttons>1</num_buttons>`) for the 7 non-Soccer
games, hiding the second slot with a dash in its 13-name fixed-ABI
`<buttons names=...>` list -- but that is an MRA-tag-only display choice
from the old generator, not evidence that the second RTL button line is
actually absent: `cfg/macros.def` fixes `JTFRAME_BUTTONS=2` core-wide,
because `Universal_DoCastle.sv`/`docastle_main.sv` wire exactly two action-
button lines (`p1_b1`/`p1_b2` -> `joystick_0[4:5]`) for every one of the 9
games regardless of whether that game's own software reads the second one.
Since jtframe wants exactly `JTFRAME_BUTTONS` names per machine, the 7
non-Soccer sets were given a generic `"Button 2"` second name (hardware-
present, not confirmed software-used) instead of silently dropping to 1
name. This is flagged in the TOML's own comment as a best-effort
placeholder -- whether jtframe has its own convention for a wired-but-
game-unused button (a dash-hide convention, a "Button N" generic fallback,
or something else) was not confirmed against a real generated MRA.

### `[ROM]`: 7 regions matching `mem.yaml`, one macros.def gap fixed

Region set/order/start-macro assignment matches `cfg/mem.yaml`'s bank
grouping directly (`main`/`sub`/`adpcm` on ba0 via offset, `gfx1` on ba1,
`gfx2` on ba2, `spritecpu`/`proms` in the two BRAM blocks). One real gap was
found and fixed while writing this: `cfg/macros.def` had only **one** BRAM-
area start macro (`JTFRAME_PROM_START`) for **two** independent BRAM
regions (`spritecpu`, `proms`/`cprom`). Checked directly against both
`cores/flstory/cfg/mame2mra.toml` and, more precisely,
`cores/castle/cfg/mame2mra.toml` (whose last two regions, `k007121_2` and
`proms`, get their own distinct `JTFRAME_BA3_START`/`JTFRAME_PROM_START`
macros, not a shared one) -- every non-first `[ROM].regions` entry needs its
own explicit `start=` macro, no implicit "falls through to the next region"
behaviour is evidenced anywhere in either real example. `macros.def` now
defines `JTFRAME_PROM2_START=0x68200` (immediately after `spritecpu`'s
fixed 512-byte/`0x200` footprint, which is identical on all 9 sets) for the
`proms` region. Same caveat as every other address in this draft's SDRAM/
BRAM map: unvalidated placeholder headroom, not checked against real
`jtframe mem`/`jtframe files` output.

The `adpcm` region entry carries no `machines=[...]` restriction in the
TOML, relying on the parser to simply skip a region that doesn't exist for
a given machine's MAME ROM list (true for the 7 non-Soccer sets, which have
no `adpcm` `ROM_REGION` at all) -- this behaviour is inferred from how the
tool is described to work generally, not confirmed against a worked example
with an absent-for-some-machines region in either flstory or castle's real
TOML (both of flstory's own machine-restricted regions, `sub`/`user1`, use
explicit `machines=[...]`, not implicit absence). Flagged as unverified.

### Net effect on the game-ID hazard

Before this pass: `[header]` did not exist, `JTFRAME_HEADER=8` had nothing
writing real content into it, and `jtdocastle_profile.v`'s own header
called this an open, "do not trust... without further work" gap. After this
pass: every one of the 9 curated sets gets an explicit, cross-checked byte 0
matching the original `docastle_profile.sv` numbering exactly, and every
other case (unassigned bytes, any future non-curated MAME set that slips
through `[parse]`'s incomplete `skip.Setnames`) resolves to a loud reset
rather than a silent wrong-game boot. What remains unverified is
implementation-wiring, not intent: whether `jtframe mem`/`jtframe files`
actually produces the `header`/`prog_addr`/`prog_we` signals
`jtdocastle_game.v` already assumes, at the byte-offset timing assumed
here. That can only be confirmed by running the real toolchain, which
remains unavailable in every session that has touched this core so far.
