# Vapor Trail / Kuhga (vaportra.cpp) — bring-up notes for the cninja-family core

MAME driver mirrored at `doc/vaportra.cpp`. Target: add as **game_id = 3** (free
slot; 0=cninja 1=cbuster 2=darkseal 4=supbtime). Closest existing sibling =
**darkseal** (2×deco16ic + MXC-06 sprites, split palette, YM2203+YM2151+2×OKI,
NO protection). Model the vaportra path on darkseal and diff where noted.

## Chips (same board family — "2× Data East 55 + 1× MXC-06", per the driver header)
- **68000 @ 12 MHz** (24MHz/2) — same clock as cninja/darkseal.
- **H6280 @ 6 MHz** (24MHz/4) sound CPU → loads into BRAM `snd` like the family.
- **2× deco16ic** tilegen (tilegen[0], tilegen[1]).
- **1× DECO MXC-06** sprite (= decospr).
- Sound: **YM2203 + YM2151 + 2× OKI MSM6295** (same as darkseal).
- **NO DECO146/104 protection** — inputs are read DIRECTLY. (Simplest of the family.)

## ⚠ Orientation: ROT270 (VERTICAL)
Vapor Trail is a **vertical** shmup. The raw framebuffer is still **256×240**
(`set_visarea(0,255, 8,247)`), so the *rendering* fits the 256px family geometry
unchanged — but the cabinet/monitor is rotated 270°. The cninja family is
horizontal (`JTFRAME_VERTICAL` not set). Rendering bring-up is orientation-
independent; the display-orientation decision (mark vertical / MiSTer rotate /
accept sideways) is a separate, later config item. NOT a rendering blocker.

## Memory map (main 68000) — `main_map`, differs from darkseal
```
000000-07ffff  ROM (512KB, byte-swap decrypted — see Decrypt)
100000-100001  r PLAYERS (P1/P2 joy+buttons, active-low)
100002-100003  r COINS   (coin/service + vblank bit3)
100004-100005  r DSW
100000-100003  w priority[0..1]  (priority_w: [0]=layer-order sel, [1]=spr/fg pri)
100007         w soundlatch (8-bit)
200000-201fff  rw tilegen[1] pf1 data   (deco16ic #2)
202000-203fff  rw tilegen[1] pf2 data
240000-24000f  w  tilegen[1] pf_control (scroll/flip/bank)
280000-281fff  rw tilegen[0] pf1 data   (deco16ic #1)
282000-283fff  rw tilegen[0] pf2 data
2c0000-2c000f  w  tilegen[0] pf_control
300000-3009ff  rw palette     RAM (GR: g=hi byte, r=lo byte)   [share m_paletteram]
304000-3049ff  rw palette_ext RAM (xB: b=lo byte)              [share m_paletteram_ext]
308001         rw irq6_ack (read or write clears M68K_IRQ_6)
30c000-30c001  w  sprite DMA trigger (buffered_spriteram16 write)
318000-3187ff  ram spriteram (0x800 bytes, mirror 0xce0000)
ffc000-ffffff  ram work RAM (16KB)
```
- **IRQ6** = vblank (`irq6_line_assert`), acked at 0x308001. (cninja used deco_irq;
  vaportra is a plain vblank IRQ6 — simpler.)

## Palette — SPLIT, like darkseal but full RGB888
- `m_paletteram` word = **{G[15:8], R[7:0]}**, `m_paletteram_ext` word = **{x, B[7:0]}**.
- final pen = `rgb(r,g,b)` each 8-bit → true **RGB888** (no 4-bit nibble like taitob).
- 1280 entries. Same SPLIT-RAM wiring as darkseal's colmix (`splitpal`), but
  darkseal/cbuster clamp/format differs — vaportra is straight 8-bit per channel.
- NOTE driver TODO: values >0xf0 not written (HW colour resistors) — ignore for now.

## Tile gfx — each chip has its OWN rom, used for BOTH its playfields
gfxdecode: tiles1 → (gfx0 8x8, gfx1 16x16); tiles2 → (gfx2 8x8, gfx3 16x16).
- **tilegen[0]** (pf1 8x8 + pf2 16x16) reads **tiles1** (512KB).
  col_bank pf1=0x00, pf2=0x20; 8x8 bank=0, 16x16 bank=1.
- **tilegen[1]** (pf1 8x8 + pf2 16x16) reads **tiles2** (1MB).
  col_bank pf1=0x30, pf2=0x40; 8x8 bank=2, 16x16 bank=3.
- bank_callback (both chips): `((bank>>4)&0x7) * 0x1000` → 3-bit tile bank, up to
  0x7000. BIGGER than cninja's single 0x1000 bit — needs ≥3 bank bits in the engine.
- 4bpp, `RGN_FRAC(1,2)` planar: planeoffset `{F+8,F+0, 0+8,0+0}` (F=half). Same
  family planar→ the engine's plane handling; verify pswap vs darkseal.
- charlayout/tilelayout: 8x8 = `8*16` bits/tile; 16x16 = `32*16`, columns
  `STEP8(16*8*2,1),STEP8(0,1)` rows `STEP16(0,8*2)` (half-major 16px).

## Sprites — MXC-06 (decospr family), 1MB
- gfx: tilelayout 16x16, palette base **0x100**, 16 colours.
- `colpri_cb`: sprite priority vs playfields = `colour >= m_priority[1]` → behind FG.
- spriteram 0x800 bytes, double-buffered (DMA at 0x30c000).

## Layer priority — RUNTIME selectable (NEW vs cninja/darkseal)
`screen_update`: `pri = m_priority[0] & 0x03` picks one of **4 orderings** of the
4 tilemaps (tilegen0 pf1/pf2, tilegen1 pf1/pf2) + sprites. tilegen0 pf1 (8x8) is
always drawn LAST (front-most). Sprites drawn between the playfields and pf1.
Must replicate the 4-way `pri` mux in colmix (driven by the priority[0] register).

## Decrypt — maincpu byte-swap (download-time)
`driver_init`: every maincpu byte `0x00000..0x7ffff` → `bitswap<8>(b, 0,6,5,4,3,2,1,7)`
= swap bit7<->bit0, keep bits 1..6. Apply in `game.v` `post_data` for game_id==3
(like darkseal/cbuster's post_data swaps). DO NOT apply to other regions.

## ROMs (parent `vaportra`)
```
maincpu  0x80000  fl_02-1+fl_00-1 (0x00000) + fl_03+fl_01 (0x40000)  LOAD16_BYTE
audiocpu 0x10000  fj04                              → BRAM snd
tiles1   0x80000  vtmaa00.bin (one 512KB mask)      → tilegen0
tiles2   0x100000 vtmaa02 (0) + vtmaa01 (0x80000)   → tilegen1
sprites  0x100000 vtmaa03 (0) + vtmaa04 (0x80000)
oki1     0x40000  fj06 (0x20000 loaded)
oki2     0x40000  fj05 (0x20000 loaded)
```
Sets: vaportra (World r1), vaportra3 (World r3, split tiles1 into 4), vaportrau
(US), kuhga (Japan). vaportra3 has tiles1 as 4×0x20000 LOAD16_BYTE instead of the
single mask — handle via a separate mame2mra rule if shipping that set.

## Bring-up plan (canonical path)
1. cfg: game_id=3, mame2mra.toml ROM rules + header `03 ...`, mem.yaml fit
   (maincpu→BA2 main, tiles1→BA3 scr1, tiles2→BA1/BA2 scr2/scr3, sprites→BA0).
2. game.v: vapor wire (game_id==3), post_data byte-swap, sound mux.
3. main.v: vaportra address decode (inputs direct @100000, priority reg, tilegens
   @200000/280000, split palette @300000/304000, sprite, work RAM @ffc000, IRQ6).
4. Boot: capture MAME 68k trace (doc/), PC-dump in sim, diff to boot landmark.
5. video.v/colmix.v: tilegen routing (tiles1→tg0, tiles2→tg1), 3-bit bank,
   split RGB888 palette, 4-way priority mux. Scene-diff vs MAME.
6. sound (reuse darkseal YM2203+YM2151+2×OKI path), inputs, polish.
