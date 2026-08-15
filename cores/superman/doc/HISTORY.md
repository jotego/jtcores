# Superman / Taito X System core — bring-up history

Living document. Records every commit in order plus the findings, decisions,
and dead ends that produced it. Pre-C-chip work is summarised; from the
graphics-pipeline phase onward each commit is documented individually so
this trail can be turned into a step-by-step tutorial.

Use the **"Tutorial spine"** at the very bottom as a curated list of
successful-only steps (skipping reverted commits and dead ends).

---

## Phase 0 — Core scaffolding & CPU bring-up

These commits land the 68k, Z80, YM2610, and TC0140SYT, then bolt the
real Taito C-chip (uPD78C11) on. They predate the graphics work and are
treated as a single block here. Each one is in `git log` if you want
detail.

- `290ca52bc` — Bring up Taito X System core (68k + Z80 + jt10 + TC0140SYT)
- `92ce95118` — C-chip ROM disassembly + boot-path notes
- `ea8adf330` — Integrate Fulvio's uPD78C11 (drops the HLEs)
- `5aec3684c` `d3aa1538c` `af625270b` `b8207fac0` `9cc81d845` `2e069b3e5`
  `a6576af19` `b5fc1e757` `279de632c` `114e57608` `41b05d2d3` `689690a80`
  — C-chip wrapper, INTF1 vblank pulse, ASIC/bank-map alignment with MAME,
  ADC wiring, status / audio probes.

**Key takeaway**: at this point the 68k boots all the way to the game-loop
idle, the C-chip retires real instructions, and the YM-side audio chain
is alive. The video pipeline is still emitting black frames.

---

## Phase 1 — First sprite output

### `f04653be1` — Three-panel BRAM viewer + xBGR palette correction

A debug renderer that scans palette / VRAM / OBJ-RAM across the screen so
any byte the CPU writes lands as a visible coloured cell. First time the
core emits anything other than black.

**Finding:** the palette is xRGB-555, not xBGR-555 like most jt cores.

### `a1b6fef41` — BRAM-shadow dump + MAME ground truth, 100 % OBJ match

Added a `$writememh` shadow dump of pal / vram / oram in HDL, then ran
`./mame superman -debug` with a Lua script to dump 0xB00000, 0xD00000,
0xE00000 from MAME memory. Byte-for-byte compare: the CPU is writing the
right OBJ data.

**Decision:** the visible "no sprites" problem is therefore in our **rendering
pipeline**, not the CPU.

### `ce65060dd` `c80df001d` — Position-only X1-001A renderer (debug)

`jtsuperman_obj_v2.v`: small custom renderer that shadow-loads 128 OBJ
slots and draws 16×16 solid-coloured rectangles at each sprite's (X,Y).
Confirms the OBJ-RAM layout (FG = OBJ word N + 0x200+N, sprite-Y in
VRAM word N low byte) but produces only coloured boxes, no real gfx.

**Dead end-ish.** Useful for proving layout; superseded by the kiwi engine.

### `a1c8b9e23` — Wire kiwi obj / draw with an address translator (no output yet)

Wired Jose Tejada's TNZS-derived kiwi sprite engine (`jtsuperman_obj.v` +
`jtsuperman_draw.v`) into the core. The kiwi engine drives a 12-bit
`lut_addr` that we translate to OBJ word offsets. Connected to bank 2 of
SDRAM for tile gfx.

**Output:** still nothing — `obj_cs` fires but `nonzero_data_ticks = 0`.

### `ddb975de8` — REAL SPRITE GRAPHICS visible — fix mem.yaml obj bus

Found that `cfg/mem.yaml` had `addr_width: 19` and a non-zero
`OBJ_OFFSET` on the obj bus. The kiwi engine wants a 21-bit byte address
(= 19-bit 32-bit-word address). Widened the bus to `addr_width: 21`,
dropped the offset, dropped the `scr` bus (Superman has no tilemap layer
through this chip).

**Finding:** the SDRAM controller had been mapping our `obj_addr` to the
wrong byte range. With the right width, gfx ROM data flows.

### `d60b903c2` — Y inversion per X1-001A — screen_y = 240 − vram_y

MAME OBJ-RAM dump showed BG region (0x800-0x3FFF) empty for the TAITO
splash, so all visible sprites are FG. Active vram_y values cluster at
0xE2 (= 226) and 0x0A (= 10). Replaced the kiwi's natural `y_data =
vram_y` with `8'd240 - vram_y` to flip Y per MAME's `max_y - sy`
semantics.

### `17b561bab` — TITLE SCREEN VISIBLE — palette mask fix

X1-001A uses **16 palettes**, not 32. MAME does `color %= total_color_codes`
with `total = 16`, so the palette field's MSB has to be dropped. Without
this, palette 24 (where the blue TAITO logo lives at `$181`) was
collapsed onto palette 8 (yellow at `$81`). First time real attract
content was on screen, though still rendered yellow instead of blue.

### `3673e24f9` — Invert both H and V flip bits — TAITO logo upright

The kiwi engine's `hflip` / `vflip` polarities (TNZS X1-001) disagree
with our X1-001A gfx-ROM byte interleaving. With bits 15/14 unchanged
the logo came out simultaneously upside-down and horizontally mirrored
("TAITO" read as "OTIAT"). Toggle bits 15 and 14 on the code+ctrl word
only (gated by `sel_xcolor_q` so the X+color word's colour byte stays
intact).

### `b0bbae01f` — Full 5-bit palette + R/B channel swap, TAITO logo is BLUE

Two bugs were folded together under the earlier palette mask hack:

- The mod-16 mask folded MAME's palette 24 onto our palette 8. Drop the
  mask so the engine's full 5-bit `pal[4:0]` reaches the palette RAM
  intact (`palette[$000..$1FF]`). This moved colours from yellow to red.
- X1-001A palette is **xRGB-555** (R high, B low), not xBGR-555 as most
  jt cores assume. Swap red and blue at the `pal_dout_b_w` decode and
  the TAITO logo's real blue appears.

### `46e331db3` — Remove palette-grid debug background

Non-sprite pixels were indexing the palette by `{vdump,hdump}` (the old
debug viewer). Replace with `palette[$000]` so the backdrop is black.

---

## Phase 2 — Y formula nail-down

### `24c4037e2` — MAME-exact Y formula (REVERTED)

Tried `8'd10 - vram_y` derived from MAME's no-flip formula with visarea
y[8..247]. Looked plausible on paper but the rendered layout had CREDIT 0
at the top — user feedback confirmed wrong against the MAME ground-truth
screenshot.

### `354b5cee0` — Revert the above.

### `cf2bd9250` — Y formula `226 - vram_y` — visarea y[16..239] take

Used `set_visarea(0,16)-(383,239)` from the non-cchip variant of taito_x
in MAME. Visible text rows were close but the whole layout was 8 px too
high.

### `1e97a4240` — Visarea correction is −8 (cchip variant), not −16

Found the correct visarea line in `taito_x.cpp:1045` — the cchip variant
uses `(0,8)-(383,247)`. Formula becomes `8'd234 - vram_dout_b_w[7:0]`.
Score row at row 8, CREDIT 0 at row 224 with one row of bottom clip.

---

## Phase 3 — BG-column layer

### `184635c20` — BG-column scaffolding (second kiwi engine)

X1-001A has two sprite paths: FG (OBJ 0x000-0x3FF, individual per-sprite
positions) and BG (OBJ 0x400-0x7FF, 16 columns × 32 sprites each, per-
column scroll). Wired a second `jtsuperman_obj` instance with `page=1`
to read the BG region. Both engines need OBJ-RAM port-B access so we
**duplicated** the OBJ BRAM in `jtsuperman_main.v` (mirrored CPU writes).
The two BRAMs use independent SDRAM gfx buses (`obj` and `bg` in
mem.yaml).

**Finding:** the attract BG region is empty during the TAITO splash; need
to advance further into attract before BG sprites populate.

### `15fa92755` — Scene-replay infrastructure (4× faster sim)

Full CPU sim takes 5+ minutes for 160 frames. Use JTFRAME's standard
scene-replay path so we can iterate on rendering at 1m11s per render:

- `NOMAIN`/`NOSOUND`/`SIMSCENE` macros stub the CPU and Z80 in HDL.
- Mirrored BRAM instances (`u_pal_sim`, `u_vram_sim`, `u_oram_sim`,
  `u_oram_bg_sim`) in the `else NOMAIN` branch of main.v load the RAM
  contents from binary files via the framework's `SIMFILE` parameter.
- `sim.sh -s <scene_dir>` drops the local -s parser and lets `jtsim`
  handle it.
- `cores/superman/ver/superman/scenes/<scene>/dump.bin` is a
  concatenation of pal.bin + vram.bin + oram.bin captured from MAME.

**Decision:** every BG/FG rendering issue from here on is debugged via
scene replay, not full CPU sim.

### `c6d321377` — Per-column BG scroll + rest2bin hook + supes_logo scene

Per-column scroll values live at `m_spriteylow[0x200..0x2FF]` (= our VRAM
words 0x200..0x2FF). Two arrays (`bg_scrolly_arr`, `bg_scrollx_arr`) and
an FSM that walks the 16 columns each VBLANK, reads scrolly at
0x200+col*0x10 and scrollx at +4. BG kiwi `y_data` becomes
`231 + scrolly[col] - (offs/2)*16` and the X+color word's xpos bits are
overwritten with `scrollx[col] + (offs&1)*16`.

`ver/game/rest2bin.sh` is the per-core hook called by JTFRAME's
auto-regenerated `dump2bin.sh`; we use it because Superman's BRAMs are
hand-instantiated rather than declared in mem.yaml, so the template
emits an empty `split_into_parts` and we have to split rest.bin
ourselves.

### `d5d19c775` — Burst-capture script — 12 scenes from one MAME run

`mame_scripts/dump_burst.lua` uses `emu.register_frame_done` to fire the
RAM-dump-and-screenshot at every entry in a `targets` list, all in one
MAME launch. `scenes/burst_capture.sh` collates the per-frame
`/tmp/superman_burst_<frame>_*` dumps into per-scene directories,
concatenates them into `dump.bin`, and converts the raw RGBA screen
capture to PNG.

**Outputs:** 12 attract scenes including `burst_01200` (green villain
panel) and `burst_01800` (real gameplay frame). High-value targets for
the rest of the work.

### `e96df6037` — Fix BG scroll-load FSM 1-cycle BRAM-latency bug

`jtframe_dual_ram` has a 2-cycle effective latency from "schedule addr"
to "data on q" because both addr1 and qq1 are registered with the same
clock edge — at the edge that promotes addr1 from OLD to NEW, qq1
latches `mem[OLD]`. The 3-phase scroll-load FSM in c6d321377 captured a
cycle too early, so `bg_scrolly_arr` held whatever was on port-B before
the load and `bg_scrollx_arr` held the **scrolly** values.

**Visible symptom:** every BG column rendered at the same X (because the
cached "scrollx" was actually scrolly, identical across most columns).

**Fix:** widen `load_phase` to 3 bits, insert wait states between issue
and capture (`0:issue Y, 1:wait, 2:capture Y + issue X, 3:wait, 4:capture
X, advance col`). Now multiple BG columns appear at distinct X
positions.

### `ae917864d` — BG Y uses no-flip ordering (offs=0 at top)

User-empirical observation on burst_01800: with the screenflip Y formula
the BG tile at offs=0 lands at the BOTTOM of its column, but MAME draws
it at the TOP with offs values increasing downward. Switch BG y_data to
`(offs/2)*16 - scrolly[col]`. No visarea −8 applied here because the BG
layer in MAME tiles starting at chip_y=0.

### `504101ee6` `726345c3d` — Hardcoded BG_STARTCOL = 4 (REVERTED)

The non-cchip `startcol` formula from MAME's `draw_background` is
`(ctrl[0] ? 4 : 0) + (ctrl[1] ? 8 : 0)`. Initially hardcoded `4` because
that subjectively matched the layout, but a scene-dump of
`m_spritectrl[0]` showed `0x10` everywhere we'd captured (bits 0 and 1
both zero), so the correct value is `0`. Revert. The "4 looked right"
match was a misread of MAME's screenshot — I was wrong about which BG
tiles were the graffiti vs the brick wall.

### `171048b80` — Implement BG `upper` register — cols 8..N draw at X+=256

MAME `seta001.cpp:297,318` computes
`upper = m_spritectrl[2] + m_spritectrl[3] * 256` and for each BG col
where `upper & (1 << col)` is set, shifts sx by −256. This is the
X1-001A's right-half wrap for the BG layer.

**Visible symptom before fix:** burst_01200's green villain (cols 0..7
and 8..11 carry the same image codes) rendered ALL cols at scrollx
0..96 = clumped at the left. After implementing the `upper` shift, the
right half (cols 8..11) moves to scrollx 256..352 and the villain
appears centred.

**Implementation:** the per-VBLANK scroll-load FSM is extended to also
read `m_spritectrl[2]` at VRAM word 0x302 and `m_spritectrl[3]` at
0x303 after the 16 col-scroll passes. `load_state` widens to 5 bits
(0..15 = cols, 16 = ctrl2, 17 = ctrl3, 18+ = idle). Add 9'd256 to the
X-inject when `upper[scroll_idx]` is set; in 9-bit arithmetic, +256 ==
−256 mod 512.

### `64fc5218b` — Extend burst capture — 33 scenes covering 120 s of attract

Two passes of frame targets in `dump_burst.lua`:
- frames 30..300 every 30 (motion across early splash)
- frames 600..7200 every 300 (full attract loop, twice)

Useful gameplay frames now include `burst_03600` (Baptist Church) and
`burst_05700` / `burst_06000` (Superman flying over a city skyline).

**Survey finding:** every scene across 120 s of attract has scrolly ∈
{0, 249, 255}, so Superman attract is purely a horizontal-scroll level
— no within-frame Y parallax to exercise.

---

## Phase 4 — pixel-level alignment & open issues (CURRENT)

### Bank-shadow investigation result

Dumped FG sprites by region in `burst_01200`:
- Bank 0 FG (OBJ words 0..0x3FF): 503 non-zero words.
- Bank 1 FG (OBJ words 0x800..0xBFF): all zero.

The X1-001A `setac_eof` bank-swap mechanism (gated by
`m_spritectrl[1] & 0x40`) is therefore NOT the source of the missing
red labels — bank 1 is genuinely empty in the captured scenes.

What I *had* missed: my earlier FG-sprite enumeration only walked
slots 0..255, but FG slots 256..511 also contain real sprites (104 of
them at vram_y=250 in burst_01200, codes like ',', '.', '1', '7',
'8', '9', 'A', 'B' = pieces of "TAITO CORPORATION 1988"). Our pipeline
*is* iterating those slots (the kiwi engine runs `objcnt = 0..0x1FF`,
the address translator routes them to OBJ 0x000..0x1FF + 0x200..0x3FF),
so they reach the BG/FG kiwi just like the first 256.

### The K=234 vs K=10 mystery

Building the table of what MAME's no-flip formula
`display = (266 - vram_y) & 0xff` predicts vs. what our K=234 formula
gives:

| vram_y | MAME row | OUR K=234 | OUR - MAME (mod 256) |
|---|---|---|---|
| 10  | 0   | 224 | +224 |
| 74  | 192 | 160 | -32  |
| 226 | 40  | 8   | -32  |
| 242 | 24  | 248 | +224 |
| 250 | 16  | 240 | +224 |

The diffs are either +224 or -32, which are the same value modulo 256
(+224 == -32 - 256). So K=234 == K=10 + 224 mod 256: our formula is
literally `MAME formula + 224 mod 256`, with the wrap-around producing
the apparent pixel match on burst_01200's INSERT COIN (`234-74 = 160`
matches MAME's measured row 160 only by 256-modular coincidence).

The systematic byproduct: every vram_y in {10, 226, 242, 250} (where
MAME draws the red labels, score values, copyright text, INSERT COIN
header at the *top* of the screen) is being displaced 224 rows down
and clipped off the bottom of our 240-row visible area.

### K=10 (MAME no-flip exact) retry

With all the other fixes now in place (palette decoded right, BG layer
including the `upper` register, per-column scroll), retrying K=10 on
burst_01200 produces a layout that is **structurally** much closer to
MAME than K=234 was:

| Element | OURS K=10 | MAME | Offset |
|---|---|---|---|
| Red labels | rows 33..39 | rows 0..6 | +33 |
| White score | rows 5, 11 (CREDIT 0 text?) + 41..47 | rows 8..14 + 228..234 | mixed |
| Cyan INSERT COIN | rows 193..199 | rows 160..166 | +33 |
| White HUD | (missing) | rows 228..234 | — |

The label, INSERT COIN, and score rows all have a **constant +33 px**
offset from MAME. K=233 (= 10 - 33) hits the INSERT COIN, score, and
HUD rows MAME-exact — but then the vram_y=10 sprites that should be
the red labels at MAME row 0 end up at row 224 (the HUD area).

### Real second bug — bit-plane extraction colours

Looking at MAME's burst_01200 RED labels at rows 0..6 and the WHITE
score at rows 8..14 — both at MAME row 0..15, that is, BOTH inside
the 16-row span of the same sprites at vram_y=10. The 16x16 gfx
tile has **two rows of text** glued vertically: the label (red top
7 rows) and the digit (white bottom 7 rows).

In our pipeline, those same sprites at the same vram_y render only
the white digits (visible at our K=10 rows 5 and 11) — the red top
half is **invisible**. The palette is byte-identical with MAME's
dump (verified earlier), so the bug is in `jtsuperman_draw.pxl_in`:

```verilog
assign pxl_in = hflip ?
    { pxl_data[23], pxl_data[ 7], pxl_data[31], pxl_data[15] } :
    { pxl_data[16], pxl_data[ 0], pxl_data[24], pxl_data[ 8] };
```

That ordering is what the kiwi TNZS X1-001 engine ships with. For
X1-001A's gfx-ROM byte interleaving the right ordering is probably
the natural Seta convention (`{pxl_data[24], [16], [8], [0]}`). I
tried that earlier in an unstaged attempt #1 and it produced no
visible change ON THE TAITO LOGO — but the logo is all one colour
index, so it can't tell the difference between bit-plane orderings.
Now that we have text content (multi-colour glyphs in a single tile),
the wrong ordering becomes visible.

### Investigation queue

- **Bit-plane extraction (attempted)**: tried the natural Seta
  `{pxl_data[24], [16], [8], [0]}` ordering — that's what MAME's
  `gfx_layout` `{ STEP4(0,8) }` literally says.  The result was much
  worse than the kiwi TNZS ordering: burst_01200 came out with a brown
  background instead of black, a blue/white villain instead of green,
  and grey labels instead of red.  Reverted.
  
  Root cause: `taito_x.cpp` loads gfx1 with `ROM_LOAD32_WORD_SWAP` —
  f1 (annotated "Plane 0, 1") at byte offset 2 of each 32-bit word
  and j1 ("Plane 2, 3") at byte offset 0, with each 16-bit ROM word
  byte-swapped.  After this byte juggling the 4 bytes of the 32-bit
  gfx word do NOT line up with planes 0..3 in the gfx_layout order;
  some other permutation does.  24 permutations are possible (4!),
  the kiwi TNZS ordering is one of them and is *close* but produces
  the wrong colour index on multi-colour tiles (visible at
  burst_01200's vram_y=10 sprites where the red top half + white
  bottom half of the 16x16 tile renders only white in our pipeline).
  
  Next step: either enumerate the 24 plane permutations by sim, or
  derive the correct one from the schematic ROM-to-X1-001A pinout
  in `Superman [schematics].pdf`.

- **Y-formula constant**: settle on K=233 (best match for visible
  sprites at rows 8/40/160/192/228) versus K=10 (correct for vram_y=10
  at top), once the bit-plane fix reveals what the red labels actually
  look like.

- **Dynamic `startcol`** from `m_spritectrl[0]` bits 0/1.

- **Schematic dive**: pixel-clock frequency, gfx-ROM pinout, FLIP pin.

---

## Tutorial spine — successful-only steps in order

For the eventual step-by-step tutorial, use **only** these commits.
Reverted experiments and dead ends are intentionally excluded.

1. **Bring up the framework** (`290ca52bc`): 68k + Z80 + jt10 +
   TC0140SYT skeleton.
2. **Real C-chip** (`ea8adf330` + follow-ups through `689690a80`): drop
   the HLEs and run the real uPD78C11.
3. **BRAM viewer + xRGB palette format** (`f04653be1`): produces the
   first non-black frame and pins down the palette byte order.
4. **MAME ground-truth dump** (`a1b6fef41`): proves the CPU is writing
   the right OBJ data, so the rest of the work targets the rendering
   pipeline.
5. **Widen the OBJ SDRAM bus** (`ddb975de8`): `mem.yaml addr_width: 21`
   on the `obj` bus; drop the unused `scr` bus. Without this, the
   kiwi engine's reads are mapped to the wrong byte range.
6. **Y inversion** (`d60b903c2`): `8'd240 - vram_y` per the X1-001A
   `max_y - sy` convention. (This is the simplest formula that brings
   the title screen up; refined later.)
7. **Palette decode** — three steps:
   - `17b561bab` palette mask fix (16 palettes, not 32)
   - `3673e24f9` invert H and V flip bits (X1-001A polarity vs TNZS)
   - `b0bbae01f` full 5-bit palette + R/B swap (TAITO logo blue)
   - `46e331db3` drop the palette-grid debug background
8. **Visarea -8** (`1e97a4240`): Superman is the cchip variant with
   `set_visarea(0,8)-(383,247)`, not the y[16..239] of the other taito_x
   games. Final FG formula `8'd234 - vram_y`.
9. **BG-column scaffolding** (`184635c20`): second kiwi instance with
   `page=1`, mirrored OBJ BRAM, second SDRAM gfx bus.
10. **Scene-replay infra** (`15fa92755`): NOMAIN-branch SIMFILE-loaded
    BRAMs, drop sim.sh's local `-s` parser, ~1 min per render.
11. **Per-column BG scroll + rest2bin hook** (`c6d321377`): 16-entry
    scrolly/scrollx arrays loaded from VRAM 0x200..0x2FF during VBLANK,
    applied to BG y_data and X-inject.
12. **Burst capture** (`d5d19c775` + `64fc5218b`): 33 attract scenes
    from a single MAME run via an `emu.register_frame_done` Lua hook.
13. **FSM BRAM-latency fix** (`e96df6037`): 5-phase per-column FSM with
    wait states (BRAM is 2-cycle from issue to data on q).
14. **BG Y no-flip ordering** (`ae917864d`): offs=0 at the top, offs
    increasing downward; `(offs/2)*16 - scrolly[col]`.
15. **`upper` register** (`171048b80`): VBLANK reads of
    `m_spritectrl[2]` (VRAM 0x302) and `m_spritectrl[3]` (VRAM 0x303),
    forming `upper[15:0]`; cols where `upper[col]` is set get
    `bg_xpos_inject += 256`.

After step 15: the FG-Y formula is right within 1 px, the BG layer
renders the right columns at the right X, the green-villain frame and
the gameplay frames look broadly like MAME. Top RED labels are still
missing — that's the next step (sprite bank-shadow).

16. **Bank-shadow ruled out**: dumped bank 1 of OBJ-RAM
    (0x1000-0x1FFF) on `burst_01200` — it is empty, so the missing RED
    labels at the top of the screen are not a `setac_eof` shadow swap
    issue.
17. **Misdiagnosis corrected**: a brief attempt to re-derive the
    plane-extraction from the schematic was undertaken on the
    assumption that colors were wrong on multi-color tiles.  User
    correction: colors have always been right; the missing red labels
    are a **positioning** issue (sprites drawn off-screen, not the
    wrong color).  The pinout-derived experiment was reverted — the
    committed TNZS-style ordering stays:
        non-flip pxl_in = { pxl_data[16], pxl_data[ 0],
                            pxl_data[24], pxl_data[ 8] }
    The schematic intel (pair 37-38=planes 0,1, pair 43-45=planes
    2,3, byte lanes on CGD:C10-C47) is recorded here for future
    reference but is not driving any HDL choice right now.

18. **Measured FG/BG Y-offsets via docker sim**: ran
    `FRAMES=1 ./sim-core.sh superman superman -s ../superman/scenes/burst_01200`
    and pixel-compared `frames/frame_00063.jpg` to MAME's `screen.png`.
    Red labels are NOT missing — they render correctly. The FG layer
    is shifted DOWN by a **constant +33 lines** vs MAME, the BG layer
    by **+8 lines**.

        | sprite           | sy/group | MAME img_y | FPGA img_y | shift |
        |------------------|----------|------------|------------|-------|
        | Red labels (FG)  | sy=10    | 0..6       | 33         | +33   |
        | Score values (FG)| sy=242   | 8..14      | 41         | +33   |
        | INSERT COIN (FG) | sy=74    | 160..166   | 193        | +33   |
        | CREDIT 0 (FG)    | sy=??    | 228..234   | 5 (wrap)   | +33   |
        | Green villain BG | —        | 45..162    | 53..164    | +8    |

19. **K compensation for kiwi-engine constant offset**: applied two
    separate Y offsets to compensate the measured constant shifts.

    First tried K=233 (= 10-33): MAME-pixel-perfect for INSERT COIN,
    score values, CREDIT, and BG villain. But the red `1UP`/`HIGH
    SCORE`/`2UP` labels (sy=10) end up clipped 6 px above the visible
    top — their tile content sits right at the edge so half hides.

    Bumping K to 239 (=10-27, only +6 from 233) does NOT shift labels
    down by 6 — it makes them VANISH entirely. The kiwi engine's
    top-of-frame match window has a hard boundary; sprites whose
    `y_data` puts them in that boundary just don't render. K=242
    (=10-24) lands all labels fully inside the visible area but
    shifts everything +9 below MAME-exact. Per user preference K=242
    is the committed value — visually cleaner than K=233's clipped
    labels at the cost of a uniform 9-pixel offset.

    A proper fix requires changing the kiwi engine's vf/buffer-flip
    timing so display row 0 can receive a sprite write (currently the
    engine resets through vdump=249..263 and `vf=vdump-1` means it
    can't write the buffer for display row 0). User suggested looking
    at MAME's seta001.cpp / TNZS source as reference and possibly
    abandoning the kiwi engine entirely if needed.

    Tried removing the `vdump > 9'hf8` reset window in jtsuperman_obj
    so the engine would have all 15 VBLANK lines to scan — no visible
    change to the clipped-labels symptom. The issue is downstream:
    `vf = vdump - 1` + 1-line buffer-flip latency means sprite top
    can never land at display row 0 with normal y_data; the engine
    would have to scan at vdump=263 for sprite row 0 to display at
    vdump=0, which requires the match formula to handle that wrap
    (it currently doesn't).

    Reference: cabal sim.sh (asturur/jtcores cabal branch) is a clean
    docker-wrapped scene-replay script that we should model future
    Superman sim.sh updates on.

20. **Vtimer alignment to TNZS-style structure**: MAME confirms
    Superman is 384x240 (240 visible lines) while TNZS is 256x224
    (224 visible). The kiwi engine was designed for TNZS's vtimer
    structure (V_START=8, VB_END=15, VB_START=239) and our previous
    Superman vtimer (V_START=0, VB_END=0, VB_START=240) didn't give
    the engine its expected pre-visible VBLANK window. Updated to:

        V_START  = 9'd008    (TNZS-style)
        VB_END   = 9'd015    (visible starts at vdump=15)
        VB_START = 9'd255    (visible ends at vdump=254)
        VS_START = 9'd259
        VCNT_END = 9'd271    (264 total, same as TNZS)

    Visible region is now vdump 15..254 = 240 rows. Also bumped the
    kiwi reset condition from `vdump > 9'hf8` (=248) to
    `vdump > 9'd254` so the engine doesn't reset during our shifted
    visible area.

    Effect: FG offset vs MAME drops from +33 to +18 lines. Labels
    are at JPG Y=18..24 (MAME 0..6), INSERT COIN at 178..184
    (MAME 160..166), etc. Still not pixel-exact; CREDIT at MAME
    Y=228 lands too close to the visible bottom edge with the +18
    shift. Closing the remaining +18 gap needs further investigation
    of the kiwi engine's internal pipeline delay.
