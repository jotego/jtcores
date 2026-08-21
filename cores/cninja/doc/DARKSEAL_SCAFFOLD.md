# Dark Seal — scaffolding plan (ready to apply)

Concrete, ordered implementation plan to bring up Dark Seal as **game_id = 2** of
the cninja core. Grounded in `DARKSEAL_HW.md` + `DARKSEAL_BOOT_TRACE.md`.

**Prereq decisions for the user (flagged, do these first):**

- **D1 — palette mux.** Dark Seal is 24-bit RGB888 across two regions
  (0x140000 RG + 0x141000 B-ext); cninja is 12-bit RGBx_444 in one. Options:
  (a) a separate `jtcninja_pal_dseal` BRAM pair + colmix path selected by
  game_id; (b) widen the existing palette to 24-bit and have cninja write only
  the low bits. **(a) is cleaner and keeps cninja untouched** — recommend (a).
- **D2 — ROM bank offsets: shared vs per-game.** The HDL reads fixed SDRAM bank
  offsets (the `*_START` macros). Dark Seal's region sizes differ from cninja's.
  Either (a) game_id-mux the offsets in the address math, or (b) pad both games
  to a common layout. The superman core uses per-game header + a shared layout;
  **recommend matching that** — pick bank starts that fit BOTH games and let
  each MRA pad. Confirm before editing `mem.yaml`/`macros.def`.

---

## Canonical order (do the cheap reuse first, risky decode last)

### Step A — config scaffolding (no shared-HDL risk if gated carefully)

1. **mame2mra.toml**: add `darkseal` as a second machine.
   - `parse.machines` / `mustbe.machines`: add `"darkseal"`.
   - `[header]` data: `{ setnames=["darkseal","gatedoom","darksealj"], data="02" }`.
   - Region map for darkseal (names mostly match cninja; note `sprites` not
     `sprites1`, no `proms`):
     ```
     maincpu  0x80000  16-bit byte (ga_04-3/ga_01-3 @0, ga_00/ga_05 @0x40000)
     audiocpu 0x10000  -> snd BRAM (audiocpu:snd)
     chars    0x20000  16-bit byte (fz_02/fz_03)        4bpp RGN_FRAC(1,2)
     tiles1   0x80000  single (mac-03)
     tiles2   0x80000  single (mac-02)
     sprites  0x100000 RGN_FRAC(1,2) (mac-00@0 + mac-01@0x80000)
     oki1     0x20000  (fz_08)
     oki2     0x20000  (fz_07)
     ```
   - The plane order for chars/tiles/sprites is the SAME `{8,0,FRAC+8,FRAC}` as
     cninja → the existing game.v download plane-rotate applies unchanged.
   - **Verify:** `jtframe mra cninja` (cninja MRA unchanged) + `jtframe mra
     cninja --setname darkseal` (darkseal blob assembles) + `lint-mra`. If
     cninja regen changes, STOP — the second machine leaked into cninja.

2. **mem.yaml / macros.def**: only if D2 = per-game. Otherwise the existing
   bank layout (sprites BA0/BA1, main BA2, gfx BA3, snd BRAM) already fits
   darkseal (1 MB sprites, 512 kB main, ~1.1 MB gfx, 64 kB snd) — darkseal is
   SMALLER than cninja in every region, so a shared layout just pads.

### Step B — sound (near-zero work; verify only)

- `jtcninja_snd.v` is unchanged: identical map + chips. The one risk is the
  H6280 cen (darkseal specs XTAL/4 + timer_scale 2 vs the current ~4 MHz gate).
  Wire it, sim, and diff the sound CPU PC stream against a darkseal MAME sound
  trace (capture one like the master trace). Adjust `hu_cen` only if it diverges.

### Step C — main address decoder (game_id mux) — THE core work

In `jtcninja_main.v`, select the decode by `game_id` (pass it in from game.v).
Dark Seal decode (active when game_id==2):
```
rom_cs     A[23:16] < 0x08              (512 kB, vs cninja <0x0c)
ramdec     A[23:16]==0x10 & A[15:14]==00 (0x100000-0x103fff work RAM, BRAM)
objram_cs  A[23:16]==0x12 & ...          (0x120000-0x1207ff)
pal_cs     A[23:16]==0x14 & ~A[12]       (0x140000 RG)
palext_cs  A[23:16]==0x14 &  A[12]       (0x141000 B-ext)  <-- NEW signal
dsw/p1p2/sys reads 0x180000/2/4         (DIRECT, no deco104)
obj_copy   write 0x180006
snd_latch  write 0x180008
irq_ack    write 0x18000a
pf1_cs(t1) 0x200000-0x203fff, ctrl 0x240000 ; rowscroll 0x220000/0x222000
pf0_cs(t0) 0x260000-0x263fff, ctrl 0x2a0000
```
- IRQ: darkseal is a single vblank IRQ (level 6) + ack at 0x18000a — much simpler
  than cninja's deco_irq raster block. Mux the IRQ logic on game_id.
- Inputs: route P1_P2/SYSTEM/DSW straight to the bus (bypass jtcninja_deco104).
- **Validation:** add/keep the SIMULATION PC dumper; diff against
  DARKSEAL_BOOT_TRACE.md gates 1-3 (work-RAM clear 0x100000-0x104000, tilegen
  control 0x2a0000/0x240000, sprite-RAM clear 0x120000-0x120800).

### Step D — palette (per D1)

- Add the B-ext BRAM (0x141000) and a colmix path that assembles
  `{R[7:0],G[7:0],B[7:0]}` (24-bit) when game_id==2. JTFRAME_COLORW stays 8.
- cninja's RGBx_444 path is untouched.

### Step E — tilemaps / sprites

- 2x DECO16IC again; tilegen[0] is 64x64 (double-height) vs tilegen[1] 64x32.
  Reuse the cninja deco16ic tile engine; feed the darkseal pf sizes + the
  render order (pf1[t1] back ... sprites ... pf2[t0] front, see HW doc §5).
- Sprites: decospr, 1 MB RGN_FRAC(1,2) → the BA0/BA1 parallel-fetch + the
  download plane-rotate reuse directly.

### Step F — bring-up loop

Per AGENTS.md stage 2: scaffold → PC dumper → sim → diff vs the boot trace →
iterate to the three gates → first frame → tilemap → sprites → sound → pixel
exact. Scene-replay harness (`tools/scenesim/`) once OBJ-RAM has content.

---

## What is already done

- MAME driver mirrored (`doc/darkseal.cpp`), boot trace captured + annotated,
  full hardware spec + per-block deltas vs cninja (this folder).
- Sound + gfx-decode reuse paths identified (minimal work).
- The header/game_id infra already exists in game.v (latched, `reg [3:0] game_id`).
- **D1a + D2b chosen** (separate Dark Seal palette module; shared common bank
  layout — Dark Seal pads into cninja's existing banks, so mem.yaml/macros.def
  stay untouched).
- **Step A config foundation DONE & verified (lint-mra PASS):**
  - `doc/custom.xml`: darkseal machine block added (extracted from MAME 0.276
    `-listxml darkseal`; 13 ROMs + DIPs + inputs).
  - `mame2mra.toml`: `darkseal.cpp` added to sourcefile + machines; header
    `data` maps darkseal/gatedoom sets to game_id `02`.
  - cninja MRA is byte-identical by construction (its regions/order/header
    entry are untouched); the boot-critical `maincpu`/`audiocpu` regions ride
    the shared cninja config (same names, same D2b bank starts) so Dark Seal's
    68k ROM + sound BRAM assemble correctly for the first sim milestone.

## CRITICAL HDL NOTE — the MRA header is BYTE-addressed in the game module

When latching header bytes in `jtcninja_game.v` (game_id, gfx bounds, future
per-game config), the header phase feeds the game (game_sdram.v lines 260-263,
`pass_io = header`):
- `prog_addr = ioctl_addr` -> a **byte index** (0,1,2,3,4...), one byte each.
- `prog_data = ioctl_dout`  -> the byte in **`[7:0]`**; `[15:8]` is zero-extended.

So read EACH header byte at its own `prog_addr[3:0]` from `prog_data[5:0]` (or
`[7:0]`). Do NOT pack two bytes per 16-bit word (`prog_data[13:8]` is always 0).
This bit me once: a word-packed parse latched `gfx_t1=0/gfx_end=0` for darkseal,
collapsing the tiles2 remap and turning the smooth marble blocky. The
`mame2mra` `[header] data="g t1 t2 end rc"` byte order maps 1:1 to the
`prog_addr[3:0]` case in the latch.

## CRITICAL TOOLING NOTE — MAME snapshot byte order is BGRA, not RGBA

A whole "red marble vs blue marble" colour investigation was wasted on a
**snapshot conversion bug, not an HDL bug**. `screen:pixels()` in MAME Lua
returns the `bitmap_rgb32` buffer as little-endian ARGB8888 — i.e. the raw
byte stream per pixel is **B, G, R, A**. Converting it with
`ffmpeg -pix_fmt rgba` swaps R<->B, so a RED screen renders BLUE in the PNG.

- **Always use `-pix_fmt bgra`** when converting a raw `screen:pixels()` dump.
- For per-pixel reads, `screen:pixel(x,y)` returns a uint32 0xAARRGGBB, so
  `r=(p>>16)&0xff, g=(p>>8)&0xff, b=p&0xff` (no swap needed).
- The committed `tools/scenesim/` harness is FINE — it grades against MAME's
  own `screen.png` snapshot (written correctly by MAME), not a raw rgba dump.

**Conclusion: Dark Seal's intro marble is RED in MAME too.** The FPGA's red
marble is colour-correct; there was never a palette/RGB-order bug. Verified
by reading MAME output pixels directly: `screen(128,60) = R=c3 G=00 B=00`.

## Dark Seal video layer map (from darkseal.cpp, frame ~195 intro)

GFXDECODE colorbases: chars=0x000, tiles1=0x300(768), tiles2=0x400(1024),
sprites=0x100(256). deco16ic tilegen bank assignment:
- **tilegen[1]** (DECO_64x32, `16x16_bank=2` -> tiles2 gfx, **colorbase 0x400**)
- **tilegen[0]** (DECO_64x64, `16x16_bank=1` -> tiles1 gfx, **colorbase 0x300**)

Draw order (screen_update, back -> front):
`t1g1 pf1, t1g1 pf2, t1g0 pf1, sprites(buf 0x400), t1g0 pf2`.

At the intro (frame 195) the nonzero tilemaps are:
- `t1g1 pf2` @0x202000: 768 tiles, all pal-nibble 0 -> pen 0x400-0x40f = **RED
  marble** (the full-screen background). `t1g1 pf1` @0x200000 is all-zero.
- `t1g0 pf2` @0x262000: 560 tiles, all pal-nibble 9 -> pen 0x390-0x39f =
  brown/orange (the "In the Kingdom of Etrulia..." intro text/decoration).
  `t1g0 pf1` @0x260000 is all-zero.

## NEXT (real, open) video work — NOT colour

The marble colour is correct, but the FPGA render still differs from MAME:
1. FPGA marble is blocky / vertically banded vs MAME's smooth marble texture
   (suspect tile addressing / scroll / half-fetch ordering in jtcninja_pf for
   the 64x32 tilegen[1] path — grade with a scenesim diff, do NOT eyeball).
2. The t1g0 pf2 intro-text layer (pen 0x390) is not visibly rendering — verify
   the FPGA renders BOTH tilegens' pf2 with the right colorbase + draw order.
Use `-pix_fmt bgra` for any MAME reference capture from here on.

## STATUS — CPU spine DONE (game_id=2), video is next

**Working (committed 3da884934):** Dark Seal's 68000 boots fully. FPGA PC trace
== MAME boot trace one-for-one; level-6 vblank IRQ fires + acks every frame; CPU
writes palette/tilegen/sprite RAM (pal~7700, tile~26000, obj=2048 per run).
Two fixes: (1) game_id address-decoder/IRQ/input mux in jtcninja_main.v;
(2) **maincpu D1<->D6 data-line descramble** in the game.v download (MAME's
driver_init: `rom=(rom&0xbd)|((rom&2)<<5)|((rom&0x40)>>5)` — without it the CPU
ran the raw scrambled ROM as garbage and crashed into the 0x4400 data tables).

**Screen still black** — the CPU's writes land in the video RAMs but jtcninja_video.v
reads them with cninja's addressing. The remaining VIDEO milestone:

1. **Pass game_id + wider cpu_addr to video.v** (currently only [15:1]; darkseal
   tilegens need A[19:16] to tell 0x20/0x24/0x26/0x2a apart — widen to [19:1]).
2. **Palette (D1a)** — darkseal is split: GR @0x140000, B @0x141000 (2048 each),
   read in parallel; assemble {G,R,B} 24-bit. cninja's is interleaved 2-words/colour.
3. **Tilegen decode** — darkseal data/control/rowscroll are exploded across the
   map (t1 0x20/0x22/0x24, t0 0x26/0x2a) vs cninja's packed 64kB window. Decode
   t0p1/t0p2/t1p1/t1p2/ctrl0/ctrl1 from A[19:16]+A[15:13] when game_id==2.
4. **colmix** — darkseal render order (pf1[t1] back .. sprites .. pf2[t0] front,
   see HW doc §5) + colour bases (chars 0, tiles1 768, tiles2 1024, sprites 256).
5. **gfx ROM** — darkseal chars/tiles in BA3 currently get cninja's download
   remap (ROM_CONTINUE/rotate) which is WRONG for darkseal's single-ROM tiles;
   mux the bank-3 remap on game_id, and add darkseal gfx region config in mame2mra.

This is a full video bring-up (several sim iterations). The hard
reverse-engineering (the descramble) is done; the rest is mechanical addressing.

## Sim pipeline validated (Step A end-to-end)

`ROMS_HOST=~/.mame/roms-local ./sim-core.sh cninja darkseal` runs clean: the
darkseal ROM blob assembles + loads and the 68000 executes **real darkseal
code** (heartbeat PC ~0x4408-0x4e38, not 0xFF garbage → maincpu is placed
correctly). It then diverges (pal=0/tile=0/obj=0, never reaches video init)
because the decoder still applies cninja's map, so darkseal's work RAM
(0x100000) / control (0x180000) mis-decode and the CPU loops. **This is the
expected pre-decoder baseline** — the next session wires the game_id==2 decode
(Step C) and diffs the PC stream against the DARKSEAL_BOOT_TRACE.md gates from
here. The sim pipeline is ready; no infra work needed.

## What is NOT done (needs the user / a focused session)

- **Dark Seal sprite region** — `sprites` (1 MB RGN_FRAC(1,2)) currently gets a
  default placement (lint warns "unlisted region for sorting sprites"). Needs a
  darkseal-qualified region that splits mac-00 (planes 0,1) → BA0 @ blob 0 and
  mac-01 (planes 2,3) → BA1 @ `JTFRAME_BA1_START` (the 512 kB plane-pairs must
  straddle the bank boundary, so planes 0,1 pad from 512 kB to 1 MB). Not on the
  boot path — wire it at the sprite stage.
- **gfx region check** — chars/tiles1/tiles2 ride cninja's shared config; verify
  the tiles2 ROM_CONTINUE handling (cninja-specific) doesn't misapply to
  darkseal's single-ROM tiles2 once the tilemap stage starts.
- **buttons/audio MRA metadata** for darkseal (cosmetic).
- All HDL muxing (steps C-E) — these edit the shared cninja main/video/colmix
  and must be sim-verified per gate so cninja does not regress.
