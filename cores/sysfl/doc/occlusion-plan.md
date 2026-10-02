# C123 occlusion: row-level layer skip, then the coverage cascade

Target: the sdram64 controller at the stock 48 MHz clock (this branch).
Goal: cut the 6-layer tilemap fetch load using what the other planes
already know, without DDR framebuffers.

Credit: stage 1 mirrors the scheme found in XelaNotPu's System FL core
(road publishes per-row solidity+priority; tile compositor skips layers
that provably lose). Stage 2 is our stronger generalization.

## Mixer contract (jtc116.sv:97-102) — the safety rule

- `scr_eff = {scr_prio,1'b0}` (3-bit tilemap prio doubled into the 4-bit
  shared space)
- tilemap beats ROZ when `scr_eff >= roz_prio` (ties -> tilemap)
- sprites beat background when `obj_prio >= bg_prio`

A tilemap layer may be skipped on a row ONLY if every pixel would lose:
row fully covered by opaque ROZ AND `scr_eff < roz_row_prio` (strict).
Shadow pixels (obj 0xffe) modify the pixel behind them and must never
count as cover anywhere in this plan.

## Stage 0 — port the validated cheap wins from the lanes work

1. BLANK tile skip: code 0x0020 never touches the SDRAM port (prefetch
   and pixel paths). Measured on lanes: ~118k skips per burst scene.
2. Line-start clear sweep: cut tails render transparent, no downward
   smudge. Both are controller-agnostic c123 changes.

## Stage 1 — ROZ row summary + whole-layer skip

1. Measure first: how far ahead of the beam does jtc169's `lline` run
   vs the line c123 renders (c123 writes the linebuf half displayed
   NEXT). If c169 completes line L before c123 starts L, its summary is
   usable directly; otherwise c169 must lead one more line (second line
   buffer bank) or c123 consumes the summary one row late (NOT allowed:
   horizon rows would glitch — lead extension is the correct fix).
2. jtc169 publishes at each line completion: `{covered, minprio}` —
   covered = every visible x written opaque this line (track while
   writing; both ROZ layers fold in), minprio = min priority among the
   drawn pixels. Conservative by construction.
3. jtc123 at line start: for each enabled layer, `skip_row[i] =
   covered && {cfg_prio[i],1'b0} < minprio`. Skipped layers are treated
   as disabled for the line: no map read, no unit fetch, no xing stall
   (fold into cfg_enb_eff for the line).
4. Expected win: Speed Racer gameplay rows are mostly solid road; the
   4 scroll layers under it stop fetching entirely on those rows.

Gates (speedrcr only, per current regime): burst_07200 + road scenes
03900/05400/06000 pixel-identical vs this branch's fresh baselines
(skip changes timing, never pixels — any pixel diff is a bug in the
skip condition); SCRA/SOBJ/ROZA cut counts recorded; 500-frame
speed1_fast boot, 0 errors, 3 coins.

## Stage 1b — the reverse direction: fixed layers over ROZ (optional)

The two fixed layers (HUD/text, no scrolling) sit above the road in
gameplay. Their coverage for a line is computable one line early with
a dedicated row prepass (map words from the VRAM BRAM, opacity from the
tile mask bytes), letting jtc169 skip texel fetches under opaque HUD.
Small win (HUD is sparse); build only after 1 is measured, and reuse
the same strict-priority rule in the other direction:
roz skips only where {scr_prio,1'b0} >= roz_prio AND the HUD pixel is
opaque. Shadow rule unchanged.

## Stage 2 — staggered coverage cascade (design, build only if stage 1
is not enough)

Render the 6 tilemap layers front-to-back, layer k on line N-k, each
consulting (a) accumulated opaque coverage of higher tilemap layers,
(b) per-pixel obj/roz cover masks ("their prio beats this layer's"),
skipping fetch and paint of covered runs. obj/roz line buffers deepen
into rings (greedy lead) to persist the lines the cascade needs.

- Every layer gets a full line budget instead of sharing one.
- Occupancy = opaque AND NOT shadow (0xffe). Because stages run in
  strict priority order, ONE occupancy bit per pixel per in-flight
  line suffices ("someone above wrote here"); the obj wmaskg/gfull
  first-write-wins machinery is absorbed by it.
- Shadows are a modifier bit in the slot, applied when the lower stage
  writes the pixel, never as cover.
- Per-line latch of the priority sort and scroll regs (raster
  effects); the stage order is derived from the priority registers at
  line start, never hardcoded (bands are scene-dependent).
- Slot count for the full cascade (scr-above @N, sprites @N-1, roz
  @N-2, scr-below @N-3, beam behind): 4 in flight plus the displayed
  line; retires the obj double buffer and both roz linebufs, so BRAM
  is roughly neutral.
- Added display latency: ~4 lines (vtimer lead adjustment). No DDR
  involved.

Go/no-go after stage 1: if road-heavy scenes drop to ~0 scr cuts and
obj/roz improve from the freed bandwidth, stage 2 is shelved.
