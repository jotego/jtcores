# Dark Seal (gatedoom) — hardware spec & integration notes

Source of truth: `cores/cninja/doc/darkseal.cpp` (MAME `dataeast/darkseal.cpp`,
mirrored 2026-06-09). Boot trace landmarks: `DARKSEAL_BOOT_TRACE.md`.

Dark Seal = "Gate of Doom" (US) / "Dark Seal" (World/Japan). Data East DECO
16-bit board, **part of the Caveman Ninja Hardware family** we are bringing up
as game_id variants of the `cninja` core (see `HW_FAMILY.md`). game_id = 2.

> **Bring-up status: ANALYSIS ONLY.** No HDL wired yet. The boot trace and this
> doc are the canonical step-0/0.5 deliverables. The game_id mux architecture
> (esp. palette + address decoder) is a design decision left for a session with
> the user — see "Integration assessment" at the bottom.

---

## 1. CPUs and clocks

| Block      | Device | Clock                         | Notes |
|------------|--------|-------------------------------|-------|
| Main CPU   | M68000 | 24 MHz / 2 = **12 MHz**       | "Custom chip 59" — same as cninja |
| Sound CPU  | HuC6280 (H6280) | 32.22 MHz / 4 = **8.055 MHz**, `set_timer_scale(2)` | "Custom chip 45" |

**Sound-clock delta vs cninja:** darkseal specs the H6280 at `XTAL/4` (8.055 MHz
device clock) with `timer_scale(2)`, whereas the cninja snd.v gates `hu_clk` to
~4 MHz. The H6280 internally divides; confirm the effective instruction rate in
sim against the boot trace before trusting the existing cen. Likely the same
real ~4 MHz core rate (the /4 + internal /2), but VERIFY.

---

## 2. Main CPU memory map (`main_map`, darkseal.cpp:163)

```
000000-07ffff  ROM (512 kB)                          maincpu, 4x 128 kB 16-bit
100000-103fff  work RAM (16 kB)                       <- BRAM (clear loop @0x14A4)
120000-1207ff  sprite RAM (2 kB)                      buffered_spriteram16
140000-140fff  palette RAM      (RG)  write palette_w
141000-141fff  palette RAM ext  (B)   write palette_ext_w
180000-180001  DSW           (port read)              DIRECT - no protection chip
180002-180003  P1_P2         (port read)
180004-180005  SYSTEM        (port read, bit3 = vblank)
180006-180007  sprite DMA    (write -> buffer spriteram)
180008-180009  soundlatch    (write, umask 0x00ff)
18000a-18000b  irq_ack       (write)
200000-201fff  tilegen[1] pf1 data
202000-203fff  tilegen[1] pf2 data
220000-220fff  pf1 rowscroll  (tilegen[0]'s pf1)
222000-222fff  pf3 rowscroll  (tilegen[1]'s ... see note)
240000-24000f  tilegen[1] pf_control
260000-261fff  tilegen[0] pf1 data
262000-263fff  tilegen[0] pf2 data
2a0000-2a000f  tilegen[0] pf_control
```

Note MAME's own comment: pf2/pf4 rowscroll regions "maybe don't exist". The two
rowscroll banks are 0x220000 (pf1) and 0x222000 (pf3).

---

## 3. Sound CPU memory map (`sound_map`, darkseal.cpp:192) — **IDENTICAL to cninja**

```
000000-00ffff  ROM (64 kB)        audiocpu  -> BRAM (same as cninja now)
100000-100001  YM2203 (ym1)
110000-110001  YM2151 (ym2)       IRQ -> H6280 IRQ2 (input line 1)
120000-120001  OKI1  (oki1)
130000-130001  OKI2  (oki2)
140000-140001  soundlatch read    -> H6280 IRQ1 (input line 0, data_pending)
1f0000-1f1fff  work RAM (8 kB)
```

This is byte-for-byte the cninja sound map. **`jtcninja_snd.v` should drop in
essentially unchanged** (verify the H6280 cen, above).

### Sound chips (machine_config)

| Chip   | Clock              | Route | jt module |
|--------|--------------------|-------|-----------|
| YM2203 | 32.22/8 = 4.0275M  | 0.45  | jt03      |
| YM2151 | 32.22/9 = 3.58M    | 0.55 L+R | jt51   |
| OKI1   | 32.22/32 = 1.0069M, PIN7_HIGH | 1.0  | jt6295 |
| OKI2   | 32.22/16 = 2.0138M, PIN7_HIGH | 0.60 | jt6295 |

Same chip set and clocks as cninja. Mix ratios differ slightly (cninja was
rebalanced to 0.60/0.45/0.75/0.60); darkseal's are 0.45/0.55/1.0/0.60.

---

## 4. Palette — **24-bit RGB888, SPLIT across two RAM regions** (KEY DELTA)

```c
r = (paletteram[offset]     >> 0) & 0xff;   // 140000 region, low byte
g = (paletteram[offset]     >> 8) & 0xff;   // 140000 region, high byte
b = (paletteram_ext[offset] >> 0) & 0xff;   // 141000 region, low byte
```

- 2048 palette entries.
- `paletteram` word = `{G[7:0], R[7:0]}` at 0x140000.
- `paletteram_ext` word = `{xxxx, B[7:0]}` at 0x141000.
- **8 bits per channel = true RGB888** (24-bit colour).

Contrast cninja: RGBx_444 (12-bit) in a single 0x19c000 region. Dark Seal needs
**two palette BRAMs** and a colmix that assembles 24-bit from the RG word + the
B-ext word. This is the single biggest HDL divergence.

---

## 5. Tilemaps — 2x DECO16IC (same chip family as cninja)

| Tilegen | pf sizes        | 8x8 bank | 16x16 bank | col_mask | data @ | ctrl @ |
|---------|-----------------|----------|------------|----------|--------|--------|
| [0]     | 64x64 (both)*   | 0        | 1          | 0x0f     | 260000/262000 | 2a0000 |
| [1]     | 64x32 (both)    | 0        | 2          | 0x0f     | 200000/202000 | 240000 |

*MAME comment: tilegen[0]'s maps "need to be twice the y size of usual"
(64x64). col_bank = 0 for both. First tilegen[1] control write in the boot
trace: `move.w #$90, $240000` then `D0 -> $240002` (PC 0x1656).

Render order (`screen_update`, darkseal.cpp:138):
```
fill black
tilegen[0].pf_update ; tilegen[1].pf_update
tilegen[1].tilemap_1_draw     (back)
tilegen[1].tilemap_2_draw
tilegen[0].tilemap_1_draw
sprgen.draw_sprites (0x400 entries)
tilegen[0].tilemap_2_draw     (front)
```
Sprites are drawn BETWEEN tilegen[0]'s two tilemaps (pf1 behind, pf2 in front of
sprites). `flip` comes from `tilegen[1].pf_control_r(0) bit7`.

---

## 6. GFX layouts & ROM regions

| Region   | Size   | Layout    | bpp | colour base | #pal | ROMs |
|----------|--------|-----------|-----|-------------|------|------|
| chars    | 0x20000 | 8x8  RGN_FRAC(1,2) | 4 | 0    | 16 | fz_02,fz_03 (16-bit byte) |
| tiles1   | 0x80000 | 16x16 seallayout   | 4 | 768  | 16 | mac-03 (single) |
| tiles2   | 0x80000 | 16x16 seallayout   | 4 | 1024 | 16 | mac-02 (single) |
| sprites  | 0x100000 | 16x16 seallayout  | 4 | 256  | 32 | mac-00,mac-01 (RGN_FRAC 1,2) |
| maincpu  | 0x80000 | -        | - | -            | -  | ga_04-3,ga_01-3 / ga_00,ga_05 (16-bit byte) |
| audiocpu | 0x10000 | -        | - | -            | -  | fz_06-1 |
| oki1     | 0x40000 | -        | - | -            | -  | fz_08 (only 0x20000 loaded) |
| oki2     | 0x40000 | -        | - | -            | -  | fz_07 (only 0x20000 loaded) |

Plane order (both charlayout & seallayout): `{8, 0, RGN_FRAC(1,2)+8, RGN_FRAC(1,2)}`
— same RGN_FRAC(1,2) plane-pair split as cninja's tiles/sprites (planes 0,1 in
first ROM half, 2,3 in second). **The cninja game.v download plane-rotate and
the bank-split sprite trick apply directly.**

Sprites = mac-00 (0x00000) + mac-01 (0x80000), 1 MB total, RGN_FRAC(1,2) → same
two-bank parallel-fetch layout we just built for cninja can be reused.

---

## 7. Inputs & DIPs (DIRECT, no protection)

- **P1_P2** (0x180002): UDLR + B1 + B2 + START per player (bit layout in
  darkseal.cpp:206). Button 3 unused. 2-button game like cninja.
- **SYSTEM** (0x180004): COIN1/2/3 (bits 0-2), vblank (bit3, ACTIVE_HIGH).
- **DSW** (0x180000): SW1 = coinage + flip (SW1:7) ; SW2 = lives/difficulty/
  energy/continue/demo-sounds. 16-bit DIP word.

Crucially the inputs are read straight off the bus (no DECO 104/146). The
cninja `jtcninja_deco104` block is **bypassed entirely** for darkseal — inputs
go direct to the 68k data bus at 0x180000-0x180004, soundlatch direct at
0x180008.

---

## 8. IRQ — simple vblank (no raster)

- `irq6_line_assert` on vblank (`set_vblank_int`), IRQ level 6.
- `irq_ack_w` (0x18000a) clears `M68K_IRQ_6`.
- **No deco_irq raster system** (cninja has raster1/raster2 IRQs at 0x190000).
  Dark Seal's interrupt logic is far simpler: one vblank IRQ, acked by a write.

---

## 9. Boot landmarks (from the MAME trace, `DARKSEAL_BOOT_TRACE.md`)

| PC      | Action |
|---------|--------|
| 0x1490  | init control regs: soundlatch=1, clr sprite-DMA (180006), clr irq-ack (18000a) |
| 0x14A4  | **work-RAM clear loop** 0x100000-0x104000 (the stage-2 validation gate) |
| 0x1656  | first tilegen[1] control write (`#$90 -> 240000`) |
| 0x250A  | reads inputs/DSW at 0x180000 |
| 0x256C  | sets up palette pointers (0x140a00 / 0x141a00) |

(The trace begins at 0x1490; the reset vector / SP load at 0x0/0x4 executed
before MAME's debugger trace engaged. Read the maincpu ROM vectors if the exact
reset PC is needed.)

---

## 10. Integration assessment (game_id = 2 variant of cninja)

What **reuses cleanly** from the cninja core:
- **Sound** — identical map + chips; `jtcninja_snd.v` drops in (verify H6280 cen).
- **GFX decode** — same RGN_FRAC(1,2) plane split; the download plane-rotate,
  the sprite two-bank parallel-fetch, and the deco16ic tile decode all apply.
- **decospr sprite engine**, **deco16ic tilemap engine** — same chips.
- Sprite ROM is 1 MB RGN_FRAC(1,2) → the BA0/BA1 split we just built fits.

What **must be muxed on game_id** (the real work):
1. **Address decoder** (`jtcninja_main.v`) — darkseal's map is entirely
   different (ROM 512 kB, work RAM @0x100000, palette @0x140000, inputs/sound/
   irq @0x180xxx, tilegens @0x200000/0x260000). This is the largest delta.
2. **Palette** — 24-bit RGB888 across TWO regions (0x140000 RG + 0x141000 B)
   vs cninja's 12-bit RGBx_444 single region. Needs a 2nd palette BRAM + a
   colmix path that builds 24-bit. Biggest video divergence.
3. **No protection** — bypass `jtcninja_deco104`; inputs read direct.
4. **IRQ** — simple vblank+ack vs cninja's deco_irq raster system.
5. **Tilegen geometry** — tilegen[0] is 64x64 (double-height); addresses differ.
6. **mem.yaml / mame2mra** — new ROM region layout (sizes above), header
   game_id=2, second machine `darkseal` in mame2mra.

**Recommendation:** the deltas (full address map + 24-bit split palette + no
protection + different IRQ) are substantial — this is more than "a few config
switches". A clean approach is a thin per-game address-decode + palette module
selected by game_id, rather than threading game_id through every decode line in
the shared main/video. Worth deciding with the user before wiring. Sound and
gfx-decode reuse are the easy wins to do first.
