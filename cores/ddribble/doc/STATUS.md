# ddribble — STATUS

Living status + handoff for the Double Dribble (GX690) core. Schematic-driven
bring-up: the schematic / the 005885 reference Verilog are the source of truth;
MAME is a tie-break only.

## Current state (at pivot commit `6c519fc0a`)

Working and verified in scene-sim:
- **Main/sub/sound CPU spine** boots; POST passes.
- **Tilemap (both 005885 chips)**: text **pixel-exact** vs MAME — scene
  `mame_00300` lit=4426, `mame_00600` lit=6169, corr ~1.0. Per-tile colour,
  bank, hflip/vflip all correct.
- **Tilemap HFLIP off-by-one**: FIXED (`6c519fc0a`) — flip is captured *with*
  the gfx word (`rw_hflip`) so it stays on its own tile.
- **Sprites**: real shapes, correct palette via the sprite LUT PROM; the big
  "garbled / unrelated tiles" bug was a `mem.yaml` `addr_width` truncation of
  RA16 (see [project-ddribble-gfx-addrwidth] memory + fixes_journal). Sprite +
  tilemap are **latency-aligned** at this commit (HB_OPEN=14, no shift register).
- Colour mix via 007327 (`pri = (|g1col[3:0]) & g2col[4]`).

Known issue (the open item):
- **Horizontal scroll is 8px-blocky** (no fine/sub-tile X scroll). Cosmetic —
  game is fully playable. `scroll_x[2:0]` is currently dropped; only the coarse
  tile-index scroll (`scroll_x[8:3]`) is applied.

## Pivot commit — THE FALLBACK POINT

```
6c519fc0a  fix(ddribble): tilemap hflip applied one tile late (off-by-one)
```

**If the active plan below goes wrong, hard-reset the working code to this commit**
(`git checkout 6c519fc0a -- cores/ddribble/hdl/ cores/ddribble/cfg/` — reverts the
RTL + cfg but KEEPS this doc) and execute the *Fallback plan handoff* at the
bottom of this file. At this commit: tilemap text is pixel-exact, sprites correct,
tilemap/sprite latency matched, scroll choppy.

## Active plan: adopt the jtcontra 007121 line-buffer tilemap

> **IMPLEMENTED 2026-06-16 (commit after pivot).** The line-buffer tilemap is in
> `jtddribble_k005885.v` (render FSM + `u_tm_line` double buffer, replacing the
> direct serializer). Verified in scene-sim: FG text **pixel-exact** (300/600,
> corr 1.000, 0 shift), and the FULL gameplay screen (2700) renders correctly —
> crowd, court, players (sprites), ball, UI labels. Gotcha found + fixed: the
> tile CODE byte is at scan **sel=1**, ATTR at **sel=0** (confirmed vs the scene
> VRAM dump — my first cut read them swapped → a screen of "0" glyphs). Remaining:
> all done. **FINE SCROLL VERIFIED** via a sim-only `-d SIM_SCROLLX=N` hook
> (forces the render scroll, scene-sim CPU is stubbed): scroll=4 -> exactly +4px
> in logical 256-space, linear/smooth (buffer write trace: tile1 hr14 -> hr10 =
> 4 cols). The "2x" at first was a red herring: the sim PNG is 512px (2x logical),
> so a raw-PNG SAD doubled it. `old_hcnt2` dropped. The 4566-vs-4426 lit on scene
> 300 is a sub-pixel edge-sampling quirk of the +2 read-latency offset (text is
> visually clean), not a position error. Render + fine scroll + sprites all
> correct => the line-buffer tilemap is FULLY WORKING in sim.

**Chosen direction (2026-06-16): adopt jtcores' existing 007121 line-buffer
tilemap.** The 005885 and 007121 are sibling Konami tilemap+sprite chips, and
jtcores ALREADY ships a JTFRAME-native, Furrtek-grounded 007121 used by 6 cores
(contra, labrun, comsc, flane, castle, mx5k). It is a far better base than Ace's
Iron Horse 005885 RE (which is "what we had, not what we want"). Crucially,
contra drives the **same external 007327 palette** ddribble uses
(`cores/contra/hdl/jtcontra_gfx.v:59 output col_cs`), and its SDRAM `rom_ok`
handshake is already solved.

Reference files (READ THESE):
- `cores/contra/hdl/jtcontra_gfx_tilemap.v` — THE line-buffer tilemap (205 lines).
- `cores/contra/hdl/jtcontra_gfx.v`         — wrapper: MMRs, RAM, color mixer, SDRAM mux, vtimer.
- `cores/contra/hdl/jtcontra_gfx_obj.v`     — sprite engine.
- `cores/contra/doc/007121.pdf`             — Furrtek datasheet.

### Why the line-buffer tilemap is the right fix (the whole point)
jtcontra renders the tilemap to a LINE BUFFER, not a direct serializer. Fine
scroll is applied as the line-buffer WRITE POSITION:
- `jtcontra_gfx_tilemap.v:144` `hrender <= scr_dump_start-1 - {7'd0, scr_hn0[1:0]}` (fine 0..3px)
- `:141` `hn_scr <= scr_hn0` (= hpos, the full scroll; sets the starting tile/half)
- `:166-172` dumps 4px/tile-half into the buffer at `line_addr`(`:96`), hrender++ per px
- read at the DISPLAY position: `jtcontra_gfx.v:159 line_dump={~line,hdump}`, `:553 u_line_scr`
Because render and display are DECOUPLED through the double-buffered line RAM
(`line` toggles on HS, `:128-129`), this (1) applies the full 0..7px fine scroll
cleanly (bit2 via the starting half, bits1:0 via hrender), (2) has NO edge-
priming problem (the line is fully rendered before display), and (3) AUTO-ALIGNS
with sprites (ours are ALREADY a line buffer = jtframe_obj_buffer). That is
exactly why the direct-serializer + BG-shift-register approach could not be made
clean, and why this one is.

### 005885(ddribble) vs 007121(contra) — what we KEEP vs CHANGE
- KEEP ddribble's 5-register decode (`jtddribble_k005885.v:303-327`:
  scroll_y/scroll_x/scroll_ctrl/tile_ctrl/irq+flip). 007121 has 8 MMRs + 32B zure
  (row/col scroll) — do NOT adopt its register map; only the tilemap RENDER changes.
- KEEP the 007327 colmix (`pri=(|g1col[3:0])&g2col[4]`) and the 5-bit COL output.
- KEEP ddribble's working sprite engine + jtframe_obj_buffer (sprite format differs
  from 007121; sprites already render correctly and are already a line buffer).
- VRAM: ddribble's is EXTERNAL (mem.yaml BRAM; the chip's single scan port
  `vram_scn_addr/vram_scn_dout` is time-shared tilemap/sprite via `obj_win` =
  `h_cnt>=272`). jtcontra has separate internal attr/code/obj RAMs. So the ddribble
  tilemap render FSM must use the time-shared scan port during the NON-obj window
  (h_cnt 0..271) and finish the line before obj_win — there is ample time
  (~272 cen * 8 clk for 32 tiles).

### Steps
1. Add a double-buffered tilemap line buffer (jtframe_dual_ram, DW≈5 {sel?,pixel}, AW≈9),
   `line` toggling on the line start (h_cnt wrap), write port = render, read port = display.
2. Replace the direct serializer (`jtddribble_k005885.v` ~495-530) with a render FSM
   modeled on jtcontra_gfx_tilemap st0..7, fed by ddribble's scroll
   ({scroll_ctrl[0],scroll_x} / scroll_y) + VRAM scan (`vram_scn_addr/vram_scn_dout`,
   the existing attr/code read) + gfx fetch (R/RDU/RDL), writing each pixel to the
   line buffer at `hrender` (fine scroll = scroll_x[1:0] + the half via the scan start).
3. `tilemap_px` for COL now reads the line buffer at the display column (h_cnt-HB_OPEN).
4. Verify: scenes 300/600 text pixel-exact, 2700 sprites aligned, full-flow smooth scroll.

Scope note: this is a tilemap-render rewrite only (NOT H/V geometry, NOT the sprite
engine), so the regression surface is the tilemap. Pivot/fallback remains
`6c519fc0a`. If this stalls, the "tilemap + matched sprite delay" handoff below is
still valid from the pivot.

---

## Fallback plan handoff: "tilemap + matched sprite delay" (from pivot `6c519fc0a`)

Self-contained prompt for a future session if the full port is abandoned. Start
by resetting to the pivot commit. This plan keeps the working sprite engine and
adds ONE matched latency — faster, lower risk, one principled pipeline-match
(NOT a fudge offset).

### What this session already proved (don't re-derive)

1. **Serializer port is correct.** Replacing the cen-gated px-3 word latch with
   the reference's `h_cnt[1]`-rising latch + reference mux order renders
   **identical** text (scene 300 corr **1.000**, lit **4426**), shifted **+2px**.
   No thin-text regression. Proven building block:
   ```verilog
   // edge detects (not cen-gated, like the attr/code latches)
   reg  old_hcnt1, old_tcl, old_tsl;
   wire tcl = (h_cnt[2:0] != 3'b001);   // tile_color_latch
   wire tsl = (h_cnt[2:0] != 3'b010);   // tile_shift_latch
   always @(posedge clk) begin
       old_hcnt1 <= h_cnt[1]; old_tcl <= tcl; old_tsl <= tsl;
   end
   // word latched at h_cnt[1] rising (reference RD phase)
   reg [15:0] row_word;
   always @(posedge clk) if(!old_hcnt1 && h_cnt[1]) row_word <= { RDU, RDL };
   // per-tile hflip at tile_color_latch (= the rw_hflip fix, native form)
   reg pixel_hflip;
   always @(posedge clk) if(!old_tcl && tcl) pixel_hflip <= flipscreen ^ tile_hflip;
   wire [1:0] psel = h_cnt[1:0] ^ {2{pixel_hflip}};
   wire [3:0] tile_pixel = psel==2'b00 ? row_word[ 7: 4] :
                           psel==2'b01 ? row_word[ 3: 0] :
                           psel==2'b10 ? row_word[15:12] : row_word[11:8];
   ```
   Also add `row_scroll_lat` to the attr latch (`if(!old_hcnt2 && h_cnt[2])`):
   `reg [2:0] row_scroll_lat; ... row_scroll_lat <= row_scroll[2:0];`

2. **BG shift register = the fine scroll** (k005885_REFERENCE.sv:758-776 /
   furrtek 007121 p25). Proven building block:
   ```verilog
   reg [2:0] tile_shift;
   always @(posedge clk) if(!old_tsl && tsl) tile_shift <= row_scroll_lat;
   reg [31:0] tilemap_shift;
   always @(posedge clk) if(cen_6m) tilemap_shift <= { tile_pixel, tilemap_shift[31:4] };
   reg [3:0] tilemap_px;
   always @(posedge clk) if(cen_6m) case(tile_shift ^ {3{flipscreen}})
       3'd0: tilemap_px <= tilemap_shift[ 3: 0]; 3'd1: tilemap_px <= tilemap_shift[ 7: 4];
       3'd2: tilemap_px <= tilemap_shift[11: 8]; 3'd3: tilemap_px <= tilemap_shift[15:12];
       3'd4: tilemap_px <= tilemap_shift[19:16]; 3'd5: tilemap_px <= tilemap_shift[23:20];
       3'd6: tilemap_px <= tilemap_shift[27:24]; 3'd7: tilemap_px <= tilemap_shift[31:28];
   endcase
   ```

3. **The two problems this creates (both real, measured / from-HDL):**
   - **Total tilemap delay grows ~10px** (+2 serializer, +8 shift register at
     scroll=0 / fine=0 → deepest tap). Sprites (pre-filled line buffer) have ~0
     delay → tilemap lags sprites ~10px (players float off the court tile).
   - **Edge priming**: the 8-px tap reaches into the line-start pipeline RAMP.
     Left ~3 columns show garbage (scene 300 leftmost-8-col stray = **644px**;
     total lit 4426→5070). HB_OPEN=14 opens the visible before the ramp+tap
     settle, and obj_win (`h_cnt>=272`) holds the VRAM at the line end so the
     tilemap can't pre-ramp.

### The faster plan, step by step

A. Apply building blocks 1 + 2 above (serializer + shift register + row_scroll_lat).

B. **Re-derive H geometry for the edge priming.** Give the tilemap pipeline room
   to pre-ramp before the visible + 8-px tap settle: raise `HB_OPEN` (localparam,
   chip ~L260) to ~**22** and push the sprite-scan window `obj_win = h_cnt >=
   9'd278` (chip ~L462) so the visible (HB_OPEN..HB_OPEN+255 = 22..277) no longer
   overlaps it. Verify scene 300 leftmost-8-col stray → ~0 (sweep HB_OPEN 20/22/24,
   pick the one where the left edge is clean AND the bulk corr stays 1.0).
   Re-check the sprite-scan still fits (obj_win 278..383 = 106 cen ≈ 848 clk for
   ≤320 list bytes — plenty) and that `objbuf_lhbl` toggle (chip ~L703, falls at
   h_cnt 2) is still in the post-write / pre-read gap.

C. **Match the sprite latency to the tilemap.** The tilemap now lags ~10px;
   delay the sprite read path to match. Cleanest: a short delay-line register on
   `obj_pxl` (the line-buffer output) of the measured N cycles, OR read the line
   buffer N px ahead (`obj_dcol = h_cnt - HB_OPEN + N`). Measure N by simming a
   scene that has BOTH a tilemap landmark and a sprite, and aligning them. This
   single matched delay is the latency relationship the silicon has — not a fudge.

D. **Verify**: scenes 300/600 stay pixel-exact (text), a sprite scene (e.g.
   `mame_02700`) keeps correct sprites aligned to the tiles, and a full-flow
   sim/MP4 shows smooth (per-pixel) horizontal scroll. Then commit + journal.

### Tooling reminders
- Lint one core: `./lint-core.sh ddribble`
- Scene sim: `ROMS_HOST=~/.mame/roms-local tools/scenesim/sim_scenes.sh ddribble ddribble mame_00300`
- Output PNG: `cores/ddribble/ver/ddribble/sim_results/mame_00300.png` (ddribble
  emits `.png`, not `.jpg` — `sim-core.sh`'s MP4 auto-encode won't trigger;
  encode MP4 manually if needed). Host python has no numpy — use pure-Python
  column-profile cross-correlation for shift/lit measurement.
- Commit `--no-verify`; never commit `frames/`, `*.mp4`, `*.raw`, `test.wav`.
