# F-1 Grand Prix (Video System Co., 1991)

MAME driver `vsystem/f1gp.cpp`, mirrored here alongside the device sources.
Sets in scope: `f1gp`, `f1gpa`. `f1gpb` and `f1gpbl` are MACHINE_NOT_WORKING;
`f1gp2` is a different board (VS920A + mb60553) and needs its own core.

## Chips

| Block | Part | Notes |
|---|---|---|
| Main CPU | 68000 @ 10 MHz (XTAL 20/2) | IRQ1 on vblank |
| Sub CPU | 68000 @ 10 MHz | road and opponents; IRQ1 on vblank, IRQ3 from the ACIA |
| Sound CPU | Z80 @ 5 MHz (XTAL 20/4) | 0000-77ff ROM, 7800-7fff RAM, 8000-ffff banked (2 x 32 kB from 0x8000) |
| Sound chip | YM2610 @ 8 MHz | ADPCM-A 1 MB, ADPCM-B 1 MB. IRQ to the Z80 |
| Video timing | C7-01 GGA @ 14.318181/2 | write-only, 4 registers at fff020 |
| Sprites | VS8904 + VS8905 x2 | `vsystem_spr2`, pritype 2, indirect tile lookup |
| ROZ | Konami 053936 | `set_wrap(1)`, offsets (-58,-2), control at fff040 |
| Link | ACIA 6850 + 2x DE-9 | cabinet-to-cabinet; stubbed in this core |
| Screen | 60 Hz, visarea 0..319 x 8..247 = **320x240**, ROT90 | |
| Palette | 2048 x xRGB-555 | fg 0x000, SPR-1 0x100, SPR-2 0x200, ROZ 0x300 |

Same custom set as `pspikes.cpp` (GGA + VS8904/VS8905), so the clocking, the
GGA, the sound CPU and the sprite scanner all come straight from `pspike`.


video: https://www.youtube.com/watch?v=6fACy69_-qU

## Main CPU map

```
000000-03ffff  ROM
100000-2fffff  ROM  "user1"
a00000-bfffff  ROM  "user2" - source data the CPU copies into rozgfx
c00000-c3ffff  rozgfx  RAM   2048 tiles of 16x16x4 packed MSB, GFXDECODE_RAM
d00000-d01fff  rozvram RAM   64x64 map, mirrored at +6000. code&0x7ff, colour code>>12
e00000-e03fff  SPR-1 CG RAM  the sprite tile-code lookup
e04000-e07fff  SPR-2 CG RAM
f00000-f003ff  SPR-1 VRAM    512-word list, start pointer at word 0x1fe
f10000-f103ff  SPR-2 VRAM
ff8000-ffbfff  work RAM
ffc000-ffcfff  RAM shared with the sub 68000
ffd000-ffdfff  fg VRAM       8x8x8 raw, code&0x7fff, flipY on code[15], pen 0xff clear
ffe000-ffefff  palette
fff000 r INPUTS       fff001 w gfxctrl (bit 5 = flip)
fff002 r WHEEL        fff002-fff005 w fg scroll x / y
fff004 r DSW1         fff006 r DSW2
fff009 r sound-latch pending (0xff/0x00)   w sound latch
fff020-fff023  w GGA
fff040-fff05f  w 053936 control            fff050 r DSW3
```

## Sub CPU map

```
000000-01ffff  ROM
ff8000-ffbfff  work RAM
ffc000-ffcfff  RAM shared with the main 68000
fff030-fff033  ACIA 6850
```

## Video notes

- **fg is 8bpp raw**: one byte per pixel, no plane decode, so a 32-bit read is
  four pixels. `jtframe_tilemap` cannot do BPP=8 (it would want a 64-bit ROM
  bus), hence a small custom fetcher.
- **ROZ graphics live in RAM**, uploaded by the CPU from `user2`. A rotating
  layer can need a new tile every pixel, so `rozgfx` has to be BRAM.
- **Sprite priority**: both chips are pritype 2 - a single descending pass, no
  priority filtering, and the priority value comes from the caller. `gfxctrl==0`
  puts both chips behind fg/ROZ, otherwise chip 0 goes in front. MAME calls its
  own handling of this "a kludge", so it is reproduced, not trusted.

## SDRAM / BRAM

SDRAM ~10.25 MB. `user1` is kept at its own 68000 offset inside the `main`
region so the address decode is a plain wire; the 768 kB hole costs nothing.

BRAM ~342 kB, of which `rozgfx` alone is 256 kB.
