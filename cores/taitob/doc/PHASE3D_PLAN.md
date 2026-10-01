# Phase 3d — sprite engine bring-up plan

This is the largest remaining piece of the TC0180VCU.  Everything else
(BG + FG + TX + scroll + ctrl[7] decode) is in place.  Sprites are a
distinct architectural unit and warrant a focused implementation pass.

## What the chip does

Per `cores/taitob/doc/tc0180vcu.cpp::draw_sprites` (lines 370–495):

* Sprite RAM lives at oram word offsets `0x0000-0x0CBF` (= 0x1980 bytes
  at the 68k's 0x410000-0x41197F window).
* 408 sprites total, 16 bytes (8 words) per slot.
* Per-sprite layout:

```
offset  bits          field
0       16            tile_code (up to 0x7FFF)
1       0..5          color (palette index 0..63)
        14            flipX
        15            flipY
2       0..9 (signed) x-coordinate (10-bit, -512..511 then wrap)
3       0..9 (signed) y-coordinate
4       0..7          y-zoom (0=100%, 0x80=50%, 0xC0=25%, 0xFF=off)
        8..15         x-zoom
5       0..7          y-sprites count - 1 (big sprite)
        8..15         x-sprites count - 1
6..7    unused
```

* Iteration order is **reverse** — `offs` walks from 0xCB8 down to 0.
  Later sprites in memory draw first; earlier sprites overlay them.
* "Big sprites" stitch multiple 16x16 tiles into a larger figure; the
  first slot has dimensions, subsequent slots use latched values.
* Zoom is implemented in MAME by chunking the sprite into 16x16
  sections instead of one true zoom (acknowledged-buggy at MAME line
  457 — we should replicate the same behaviour for compatibility).

## Architecture plan (REVISED after the BG/FG/TX ring + gfx_sort work)

Context that changed since this plan was first written:

* **All three tile planes (BG/FG/TX) are now `jttaitob_shifter` rings**
  filled during HBLANK; during ACTIVE the `bg`/`obj`/`tx` SDRAM buses
  are **idle** (the rings read decoded pixels from BRAM, not SDRAM).
* **`gfx_sort=hvvvx`** reorders the shared gfx region's address bits.
  Any consumer of that region must apply the `gsort()` swap.  Sprites
  use `gfx(1)` (the same 16×16 tilelayout) → **sprites must use gsort**,
  and get the same burst-cache speedup for free.
* A shared `fill_line` (latched `vrender` at HBLANK kick) gives all
  fills a single frozen line reference, immune to the mid-HBLANK vdump
  increment.

### No SDRAM bus refactor needed (old "Option A" is obsolete)

The old plan wanted to move FG off `obj` to free it for sprites.  Not
necessary: FG only touches `obj` **during HBLANK** (its ring fill),
and `obj` is **idle during ACTIVE**.  So the sprite engine fills the
next line's buffer **during ACTIVE on `obj`** — they time-share by
phase (FG = HBLANK, sprites = ACTIVE), no contention, no refactor.

### 1. Sprite-list scanner

Walk the 408-slot list (reverse, `offs` from 0xCB8 down by 8) from
oram port-B.  Per slot read y (word 3) first; if the target line is in
`[y, y+16)` (×big/zoom later), queue the slot (code/color/flip/x/zoom).
Limit to a per-line cap (e.g. 32) to bound the render budget.

### 2. Sprite renderer (during ACTIVE, for the NEXT line)

For each queued slot: compute the 16×16 gfx row via `gsort` on the
`obj` bus (4 words/row like BG/FG, burst-cached), apply flipX/Y, write
`color*16 + pen` (pen≠0) to the write line buffer at screen-x.  Active
gives ~1920 clk/line — ample for a capped sprite count with fast
(cached) gfx reads.

### 3. Line buffer (ping-pong)

Two `jtframe_obj_buffer`-style 320×12 BRAMs.  Fill buffer A for line
N+1 during line N's ACTIVE; read buffer B (line N) during the same
ACTIVE; swap each line.  (Clear the just-read buffer as it drains, so
the next fill starts blank — the chip's per-frame erase.)

### Output mux

Add the sprite (obj) layer.  Per `ctrl[7]` bit 3:
* Mode 1 (bit3=1): `bg < fg < obj < tx`
* Mode 0 (bit3=0): `bg < obj1 < fg < obj0 < tx` (obj0/obj1 by color bit0)

nastar boots `ctrl[7]` high byte `0x28` → bit3=1 → **Mode 1** first.

## Incremental delivery (commit per step, grade on the 5 scenes)

* **3d-a — basic unscaled sprites.** Scanner + renderer (no zoom, no
  big-sprite) + ping-pong buffer + Mode-1 mux.  nastar/rastan2 sprites
  are mostly unscaled, so this should fill in the "missing pieces".
* **3d-b — big sprites** (multi-tile, latched dims).
* **3d-c — zoom** (replicate MAME's 16-px-chunked scaling, line 457).
* **3d-d — priority Mode 0** (obj0/obj1 split by color bit 0).

## Estimated effort

* Scanner FSM + queue:        ~120 lines
* Renderer (3d-a, no zoom):   ~120 lines
* Ping-pong line buffer:      ~60 lines (reuse jtframe_obj_buffer)
* Priority mux update:        ~25 lines
* zoom / big-sprite (3d-b/c): ~150 lines (later)

## Validation gates

Sprite implementation should be validated against:

1. First sprite-list read after game writes to sprite RAM (Phase 3d).
2. First sprite rendered to line buffer (Phase 3d).
3. Visible sprite on frame (compare to MAME capture).
4. Zoom values 0x40, 0x80, 0xC0 produce correctly-sized sprites.
5. Big-sprite mode forms correct multi-tile figures.
6. flipX/Y mirror correctly.
7. Priority mode 0 vs mode 1 visible difference (sprites over/under FG).

Each of those is a 30-min validation step worth a discrete commit.
