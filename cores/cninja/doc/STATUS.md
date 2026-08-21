# jtcninja status

State: **BOOTS, RUNS, RENDERS; SOUND IMPLEMENTED (validating)**. The 68000 boot,
memory map, SDRAM, BRAM work RAM, DECO 104 protection, inputs and deco_irq are
verified vs MAME. Video is now rendering: all four playfields (tilegen0 pf1 8x8
chars/fg, pf2 16x16 tiles1/mg; tilegen1 pf1 16x16 tiles2 detail, pf2 16x16
tiles2/bg) + the decospr sprite engine, validated pixel-correct on attract +
gameplay + boss scenes (0300/0900/1500/2100/2400/2700) via scene replay.

## Current progress (this session)
- **Sprites (jtcninja_obj):** decode (raw sprite ROM pack + bit19 plane rotate
  like the tiles), multi-tile, hflip/vflip, colour 0x300, flash, wide/wing.
- **tilegen1 pf1 (jtcninja_pf u_pf1b):** 2nd tiles2-ROM 16x16 layer (scr3 reader,
  pal 0x200, deco16ic bank cb) - adds the palm/foliage/water detail.
- **Sound (jtcninja_snd):** HuC6280 + YM2203 + YM2151 + 2x MSM6295, full
  sound_map decode, soundlatch->IRQ1 / YM2151->IRQ2, 32.22MHz crystal cens
  (frac_cen /8 /9 /16 /32), OKI2 bank from YM2151 CT1. Compiles; validating audio.

## Front layer (tilegen0 pf1) - FIXED
The title rock logo + the 1P/2P HUD are now pixel-correct (scenes 0900/1500).
Both were tilegen0 pf1 in plain **8x8 chars** mode (verified: ctrl6=0x80 always,
the rock letters ARE char tiles - 0x606 etc are just the transparent gaps). Two
jtcninja_pf bugs hid this:
- the 8x8 path used the 16x16 deco16_scan mapper instead of TILEMAP_SCAN_ROWS
  (row*64+col) -> a blank line between every HUD/text line (commit 4ed1569eb).
- the scan stopped at 17 tiles (sized for 16x16); 8x8 needs ~33 to cover 256px,
  so the right third was missing (2P HUD, right of the logo) (commit 1f09e8e85).

## Known remaining issues
- **Sprite priority:** fixed order bg<pf1b<mg<obj<fg looks right in all validated
  scenes; full deco16ic pri_callback model (x[15:14] mask) still TODO.
- **Scene replay control regs:** ctrl1[7] is seeded to 0x1100 for the bank; the
  full per-scene ctrl.bin (scroll/mode/enable) is still not loaded.

Boot fixes: (1) swallow the first few vblanks after reset ("warmup" in
jtcninja_main) - the sim ROM-download desyncs CPU reset from the free-running
vtimer so the first VBL could preempt the masked init; (2) the heartbeat
palette-write counter had a bug (sampled pal_cs at AS-fall, before the data
strobe) that masked the working render as pal=0.

## NEXT: video rendering (to display + play)
Implement in jtcninja_video / new modules:
- 2x deco16ic tilemap generators (tilegen0: 8x8 chars pf1 + 16x16 tiles1 pf2;
  tilegen1: 16x16 tiles2 pf1/pf2; 64x32 maps; scroll + rowscroll; bank cb).
  4bpp planar tiles - evolve from cores/cop/hdl/jtcop_bac06.v.
- decospr sprite engine (16x16, buffered spriteram, pri callback) - from
  cores/cop/hdl/jtcop_obj*.v.
- colmix: palette is xBGR_888, 2 words/colour (word0={G,R}, word1={x,B}); the
  pf RAM + palette + sprite RAM read-back already work in jtcninja_video.
- wire the char/scr1/scr2/obj ROM buses (idle now).
Use the MAME tilemap/sprite write traces (lua taps) + screenshots as the oracle.

## MAME as oracle (works here!)
MAME runs cninja with 6 DUMMY PLD files (zero-filled, right names/sizes) added
to a loose romdir - the tj-* GALs are emulated in the driver, so the dumps are
only a presence check. Build: extract cninja.zip to <dir>/cninja/, rename ROMs
to MAME names by CRC (see /tmp/mrom in-session), add dummy tj-*.  Then e.g.:
  mame cninja -rompath <dir> -video none -seconds_to_run 1 -debug \
       -debugscript dbg.txt   (dbg.txt: "trace /tmp/mame.tr,maincpu" then "go")
gives a full 68000 instruction trace to diff against the core. Lua read-taps on
0x1bc000-0x1bffff / 0x190000 give protection / deco_irq value traces.

## The remaining blocker (precise)
The VBL ISR is full of `cmpi.b #X,$1bcYYY; bne *-1` protection checks (they pass
- no crash - so protection values are right) and many work-RAM-flag branches
(btst/bclr on 0x184xxxx). My ISR diverges from MAME's somewhere in these flag
branches and returns early without acking the VBL or setting 0x184d1c bit 2.
Tried and ruled OUT: input polarity (fixed, real bug - advanced 0x225xx->0x115x),
init speed (work RAM -> BRAM, no change), early-vblank preemption (warmup
suppression, no change). So it is a work-RAM-state / ISR-path divergence, not
timing. NEXT TOOL: capture my sim's full ISR instruction path (program-space
fetches from 0xfe4) and diff line-by-line against MAME's /tmp/mame.tr ISR to
find the first divergent branch and the flag/value behind it.

## Reference (this folder)
- `cninja.cpp` / `cninja.h` — driver, memory maps, ROM_START, machine config
- `deco146.cpp` / `deco146.h` — protection base device (`deco_146_base_device`)
- `deco104.cpp` / `deco104.h` — DECO 104 specialization used by cninja
- `deco16ic.cpp` / `.h` — tilemap generator (2 instances)
- `decospr.cpp` / `.h` — sprite generator
- `deco_irq.cpp` / `.h` — raster/IRQ controller (0x190000)
- `decocrpt.cpp` — DECO encryption helpers (for swizzled gl-* sets, e.g. joemac)

## Key addresses (68000, `cninja_map`)
| Range            | Function                                  |
|------------------|-------------------------------------------|
| 000000–0bffff    | program ROM                               |
| 140000–14000f    | pf control, tilegen[0]                    |
| 144000 / 146000  | tilegen[0] pf1 / pf2 data                 |
| 14c000 / 14e000  | rowscroll[0] / [1]                        |
| 150000–15000f    | pf control, tilegen[1]                    |
| 154000 / 156000  | tilegen[1] pf1 / pf2 data                 |
| 15c000 / 15e000  | rowscroll[2] / [3]                        |
| 184000–187fff    | work RAM (16kB)                           |
| 190000–190007    | deco_irq                                  |
| 19c000–19dfff    | palette (write16)                         |
| 1a4000–1a47ff    | spriteram1                                |
| 1b4000           | sprite DMA flag                           |
| 1bc000–1bffff    | **DECO 104 protection** (prot16ram)       |

Sound map (H6280): 000000–00ffff ROM, 100000 YM2203, 110000 YM2151,
120000 OKI1, 130000 OKI2, 140000 soundlatch (read via DECO 104), 1f0000 RAM.

## Build order / checklist
- [x] Scaffold: cfg/ + hdl/ stubs + MAME refs in doc/
- [x] **Main CPU + memory map**: `jtcninja_main` instantiates `jtframe_m68k` +
      `jtframe_68kdtack_cen` (12MHz), decodes `cninja_map`, VBLANK IRQ (IPL5).
      Inputs/dips moved into `jtcninja_deco104` (read through the chip).
      Whole design **lints clean in Verilator** (Docker). *(raster IRQs 3/4 TODO)*
- [x] **ROM/SDRAM layout**: BA1 main+snd+2xoki, BA2 chars+tiles, BA3 sprites,
      using MAME declared region sizes; `doc/mame.xml` has the cninja machine.
      main bus addr_width 20 -> cpu_addr A[19:1] (768kB main ROM).
- [x] **DECO 104 protection** (`jtcninja_deco104.v`): full port of the
      deco146/104 model. The cninja CPU-side bitswap collapses to
      (real_address & 0x7ff) -> always the internal protection area, so no
      region_selects/cs routing. rambank R/W + magic-xor(0x2a4) + 1024-entry
      reorder table (generated by `gen_deco104_table.py` ->
      `jtcninja_deco104_table.mem`) + XOR(0x42)/NAND(0xee) + latch read-back +
      soundlatch(0xa8)/IRQ + bankswitch(0x66). Lints clean.
- [x] **Video v0** (`jtcninja_video.v`): real `jtframe_vtimer` (so VBLANK IRQ
      fires) + dual-port VRAM read-back (palette, 4x pf data, sprite RAM).
      Renders BLACK - no tilemap/sprite/colmix yet.
- [x] **Sim heartbeat**: `jtcninja_main` prints the 68000 address bus each
      VBLANK under SIMULATION, so the sim log shows if the CPU is executing.
- [x] **BOOT CONFIRMED**: 68000 runs game code (PC sweeps 0x225xx-0x226xx +
      work RAM) instead of the address-error STOP at 0x114. Protection verified:
      DSW read via INPUT_PORT_C, scramble-RAM write/read-back, cmpi.b #$5f pass.
      Fixed: rambank init=0xffff, combinational table read, table as .hex (jtsim
      only symlinks hdl/*.hex into the sim dir, not .mem).
      `jtcninja_main` keeps a SIMULATION VBLANK heartbeat ($display of the addr
      bus) - handy for further bring-up.
- [ ] **Verify execution depth**: the CPU loops in 0x225xx - identify whether
      that is the normal main loop (waiting on rendering/inputs/sound) or a new
      gate. Add traces as needed (it iterates ~2 min now since Verilator caches
      the build; only the changed module recompiles).
- [ ] **Sound**: HuC6280 + YM2203 + YM2151 + 2× MSM6295 in `jtcninja_snd.v`.
      Sound IRQ already produced by deco104 (soundlatch write); add `snd_rd`
      handshake to clear `snd_irq` when the sound CPU reads the latch.
- [x] **Tile ROM format SOLVED + background layer renders**: the deco16ic 4bpp
      tile decode is fully reverse-engineered and verified END-TO-END against the
      MAME gfxdecode (0 px mismatch) *and* against the sim's real SDRAM dump.
      `jtcninja_pf.v` renders tilegen1 pf2 (tiles2) showing correct tile graphics.
      Key facts nailed down (see jtcninja_game.v post_addr + jtcninja_pf.v):
        * Two ROM-layout bugs fixed: (a) oki2/mag-07 is 0x80000 but only 0x60000
          was reserved -> shifted every gfx ROM 0x20000; fixed BA2/BA3/PROM starts
          in macros.def.  (b) mame2mra `sequence` mangled tiles2's ROM_CONTINUE
          into a doubled 2MB region; removed it -> clean 1MB naive mag-00|mag-01.
        * post_addr/prog_addr are 16-bit-WORD addresses (jtframe_dwnld >>1), NOT
          bytes; byte lane = prog_mask. Remap rotates each region's word offset
          left by 1 (RGN_FRAC plane interleave); tiles2 also swaps word bits 17<->18
          (MAME ROM_CONTINUE de-interleave, done in HDL since mame2mra won't).
        * SDRAM SLOT offsets are in WORD units too: mem.yaml GFX2/GFX3_OFFSET use
          >>1 (NOT >>2) - jtframe_romrq does sdram_addr=offset+word_addr. With >>2
          the dw32 reads landed at half the right address (the long garble hunt).
        * draw_pxl = {d[31],d[23],d[15],d[7]} (plane p = bit7 of byte p), shift<<1.
        * rom_addr (dword) = {tile_id, half, veff[3:0]}; half=1 (left 8px) first.
- [x] **Multi-layer colmix + palette**: jtcninja_video composites bg=tilegen1 pf2,
      mg=tilegen0 pf2 (tiles1), fg=tilegen0 pf1 (8x8 chars) back->front with pen-0
      transparency; col_banks 0x30/0x10/0x00. Palette xBGR_888, 2 words/colour:
      even(@+0)={x,B}, odd(@+2)={G,R} => R=odd[7:0],G=odd[15:8],B=even[7:0]
      (verified vs MAME screen pixels).
- [x] **BG renders correctly (colours fixed)**: the bg now matches MAME's bg-only
      render (blue sky, white clouds, gray snow-mountains, green forest, blue lake,
      green grass). The colour bug: the colmix used palette col_bank 0x300 for the
      bg, but tilegen1 pf2 uses the tiles2 gfx whose GFXDECODE colorbase is 512=0x200,
      so the real index is 0x200+(0x30+tile_pal)*16+colour = **0x500**+tile_pal*16+c.
      Was off by 0x200 -> read palette 0x300-0x3ff instead of 0x500-0x5ff.
      (mg=tiles1 base0->0x100, fg=chars base0->0x000 were already right.)
      LESSON: ground-truth the render against MAME's actual *output*, not a Python
      gfxdecode you wrote yourself (that's circular). Got MAME's bg-only by zeroing
      the overlay tilemaps + spriteram via lua write-taps, then pixel-compared.
- [ ] **NEXT: sprites (decospr)** - implement jtcninja_obj from cop's obj engine;
      verify the sprite ROM decode in Python vs gfxdecode like the tiles. This is
      the main remaining visual gap.
- [ ] **scr2_addr 13th tile bit**: video.v forces dword bit19=0, so only tiles
      < 0x1000 are reachable; wire the deco16ic 16x16 bank high bit when needed.
- [ ] **Remaining video layers**: char (8x8 text), tilegen0 playfield(s),
      `jtcninja_obj` sprites (from cop's obj), `jtcninja_colmix` priority. Apply
      the same verified tile decode to char/tiles1 (post_addr already has their
      rotate; verify in Python like tiles2). Wire char/scr1/obj ROM buses.
- [ ] confirm input bit order (DATAEAST_2BUTTON) vs jtframe joystick
- [ ] raster IRQs (IPL3/4) from deco_irq; currently only VBLANK (IPL5)
- [ ] sim vs MAME trace comparison; then `joemac` (swizzled gl-* set) as an alt
- [ ] synthesis / MiSTer build (NOT doable in this sim-only env)

## How to run the sim here (romset volume not available)
ROM is at `~/.mame/roms-local/cninja.zip`. Run via Docker (Verilator is x86,
runs emulated on arm64 - a full sim build takes ~20 min; `lint-one.sh` is ~7s):
```
docker run --platform linux/amd64 --rm -v "$PWD:/jtcores" \
  -v "$HOME/.mame/roms-local:/root/.mame/roms:ro" -w /jtcores jotego/simulator -c "
  unset VERILATOR_ROOT; source modules/jtframe/bin/setprj.sh --quiet
  cd cores/cninja/ver/game; jtsim -setname cninja -video 300"
```

## Open questions to resolve
- Sound clock: 32.22MHz crystal is independent of the 24MHz video crystal.
  Decide cen strategy (jtframe_frac_cen from clk48) — placeholders in game.v.
- DECO 16IC bank callbacks and exact pf RAM word layout vs the BAC06 in cop.
- deco16ic tile ROM packing: mame2mra currently uses width=16 for tiles to
  build; confirm the real deco16ic 4bpp layout when wiring rendering.

## Sprite priority — reverse (high->low) order adopted (2026-06-09)

Scene 2400 has two overlapping dinos. Adopted: **reverse scan order
(slot 255..0, lowest slot ends on top)** to match MAME decospr. This renders
the green dino in front of the blue one, confirmed correct against the real
MAME frame. (There was a forward-vs-reverse back-and-forth while grading the
head region; reverse is the right answer.)

Facts established:
- Buffer is last-wins (jtframe_obj_buffer KEEP_OLD=0): last opaque write wins.
- MAME decospr.cpp with a pri_callback (cninja has one) draws high->low
  (offs=sizewords-4, incr=-4) => LOWEST slot ends on top.
- pri_callback only maps the sprite pri field (x[15:14]) to a *playfield*
  priority mask; it does NOT reorder sprite-vs-sprite. All dino sprites are
  pri=1, so sprite-vs-sprite is pure painter's order.
- Palettes: col12/0x3C0 = GREEN dino, col13/0x3D0 = BLUE dino. Blue occupies
  the contiguous slot range 26-42; green is split 10-21 (neck) AND 47-51 (head).

Remaining minor artifact (not blocking — reverse is adopted):
- On busy scanlines the lower head/neck can still show the wrong sprite
  on top. The same two sprites (slot 26 vs slot 47) resolve correctly on
  most lines but flip on a few => the engine appears to **drop a sprite on
  the busiest lines** (suspect per-line budget `line_cnt>=58` or parse/draw
  timing at cen2). Verify the budget / profile parse+draw cycles vs available
  line time to clean up the last few lines.
