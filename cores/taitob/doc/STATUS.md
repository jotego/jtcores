# taitob — STATUS

## Current video state (May 2026)

Graded with the `tools/scenesim/` harness against 5 MAME scenes
(`m00300` TAITO logo, `m00540` NASTAR title, `m00840`, `m00900`,
`m02100` gameplay). Canonical verification = **sim all 5 → build PNG
diffs**, never a single-scene spot check.

**Done & verified:**
- **gfx_sort=hvvvx** on the gfx region (`mem.yaml`, on the `tx` bus) +
  matching `gsort()` address swap in `jttaitob_video.v`. Rotates the
  tile L/R-half bit to the LSB so a tile-row's halves are adjacent →
  SDRAM read-cache hits. BG fill **1300→279 clk** (sdram_wait 1144→103),
  fits HBLANK with ~4× margin. Decode unchanged.
- **BG plane** renders via the `jttaitob_shifter` ring, pixel-aligned to
  MAME (all 5 scenes best-fit offset `(0,0)`).
- **BG vertical 1px-down fixed** by *latching* the fill line (`vrender`)
  at `bg_fill_kick`: gfx_sort shrank the fill into HBLANK where it
  straddles the `vdump` increment (HS_START=340), so a combinational
  `vrender`/`vdump` flipped row mid-fill. Frozen line = uniform.
- **1-2px black left edge fixed**: dropped the redundant `!LHBL/!LVBL`
  gate on `pal_idx` (colmix already blanks RGB) and clamped the BG tap's
  `hdump` to 0 during HBLANK so the read-out is primed for `hdump 0`.
  - *Residual (noted, deferred):* a very rare 1px on a few center lines
    still appears; suspected unrelated to the edge priming. Not chased.

- **FG plane** converted to the BG-style `jttaitob_shifter` ring
  (HBLANK prefetch + `tap = hdump − fg_scrollx + 1`), deleting the
  per-slice band-aids. Fixes the m00900 `mod 8` FG fine-scroll and the
  m00540 sword misalignment.
- **TX plane** converted to a ring the same way (8×8 tiles, no scroll,
  `tap = hdump + 1`).
- **Sprites (Phase 3d-a.1) — real 16×16 gfx, unscaled, single-tile.**
  `jttaitob_obj.v` scans the 408-slot list per scanline, fetches the
  gfx row off the `obj` bus during ACTIVE (gsort'd, burst-cached, while
  the rings read decoded pixels from BRAM so the bus is otherwise idle),
  decodes 16 pens with flipX/flipY, writes to a `jtframe_obj_buffer`
  line buffer. **m00840 warrior is pixel-exact vs MAME (100% over the
  sprite bbox); m00900/m02100 sprites best-fit `(0,0)`.** Three bugs
  found & fixed: (1) sprite palette base is **`fb_color_base 0x400`**
  (`set_fb_colorbase(0x40)` ⇒ `m_fb_color_base = 0x400`), not 0 — final
  index = `0x400 + color*16 + pen`; (2) the right-half planes-2/3 word
  **`w23r` must be latched** (it was read live off `gfx_data` after
  `gfx_cs` dropped, so the right 8px of every tile decoded from stale
  bus data); (3) the line buffer's `rd_data` is registered on `pxl_cen`
  (1px latency like the rings) so it must be read **one column ahead**
  (`rd_addr = hdump + 1`).

**Still open:**
- **Big sprites (3d-b)** — multi-tile figures via word+5 `x_num/y_num`
  with latched x/y stepping (`xlatch + x_no*16` etc.). nastar's warrior
  is *not* a big sprite (each tile is an independent slot), so 3d-a
  already covers it; needed for games that do use big sprites.
- **Zoom (3d-c)** — replicate MAME's buggy 16px-chunked scaling.
- **Priority Mode 0 (3d-d)** — obj0/obj1 split by color bit 0.
- **TX text doubling** — "1UP"→"11PP"; spatial addressing, suspected
  TX look-ahead amount. Still present in the scene diffs.

Bank wiring note: MAME's `ctrl_w` **code** uses `ctrl[0]→FG, ctrl[1]→BG`
(its *comment* says the opposite — stale). The HDL matches the code; do
not "fix" it to the comment.

---

**Phase**: A (bootstrap) — Rastan Saga 2 / Nastar.

## What runs

- `cfg/` files lint-target the four-set Phase A scope (rastsag2 + nastar
  + nastarw via mame2mra; tetrist excluded — different memory map).
- The HDL graph **should** elaborate (lint not yet run as of this commit).
- 68k spine is wired with the rastsag2_map decoder (taito_b.cpp:369).
- Z80 + YM2610 + TC0140SYT cloned from Superman; ADPCM-A wired,
  ADPCM-B silent.
- TC0220IOC stub returns DIPs and cabinet inputs; coin counter is a
  dead-end latch.
- Video output is the **palette viewer** stub — whatever the 68k writes
  to palette RAM at 0x200000-0x201FFF shows as a 32×128 grid.

## TC0180VCU bring-up status

| Phase | Block                                    | Status  | Commit       |
|-------|------------------------------------------|---------|--------------|
| 1     | ctrl reg file + BG tile addressing       | done    | `e19bfbed1`  |
| 2a    | SDRAM bg bus + 8-pixel batch fetch       | done    | `c20b0db4e`  |
| 2b    | Pre-fetch + double-buffer                | done    | `76af1901c`  |
| 2c    | flipX/Y per BG attr                      | done    | `83dba1a46`  |
| 3a    | FG plane (transparent pen 0, over BG)    | done    | `9e6d55775`  |
| 3b    | TX plane (8x8 tiles)                     | done    | `541c502a8`  |
| 3c    | Per-frame scroll (BG/FG)                 | done    | `eacf6d32c`  |
| 3d    | Sprite engine with zoom                  | planned | see PHASE3D_PLAN.md |
| 4     | ctrl[7] decode (priority/flip)           | partial | `dd79514e3`  |

Per-line scrolling (lines_per_block < 256) and flip-transformation of
the look-ahead position are partial in Phase 3c/4 — code-wired but not
exercised by the rastsag2 boot path that we sim against.
- Only IRQ 4 (vblank) fires; the real VCU drives both IRQ 4 (`inth`)
  and IRQ 2 (`intl`) — IRQ 2 ISR sets a flag the IRQ 4 ISR checks
  (taito_b.cpp:44). May matter for some games.
- ADPCM-B voice samples don't play.
- Framebuffer region (0x440000-0x47FFFF, used by Hit The Ice and
  Realpunc) is a black hole — fine for Rastan 2, not for hitice.

## Per-file source-of-truth pointers

| File                       | MAME ref                                            |
|----------------------------|-----------------------------------------------------|
| `hdl/jttaitob_main.v`      | taito_b.cpp:369 `rastsag2_map`                      |
| `hdl/jttaitob_snd.v`       | taito_b.cpp:1859 `rastsag2()` machine_config        |
| `hdl/jttaitob_syt.v`       | shared/taitosnd.cpp (TC0140SYT device)              |
| `hdl/jttaitob_ioc.v`       | taito/taitoio.cpp:200 (tc0220ioc_device)            |
| `hdl/jttaitob_video.v`     | taito/tc0180vcu.cpp (stub only)                     |
| `hdl/jttaitob_colmix.v`    | taito_b.cpp:1887 `PALETTE(..., RGBx_444, 4096)`     |

## Next steps (in order)

1. ~~**Lint pass**~~ — done; clean against `jotego/linter`.
2. ~~**MAME ground-truth capture**~~ — done. See
   [doc/BOOT_TRACE.md](BOOT_TRACE.md) for annotated landmarks of the
   first ~30 68k and ~20 Z80 instructions, plus 10 numbered
   validation gates the FPGA sim must hit in order. Raw traces are
   under `ver/rastan2/traces/` (gitignored).
3. ~~**CPU spine sim**~~ — **done first try.** 60-frame sim hits all
   six wired 68k-side gates (1, 3, 4, 5, 6, 10) with byte-exact data
   match to MAME. After gate 10 the CPU settles into the ROM-checksum
   loop at 0xBE4 — same place MAME's 1-second reference trace ends.
   See [BOOT_TRACE.md §FPGA sim results](BOOT_TRACE.md). Gates 2
   (SP load) and 7-9 (Z80 side) not wired yet but the 68k boot is
   demonstrably correct through the entire 1.38M-instruction trace.
4. **TC0180VCU bring-up — Phase 1 done.**
   - Full 8×16-bit ctrl-reg file decoded in main.v.
   - BG bank registers extracted (codes page from `ctrl[1][10:8]`,
     attr page from `ctrl[1][14:12]`).
   - VRAM port-B addressing in video.v: `tile_idx = {tile_y, tile_x}`
     concatenated with `bg_bank`.
   - Two-phase fetch alternates between tile-code and tile-attr reads.
   - Attribute palette field (bits 5:0) feeds palette lookup.
   - **Phase 1 finding**: MAME's first 5 seconds of sim show zero
     VRAM/palette writes — the game stays in self-test (PC settles
     into a `jsr/rts/bra` waiting loop at 0x59E). Natural-boot
     visual verification requires either (a) IRQ-2 (`intl`) wiring
     so the game's vblank handler can proceed, or (b) a scene-file
     loader that pre-populates VRAM/palette state at sim start.
     Phase 2 will pick one.

   **Phase 2 (next)**: gfx ROM fetch from SDRAM bank 2 + 4-bpp
   plane decode. Either fix the IRQ-2 wiring to let the game draw,
   or capture a scene from MAME's later state.

   **Phase 3+**: FG plane, text plane, sprite engine with zoom,
   per-line scroll, screen flip, priority mixer, framebuffer.
5. **MRA generation** — `jtframe mra --reduce` against the refreshed
   `doc/mame.xml`; deploy `.rbf` + `.mra` to the MiSTer.
