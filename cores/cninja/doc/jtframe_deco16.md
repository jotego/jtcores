# jtcninja_deco16 — status + design notes

Faithful FPGA implementation of the Data East **deco16ic** tile generator
(custom chips **55 / 56 / 74**, 4bpp). MAME ref mirrored in this folder:
`deco16ic.cpp/.h`, `tilemap.cpp/.h`. Scope: 4bpp only (the 8bpp/`mix_cb`
"141" combine is out of scope — see Open Items).

---

## 1. Current state (works, NOT yet committed)

`cores/cninja/hdl/jtcninja_deco16.v` is a **single-playfield** streamer:

- All four scroll modes from `control1[6:5]`: uniform / rowscroll (per-line X) /
  colscroll (per-column Y) / **both** (`custom_tilemap_draw`, per-line X AND
  per-column Y) — the both-mode is the fix for the end-of-level-1 rising ground.
- Runtime 8×8 / 16×16 (`control1[7]`), 64×32 / 64×64 maps, screen flip +
  per-tile X/Y flip (`tile 0x8000` gated by `control1[1:0]`).
- Streaming model: the line is walked as **8px source-columns** (the gfx-fetch
  granularity). Each column picks its own colscroll-Y and per-line rowscroll-X,
  lands on one tile's left/right half → one tile lookup + one 32-bit gfx read.
  Faithful to `custom_tilemap_draw` because `col_type (=8<<style) >= 8`.

Swapped into `jtcninja_video.v` as **4 instances** (`u_fg u_mg u_bg u_pf1b` =
2 chips × 2 playfields). Scene-sim verified (cninja pixel-clean; darkseal forest
coherent). `./lint-core.sh cninja` clean.

### Bugs fixed during bring-up
1. **gfx word order** — 16×16 is half-major: `word-in-tile = half*16 + subrow`
   (`{tile,half,subrow}`), NOT `subrow*2+half`.
2. **half polarity** — left 8px (`src_x[3]=0`) live in the *upper* 16 words →
   `half = ~src_x[3]`. This is MAME's **xoffset** `{STEP8(16*8*2,1),STEP8(0,1)}`,
   identical for cninja `tilelayout` and darkseal `seallayout` → faithful, not a hack.
3. **rom_addr code-lag (the big one)** — `rom_addr` was built from the `code`
   *register*, but `code <= ram_data` latches the same cycle, so every column
   fetched the **previous** column's tile → whole image 1 column (8px) right,
   and 16×16 even/odd columns alternated wrong. Fixed: build `rom_addr` from
   `ram_data` directly (current tile).

### Faithfulness check (vs MAME gfxlayout) — no compensating hacks
- `pswap` = the per-game **planeoffset** difference: cninja `{FRAC+8,FRAC,8,0}`
  vs darkseal `{8,0,FRAC+8,FRAC}` (the two plane-pairs are swapped). Verified the
  plane decode algebraically against both arrays.
- `half=~src_x[3]` = MAME **xoffset** (universal). 
- The mame2mra interleave is a legit planar→chunky (byte-per-plane) conversion.

---

## 2. WANT TO REVISIT: 1 module = 1 chip (not 1 playfield)

Today a chip is **2 modules** (and cninja/darkseal are 4). It works because for
4bpp the two playfields of a chip are independent at render time — separate
scroll, tile RAM, gfx bus, often different tile sizes, and drawn at different
priority levels interleaved with sprites (`fg > obj0 > mg > obj1 > pf1b > obj23
> bg`). They never combine in 4bpp.

But what genuinely belongs to the **chip**, not the playfield, is the
**control-register block** (`control[0..7]`) and the **bank callbacks** — i.e.
`deco16ic_device::pf_update`. Right now that's decoded in `video.v` (splitting
`control[5]/[6]` into per-pf bytes, deriving modes/bank). That's chip logic
leaking into the core. A per-chip module encapsulates it and mirrors the MAME
`deco16ic_device` 1:1.

### Proposed structure (two layers)
- **`jtcninja_deco16_pf`** — the playfield streamer that exists today (rename the
  current `jtcninja_deco16` to this).
- **`jtcninja_deco16`** — the **chip**: owns `control[0..7]`, does `pf_update`,
  instantiates 2× `jtcninja_deco16_pf`, emits `pf1_pxl`/`pf2_pxl`. `video.v` then
  instantiates **2** of these (tg0, tg1) and passes the raw 8 control words.

### Chip module interface (draft)
```
jtcninja_deco16 (= one deco16ic_device)
  // clocks / timing
  rst, clk, pxl_cen, hs, vrender[8:0], hdump[8:0], flip
  // per-chip / per-pf static config (resolved by the core, per game)
  pf1_fullheight, pf2_fullheight        // DECO_64x32 vs 64x64 (set_pfN_size)
  pf1_pswap, pf2_pswap                  // gfxlayout planeoffset order
  pf1_bank[2:0], pf2_bank[2:0]          // resolved bank-callback output (see Q1)
  // control registers (CPU writes the chip's control port; SIMFILE preload)
  ctrl_we, ctrl_addr[2:0], ctrl_din[15:0]
  // playfield data RAMs (chip-owned BRAM, CPU write strobes from core)
  pf1_ram_we, pf2_ram_we, ram_waddr[11:0], ram_wdin[15:0]
  pf1_ram_dout[15:0], pf2_ram_dout[15:0]   // CPU read-back
  // rowscroll/colscroll RAMs (chip-owned; darkseal shares 1 per chip - see Q3)
  pf1_rs_we, pf2_rs_we, rs_waddr[10:0], rs_wdin[15:0]
  // gfx ROM buses (one per pf; SDRAM, wired by core to the right region)
  pf1_rom_cs/addr[19:2]/data[31:0]/ok
  pf2_rom_cs/addr[19:2]/data[31:0]/ok
  // outputs
  pf1_pxl[7:0], pf2_pxl[7:0]
  ctrl0_flip                            // control[0] bit7, for the core's global flip
```

### pf_update done internally (per deco16ic.cpp)
```
pf1: scrollx=control[1] scrolly=control[2] control0=control[5][7:0]  control1=control[6][7:0]
pf2: scrollx=control[3] scrolly=control[4] control0=control[5][15:8] control1=control[6][15:8]
mode    = control1[6:5]   (00 uniform / 40 row / 20 col / 60 both)
tile16  = ~control1[7]     enable = control0[7]
rs style= control0[6:3]    cs style = control0[2:0]
```
(NB the deco code's pf1/pf2 use control[1]/[2] vs [3]/[4] — the header comment's
pf1/pf2 naming is swapped vs the code; the code is authoritative.)

### video.v after refactor
- 2× `jtcninja_deco16` (tg0, tg1). Per-game CPU address decode routes control /
  pf-data / rowscroll writes to the right chip+port. colmix consumes the 4
  streams (chip0.pf1/pf2, chip1.pf1/pf2) at their priorities. The `fg_c0/fg_c1`
  / `mg_c0` … extraction and the 4 explicit rowscroll RAMs disappear from video.v.

### Open design questions (decide before coding)
- **Q1 Bank callback** — `cninja_bank_callback` is per-game (`control[7]` →
  high tile-code bit). Keep resolving it in the core and pass `pfN_bank`, OR pass
  `control[7]` + a bank-mode param. Recommend: resolve in core (callback is
  genuinely game-specific), pass `pfN_bank`.
- **Q2 Runtime tile-size switch** — a deco16ic pf can flip 8×8↔16×16 at runtime
  (`control1[7]`), and the 8×8 (chars) vs 16×16 (tiles) gfx live in *different*
  ROM regions (`set_pf12_8x8_bank` / `_16x16_bank`). cninja/darkseal fix each
  pf's size, so one gfx bus per pf (wired to the matching region) is enough.
  General support needs 2 gfx buses (or a muxed bus) per pf — defer.
- **Q3 Shared rowscroll RAM** — darkseal uses ONE rowscroll RAM per chip shared
  by pf1+pf2 (`m_pf1_rowscroll` for both); cninja has separate. Chip exposes 2 rs
  read ports; the core wires them to 2 RAMs (cninja) or 1 mirrored RAM (darkseal).
- **Q4 RAM ownership** — recommend the chip OWNS its BRAM (control regs, 2 tile
  RAMs, 2 rowscroll RAMs) with `$readmemh` SIMFILE preload for scene replay
  (encapsulates the ctrl0/ctrl1.hex + per-RAM .bin loading). Core supplies only
  CPU write strobes + gfx ROM buses.
- **Q5 8bpp combine (141)** — the per-chip shape is the natural home for the
  `mix_cb` combine (two 4bpp pf → one 8bpp layer). Out of scope now; note the
  hook point: a `mix_pxl[7:0]` output that concatenates pf1/pf2 pen pairs.

---

## 3. Other open items (orthogonal to the refactor)
- **darkseal dungeon `0xff00` attract anomaly** — `u_mg` (tg0 pf1, DECO_64x64)
  renders blank in scene 5400 because faithful `(0xff00+y) mod 1024 = row 48`
  (content is rows 0-31). MAME shows the floor at a fixed, scroll-independent
  position in attract; never reconciled with the uniform-scroll formula. In
  gameplay the dungeon uses normal scroll values. Separate puzzle.
- **dead regs** — `code` / `tfy` in `jtcninja_deco16.v` are now unused (rom_addr
  uses `ram_data`; rsubrw uses `cur_tfy`). Remove on cleanup.
- **col_bank / col_mask** — not wired (cninja/darkseal use mask 0xf, bank 0).
  Add inputs for games that use them.
- **disabled-pf clear** — `en=0` currently stops writing → stale linebuf. Fine
  for cninja/darkseal (always enabled); add a clear-on-disable before reuse.
- ~~darkseal sprite colours~~ FIXED: the sprite gfx uses the same `seallayout`
  plane-pair order as the tiles, so the sprite engine needs `pswap` too. Extracted
  the obj engine into a generic `jtcninja_decospr` (decospr.cpp faithful) with a
  `pswap` input; `jtcninja_obj` wraps it driving `pswap=dseal`.
