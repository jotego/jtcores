# Super Burger Time — hardware notes

MAME driver: `doc/supbtime.cpp` (Data East, 1990). Sibling games on the same
board: **China Town** (`chinatwn`), **Tumble Pop** (`tumblep`) — same chips,
slightly different maps/sound clocks.

This is a deliberately CLEAN bring-up target: **no protection, no maincpu
decrypt, one tilegen, standard planar gfx** (reuses cninja's `jtcninja_deco16` /
`jtcninja_decospr` directly, `pswap=0`).

## Chips & clocks

| block      | device        | clock                         |
|------------|---------------|-------------------------------|
| main CPU   | M68000        | 21.477272 MHz / 2 = 10.738 MHz|
| sound CPU  | HuC6280 (DE45)| 32.22 MHz / 4 = 8.055 MHz     |
| tilemaps   | 1× DECO16IC   | pf1 col_bank 0x00 / pf2 0x10, col_mask 0x0f; 8x8 bank 0, 16x16 bank 1; both pf 64x32 |
| sprites    | DECO_SPRITE (decospr / MXC-06) | — |
| FM         | YM2151        | 32.22 MHz / 9                 |
| ADPCM      | OKIM6295      | 32.22 MHz / 32, pin7 HIGH     |

**Sound quirk** (driver comment): the sound program *writes* to a YM2203 and a
2nd OKI that **are not on the board** — ignore those writes. Only YM2151 + 1 OKI.

Screen: `set_raw(28 MHz/4 = 7 MHz, 442 total, 0..320 visible, 274 total, 8..248
visible)` → **320×240 visible**, ~57.8 Hz.

## Main 68000 memory map (`supbtime_map`)

```
000000-03ffff  ROM (256 kB; gk03/gk04 ROM_LOAD16_BYTE, NO decrypt)
100000-103fff  work RAM (16 kB)
120000-1207ff  sprite RAM (0x400 words)
140000-1407ff  palette (write16)            <- format TBD (xBGR? confirm in sim)
180000-180001  INPUTS (read)
180002-180003  DSW    (read)
180008-180009  SYSTEM (read)
18000a-18000b  vblank_ack (read)            <- reading acks the VBL IRQ
1a0001         soundlatch (write, low byte)
300000-30000f  deco16ic control (pf_control_r/w)
320000-321fff  pf1 data (chip pf1)
322000-323fff  pf2 data (chip pf2)
340000-3407ff  pf1 rowscroll
342000-3427ff  pf2 rowscroll
```

IRQ: VBL → IRQ? (MAME: `set_vblank_int`; ack by reading 0x18000a). Confirm level
in boot trace. (tumblep/chinatwn use slightly different maps — see driver.)

## Input ports (active-low unless noted)

- **INPUTS** (0x180000): P1 U/D/L/R = bits 0-3, P1 B1/B2 = 4/5, (b3 unused), START1 = 7;
  P2 U/D/L/R = 8-11, P2 B1/B2 = 12/13, START2 = 15. **2 buttons.**
- **SYSTEM** (0x180008): COIN1=0, COIN2=1, SERVICE1=2, **VBLANK=3 (active HIGH)**.
- **DSW** (0x180002): DSW1 = coinage (Coin_A 0xe0, Coin_B 0x1c), Flip 0x02, Cabinet 0x01;
  DSW2 = Demo_Sounds 0x100, Allow_Continue 0x200, Difficulty 0x3000, Lives 0xc000.

Joystick byte order is UDLR at bits 3:0 — check vs MiSTer RLDU when wiring
(likely needs `JTFRAME_JOY_xxxx`, confirm against the engine).

## GFX layout — STANDARD planar (cninja-native)

```
tile_8x8_layout  : 8x8,   RGN_FRAC(1,2), 4bpp,
                   planes { F(1,2)+8, F(1,2)+0, F(0,2)+8, F(0,2)+0 }
tile_16x16_layout: 16x16, RGN_FRAC(1,2), 4bpp, same plane order
```

This is the SAME plane packing as cninja/darkseal — `jtcninja_deco16` /
`jtcninja_decospr` read it directly with `pswap=0`. No chunky reverse (cbuster
was the exception). gfxdecode bases: tiles 256 (×32 colours), sprites 0 (×16).

## ROM regions (parent `supbtime`)

```
maincpu  0x40000   gk03 (even) + gk04 (odd)          ROM_LOAD16_BYTE
audiocpu 0x10000   gc06.bin
tiles    0x80000   mae02.bin (single, RGN_FRAC(1,2) split internally)
sprites  0x100000  mae01.bin @0x00000 + mae00.bin @0x80000
oki      0x20000   gc05.bin
pals     6× PAL    (board glue; not needed)
```

## Bring-up plan (per AGENTS.md canonical path)

0.5 capture MAME boot trace (68000 from reset) → `ver/supbtime/traces/`  ← needs ROM
1.  scaffold `cfg/` (macros.def, mem.yaml, mame2mra.toml, files.yaml)
2.  CPU spine: 68000 @ cen, full address decode, work/sprite/pal/pf RAM in BRAM,
    SIM PC dumper, diff vs MAME. No decrypt, no protection → should boot fast.
3.  first frame (palette/BRAM viewer)
4.  tilemaps (deco16ic, reuse jtcninja_deco16) → sprites (decospr, pswap=0)
5.  scene-replay grading (tools/scenesim, 10 scenes)
6.  sound (HuC6280 + YM2151 + OKI; ignore the phantom YM2203/2nd OKI writes)

ROM availability: `supbtime.zip` not in `~/.mame/roms-local` yet — boot trace and
all sims are blocked until it lands.
