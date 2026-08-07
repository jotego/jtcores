# Taito X System — Family Bring-Up Plan

Generated from `cores/superman/doc/taito_x.cpp` (MAME 0.282 era).  Read this
before starting any work on the sibling games — it is the source of truth
for what is shared vs per-game between Superman and the five cousins.

---

## 1. Game inventory (taito_x.cpp `GAME(...)` lines 1421–1430)

| MAME setname | Year | Title | Dev | Driver class | machine config | Rotation |
|---|---|---|---|---|---|---|
| `superman`  | 1988 | Superman (World) | Taito | `taitox_cchip_state` | `superman` | ROT0 |
| `supermanu` | 1988 | Superman (US)    | Taito | `taitox_cchip_state` | `superman` | ROT0 |
| `supermanj` | 1988 | Superman (Japan) | Taito | `taitox_cchip_state` | `superman` | ROT0 |
| `twinhawk`  | 1989 | Twin Hawk (World)| Taito | `taitox_state`       | `daisenpu` | ROT270 |
| `twinhawku` | 1989 | Twin Hawk (US)   | Taito | `taitox_state`       | `daisenpu` | ROT270 |
| `daisenpu`  | 1989 | Daisenpu (Japan) | Taito | `taitox_state`       | `daisenpu` | ROT270 |
| `gigandes`  | 1989 | Gigandes         | East Tech | `taitox_state`   | `gigandes` | ROT0 |
| `gigandesa` | 1989 | Gigandes (earlier)| East Tech | `taitox_state`  | `gigandes` | ROT0 |
| `kyustrkr`  | 1989 | Last Striker / Kyuukyoku no Striker | East Tech | `taitox_state` | `kyustrkr` | ROT180 |
| `ballbros`  | 1992 | Balloon Brothers | East Tech | `taitox_state`   | `ballbros` | ROT0 |

Three of these (`supermanu`/`supermanj` already work, `twinhawk`/`twinhawku` are
just region variants of `daisenpu`) collapse into seven core cases.

---

## 2. Hardware deltas Superman → cousins

What needs implementing/changing per game (MAME source = lines noted).

### 2.1 Sound chip routing (TC0140SYT vs PC060HA)

| Game | Comm chip | YM chip | Z80 sound_map | Notes |
|---|---|---|---|---|
| superman, gigandes, ballbros, kyustrkr | **TC0140SYT** | **YM2610** (FM+ADPCM-A) | `sound_map` (lines 699-713) | Already implemented in `jtsuperman_syt.v`. |
| daisenpu / twinhawk | **PC060HA** | **YM2151** (FM only) | `daisenpu_sound_map` (line 715+) | PC060HA is the cousin chip; rastan core has `jtrastan_pc060.v` we can reuse. YM2151 is a completely different chip family from YM2610. |

Z80 ROM size also differs: Superman / Gigandes / Ballbros / Kyustrkr each
have a 64 KB audio ROM; Daisenpu has 32 KB.

### 2.2 Input handling

| Game | Path | 68k bus map | Notes |
|---|---|---|---|
| superman | **Taito C-chip** at `$900000-$900FFF` | `superman_map` line 629 | Already implemented; MCU (uPD78C11+EPROM) processes inputs, writes shared RAM. |
| gigandes, ballbros, daisenpu | Direct `input_r`/`daisenpu_input_w` at `$900000-$90000F` | `gigandes_map` / `ballbros_map` / `daisenpu_map` | No C-chip. 68k reads IN0/IN1/IN2 directly; writes go to coin-counter / coin-lockout via `daisenpu_input_w` (lines 574-590). |
| kyustrkr | Direct `input_r`/**`kyustrkr_input_w`** | `kyustrkr_map` line 683 | Same as daisenpu but its `_input_w` has **inverted coin-lockout polarity** (line 605: `data & 0x04` instead of `~data & 0x04`). |

For the non-C-chip games we need to add a small input_r/input_w block in
`jtsuperman_main.v` that's currently absent (it was stripped during the
"dead-code" pass `f2504bf7e` because Superman never reads inputs directly).

### 2.3 Button counts and joystick macros

| Game | Buttons macro | `JTFRAME_BUTTONS` | Notes |
|---|---|---|---|
| superman | `TAITO_JOY_UDLR_2_BUTTONS_START` | 2 (Punch + Kick) | Already done. |
| daisenpu / twinhawk | `TAITO_JOY_UDLR_2_BUTTONS_START` | 2 (Shot + Bomb) | Same bit layout as Superman. |
| gigandes | `TAITO_JOY_UDLR_2_BUTTONS_START` | 2 (Shot + Bomb) | Same. |
| kyustrkr | **`TAITO_JOY_UDLR_3_BUTTONS_START`** | 3 (Short Pass + Long Pass + Shoot) | BUTTON3 at bit 6 (the slot we currently tie high for Superman) becomes a real button. |
| ballbros | **`TAITO_JOY_UDLR_1_BUTTON_START`** | 1 (Action) | BUTTON2 + BUTTON3 unused (tied high). |

Note: all of these use the schematic-verified bit layout
`bit 0..3 = UDLR, 4..6 = B1/B2/B3, 7 = START` — so the change for kyustrkr
and ballbros is just `JTFRAME_BUTTONS` + which slot is tied high.

Joystick reorder is **`JTFRAME_JOY_RLDU`** for everyone (MiSTer HPS_IO
convention, same as Superman).

### 2.4 X1-001A sprite Y offsets (machine_config)

```cpp
// Superman:  fg_yoffsets(-0x12, 0x0e)  bg_yoffsets( 0x1, -0x1)
// Daisenpu:  fg_yoffsets(-0x12, 0x0e)  bg_yoffsets( 0x1, -0x1)
// Gigandes:  fg_yoffsets(-0x0a, 0x0e)  bg_yoffsets( 0x1, -0x1)
// Ballbros:  fg_yoffsets(-0x0a, 0x0e)  bg_yoffsets( 0x1, -0x1)
// Kyustrkr:  (same as ballbros via ballbros(config))
```

FG Y offset differs (`-0x12` for Superman/Daisenpu, `-0x0a` for the rest).
That's a one-line constant change per game in our `jtsuperman_game.v`'s
FG y_data formula (currently hardcoded `K=248`).

BG Y offsets identical across the family.

### 2.5 Video timings

| Game | refresh | visarea | size |
|---|---|---|---|
| superman | 57.43 Hz | `0..48*8-1, 1*8..31*8-1` (384×240) | 52*8 × 32*8 |
| daisenpu | 60 Hz | `0..48*8-1, 2*8..30*8-1` (384×224) | 52*8 × 32*8 |
| gigandes | 60 Hz | `0..48*8-1, 1*8..31*8-1` (384×240) | 52*8 × 32*8 |
| ballbros | 60 Hz | `0..48*8-1, 1*8..31*8-1` (384×240) | 52*8 × 32*8 |
| kyustrkr | 60 Hz | (inherits ballbros) | 52*8 × 32*8 |

All match our PXLCLK=8 + 512×272 vtimer except for the 224-vs-240 visible
height on Daisenpu (vertical game in landscape res — needs a different
visible window).

### 2.6 IRQ source

| Game | 68k IRQ | Notes |
|---|---|---|
| superman | Custom `interrupt()` callback (C-chip drives an IRQ-clear timer) | Already handled. |
| all others | `irq2_line_hold` on VBlank | Simple level-2 IRQ from `LVBL`. |

### 2.7 ADPCM regions (`gfx_taito_x` is identical across the family)

| Game | adpcma | adpcmb | gfx1 |
|---|---|---|---|
| superman | b61-01.e18 (512 KB) | — | 4 × 512 KB |
| daisenpu / twinhawk | — (YM2151 — no ADPCM) | — | 4 × 512 KB |
| gigandes | east-10.16e (512 KB) | **east-11.16f (512 KB) — ADPCM-B** | 4 × 512 KB |
| gigandesa | same as gigandes | same | same |
| kyustrkr | (single chip, see ROM) | (?) | 4 × 512 KB |
| ballbros | (single chip) | — | 4 × 512 KB |

**Gigandes is the only family member that uses the YM2610 Delta-T
(ADPCM-B) channel.**  Our current `jt10` wrapper already handles ADPCM-B
in principle but we don't allocate the bank in `cfg/mem.yaml` for
Superman — gigandes will need a new SDRAM region.

### 2.8 Master XTAL split

| Game | 68k clock | Z80 clock | YM clock |
|---|---|---|---|
| superman | 16 MHz / 2 = 8 MHz | 16 MHz / 4 = 4 MHz | 16 MHz / 2 = 8 MHz |
| daisenpu | 16 MHz / 2 = 8 MHz | 16 MHz / 4 = 4 MHz | 16 MHz / 4 = 4 MHz (YM2151) |
| gigandes | 8 MHz (rough — MAME comment "8 MHz?") | 4 MHz (rough) | 8 MHz |
| ballbros | 8 MHz (rough) | 4 MHz (rough) | 8 MHz |
| kyustrkr | same as ballbros | same | same |

All sit comfortably on the 48 MHz framework clock with the existing
`jtframe_cen48` dividers (`/6` for 8 MHz, `/12` for 4 MHz).

---

## 3. Per-game implementation effort estimates

Ranked from least → most work, based on the deltas above:

### Tier 1 — trivial (config-only)
- **`supermanu`, `supermanj`**: already build — region MRAs.
- **`gigandes`/`gigandesa`**: same TC0140SYT + YM2610 + 2 buttons.
  Just needs: (a) input_r/input_w block for direct $900000-$90000F
  inputs (replacing C-chip path), (b) ADPCM-B SDRAM region, (c) FG
  yoffset constant swap (-0x12 → -0x0a), (d) MRA + macros.def per-game.
- **`ballbros`**: same as gigandes but no ADPCM-B and 1 button.
- **`kyustrkr`**: same as ballbros but 3 buttons and inverted coin-lockout.

### Tier 2 — moderate (new audio chip)
- **`daisenpu`/`twinhawk`/`twinhawku`**: needs **PC060HA** module (can
  port from `cores/rastan/hdl/jtrastan_pc060.v` and adapt — F2 reference
  also exists), **YM2151** sound CPU (jt51 instead of jt10), and a
  short 32 KB Z80 ROM region.  Plus vertical rotation handling
  (ROT270 — JTFRAME has `JTFRAME_VERTICAL`).

### Tier 3 — none in this family
All five sibling games share the X1-001A sprite, the 68k bus map
structure, and Y/X offset patterns.  No new sprite controller work,
no new tilemap controller, no new palette format.

---

## 4. Suggested order of work

### Phase A — Promote to "taitox" multi-game core
Rename `cores/superman/` → `cores/taitox/` (or new core alongside, share
modules) so the same RBF + multiple MRAs cover the family.  Decide:

- **Option A1**: rename in place — single core, all 9 setnames as MRAs.
  Faster but loses the per-game macros.def per-core isolation we have
  today.
- **Option A2**: keep `cores/superman/` working as today, create new
  `cores/taitox/` that includes Superman + cousins.  Two cores share
  most modules via `modules/` extraction.
- **Option A3** (recommended): keep Superman as-is, add per-cousin
  cores that import shared modules — `cores/gigandes/`, `cores/ballbros/`,
  `cores/kyustrkr/`, `cores/daisenpu/`.  Each has its own MRA + cfg
  but the HDL submodules (`jtsuperman_main.v` etc. with parameters)
  are reused.

Recommend **A3** because it preserves the per-core macros.def overrides
we already use for Superman (PXLCLK=8, vtimer overrides, JOY_RLDU, etc.)
and lets us tweak per-game without risking regressions in the others.

### Phase B — Tier 1 sibling, in order:

1. **Gigandes** — closest hardware to Superman; only delta is direct
   inputs + ADPCM-B + minor offset.  Best first target because: (a)
   exercises the input_r path we'll reuse, (b) exercises ADPCM-B which
   we haven't tested yet, (c) MAME has a public ROM hash so verification
   is easy.

2. **Ballbros** — adds the 1-button variant; otherwise identical to
   gigandes minus ADPCM-B.  Quick after gigandes.

3. **Kyustrkr** — 3-button variant; tests the schematic-confirmed
   "BUTTON3 at PA6" path that's tied high for Superman.  Also tests
   the inverted coin-lockout polarity.

### Phase C — Tier 2:
4. **Twin Hawk / Daisenpu** — port PC060HA + jt51 (YM2151).  Heaviest
   work because it changes both sound chips.  Also tests vertical
   orientation through JTFRAME.

---

## 5. Verification approach (per game)

For each cousin, before writing any HDL:

1. **Capture MAME reference** — boot the game in MAME, run attract loop
   for ~20 s, dump:
   - C-chip / shared-RAM (if any) snapshot
   - Sprite RAM at $D00000-$D007FF and $E00000-$E03FFF
   - Palette at $B00000-$B00FFF
   - Work RAM $F00000-$F03FFF
   - 4-6 attract-mode screenshots at fixed frame numbers
2. **MAME input trace** — same `trace_sound.lua` pattern we used for
   Superman, capturing 68k SYT writes + Z80 PC values at first sound
   command.
3. **MAME input port trace** — record what each IN0/IN1/IN2 byte looks
   like at idle vs each button pressed.  This confirms the bit layout
   matches the `TAITO_JOY_UDLR_N_BUTTONS_START` macro.
4. **Build a scene-replay suite** — modelled on `cores/superman/scenes/`
   so we can diff our HDL render against MAME for every attract scene.

Then implement the cousin's macros.def + mame2mra.toml + tiny `_game.v`
overrides, run scene replay against the MAME baseline, fix offsets /
input bits until pixel-match, then move to the next.

---

## 6. Open questions for next thread

1. **Core layout decision** (A1/A2/A3 above) — needs your call before
   any code moves.
2. **PC060HA module reuse** — is the rastan version a good base, or
   should we use the F2 reference for the Daisenpu port?
3. **MCU EPROMs for cousins** — Superman's `b61_11.m11` C-chip EPROM
   is unique to Superman; cousins don't have a C-chip so this isn't
   a blocker, but worth confirming MAME's hashes for each cousin's
   ROM set are available in `mame2mra` config.
4. **ADPCM-B for Gigandes** — confirm our `jt10` wrapper exposes the
   ADPCM-B bus correctly (we currently only feed adpcma; adpcmb may
   need a second SDRAM region wired in `mem.yaml`).
5. **Vertical orientation for Daisenpu** — does JTFRAME's
   `JTFRAME_VERTICAL` give us free rotation, or do we need to add
   `JTFRAME_ROTATE` and an MRA orientation override?

---

## 7. Quick reference — Superman fixes that apply universally

These are already in `cores/superman/hdl/` and should be **kept**
when extending to siblings:

- `jtsuperman_syt.v`: combinational `main_din` / `snd_din` (commit
  `92cc92689`) — required for the comm-port handshake to give the
  68k the correct data nibble during its read cycle.  Same fix
  needed in any new TC0140SYT or PC060HA wrapper.
- `cab_in0/cab_in1` byte packing: `{cab_1p, 1'b1, joystick[5:0]}`
  with **START at bit 7** (not bit 6), schematic-verified.
- `JTFRAME_JOY_RLDU` in `macros.def` — MiSTer HPS_IO delivers RLDU,
  game wants UDLR, this bit-reverses it.
- PXLCLK=8 + 512×272 vtimer — 15.625 kHz H rate for CRT sync.
- BG kiwi engine: `SCAN_LOW_FIRST=1` + `KEEP_OLD=0` (commit
  `b5c6aa7f1`) for MAME-correct draw_background overlay order.
