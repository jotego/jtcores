# Tail to Nose / Super Formula (Video System, 1989)

MAME driver `vsystem/tail2nos.cpp`, mirrored here with the device sources.
Sets: `tail2nos`, `tail2nosa` (Japan), `sformula`, `sformulaa` (the same game as
Super Formula). All four program the same hardware.

Assessment only - no HDL written yet.

## Chips

| Block | Part | Notes |
|---|---|---|
| Main CPU | 68000 @ 10 MHz (XTAL 20/2) | verified on PCB. IRQ6 on vblank, IRQ3 from the ACIA |
| Sound CPU | Z80 @ 5 MHz (XTAL 20/4) | banked, NMI on sound latch write |
| Sound chip | **YM2608 (OPNA) @ 8 MHz** | verified on PCB. IRQ to the Z80 |
| Zoom layer | **Konami K051316** (PSAC) | 4bpp, tiles in RAM, wrap on, offsets (7,-14) |
| Video timing | C7-01 GGA @ 14.318181/2 | write only, 4 registers at fff020 |
| Link | ACIA 6850 + 2x DE-9 | cabinet to cabinet, 78125 baud |
| Screen | 60 Hz, visarea 0..319 x 8..247, ROT90 | |
| Palette | 2048 x xRGB-555 | |

There is no sub CPU, unlike f1gp.

## Main CPU map

```
000000-03ffff  ROM
200000-27ffff  ROM  "user1"
2c0000-2dffff  ROM  "user2"
400000-41ffff  zoomram RAM  128kB, K051316 tile graphics, uploaded by the CPU
500000-500fff  K051316 RAM   (byte, umask 00ff)
510000-51001f  K051316 ctrl  (byte, umask 00ff)
ff8000-ffbfff  work RAM
ffc000-ffc2ff  sprite RAM    96 sprites of 4 words
ffc300-ffcfff  RAM
ffd000-ffdfff  tx VRAM       8x8x4
ffe000-ffefff  palette
fff000 r IN0    fff001 w gfxbank (tx bank, palette bank, flip, video enable)
fff002 r IN1
fff004 r DSW
fff009 r sound-latch pending  w sound latch
fff020-fff023  w GGA
fff030-fff033  rw ACIA 6850
```

## What already exists in jtcores

**The map is nearly f1gp's.** The whole `fff000` block matches: inputs at
`fff000` with a control byte on the odd address, ports at `fff002`/`fff004`, the
sound latch with its pending read at `fff009`, the GGA at `fff020` and the ACIA
at `fff030`. Work RAM, tx VRAM and palette sit at the same `ff8000`/`ffd000`/
`ffe000` addresses. `jtf1grpr_main.v` is close to a template.

**The GGA is programmed identically to f1gp**, byte for byte:

```
reg 00 01 02 03 04 05   08 09 0a 0b 0c 0d
    4f 5e 64 71 1f 09   7a 7c 7e 7f 1f 02
```

So `jtpspike_gga.v` works unchanged, including the `reg08 = 7a` case where the
decoded 246 lines are cut to 240 - see `cores/pspike/doc/GGA.md`.

**The ACIA link** is the same arrangement f1grpr already stubs, there on the sub
CPU and here on the main one, at the same address.

**`jt051316.v` exists** in `cores/ajax/hdl`, but see below.

## Work items

### 1. YM2608 - the main risk

No OPNA implementation exists. `modules/jt12` provides jt03 (YM2203), jt10 and
jt10b (YM2610/B) and jt12 (YM2612), none of which is a YM2608.

Tapping the sound driver's register writes shows the game uses the whole chip:

```
fm_slots = 0.0, 0.1, 0.2, 1.0, 1.1, 1.2    all six FM channels
rhythm   = true                             registers 10-1d
ssg      = true
deltaT   = true                             ADPCM-B
```

FM, SSG and deltaT are plausibly reachable from `jt10b`, which already has six FM
channels through `FULLFM(1)`, an SSG and an ADPCM-B channel. The rhythm section
is the problem: it plays six fixed percussion samples from the chip's **internal**
sample ROM, and the romset carries no such region - `osb.ic127` (128kB, region
`ymsnd`) is the deltaT sample ROM only. That data has to be sourced separately.

Decide the approach before writing sound HDL. Dropping rhythm initially would
lose the percussion but leave the rest of the score intact.

### 2. K051316 in RAM-fed 4bpp mode

ajax drives the chip with `set_bpp(7)` reading from ROM. tail2nos uses
`set_bpp(-4)`: the negative value means 4bpp with the tile graphics in **RAM**,
which the CPU uploads into `zoomram` at `400000-41ffff` through `zoomdata_w`.
That is the same arrangement as f1grpr's `rozgfx`, so the 128kB belongs in BRAM.

`jt051316` therefore needs a RAM-fed path and 4bpp unpacking rather than its
current ROM interface, plus `wrap` and the `(7,-14)` offsets.

The zoom callback remaps the tile before drawing:

```c
code |= ((color & 0x03) << 8);
color = 32 + ((color & 0x38) >> 3);
```

### 3. Sprites - new but simple

Not `vsystem_spr2`. A plain list of 96 entries, 4 words each, no zoom and no
priority:

```
w0  y, taken as 0x10000 - value, then signed
w1  x, signed
w2  code[10:0]  flipy[11]  flipx[12]  colour[15:13]
w3  unused
```

Tiles are **16x32**, 4bpp, with the two ROM halves interleaved (`RGN_FRAC(1,2)`).
Palette is `40 + colour`. MAME nudges the sprites by `(+3,+1)` relative to the
zoom layer, noted in the driver as verified against the real board. Under flip,
`sx = 302 - sx` and `sy = 216 - sy`.

This is considerably less work than f1grpr's dual VS8904/VS8905 scanner.

### 4. tx tilemap

8x8x4, packed LSB.

```
code   = (vram & 0x1fff) + (txbank << 13)
colour = ((vram & 0xe000) >> 13) + txpalette * 16
```

`txbank` and `txpalette` come from `gfxbank_w` at `fff001`, which also carries
the flip and video-enable bits.

## Layer order

```
K051316 zoom (opaque)  ->  sprites  ->  tx tilemap
```

When video enable is clear the screen is filled with colour 0.

## ROM regions

| region | size | notes |
|---|---|---|
| maincpu | 256 kB | ROM_LOAD16_BYTE pairs |
| user1 | 512 kB | ROM_LOAD16_WORD_SWAP, mapped at 200000 |
| user2 | 128 kB | ROM_LOAD16_BYTE pairs, mapped at 2c0000 |
| audiocpu | 128 kB | 32 kB fixed + banked |
| chars | 768 kB | tx tiles |
| sprites | 512 kB | two interleaved halves |
| ymsnd | 128 kB | YM2608 deltaT samples |

About 2 MB in total, a comfortable SDRAM budget.

## Summary

The CPU and video side is largely assembly from parts already in the tree: the
memory map follows f1gp, the GGA is bit-identical, the ACIA is already stubbed
and the sprite hardware is simpler than f1grpr's. The two pieces of real work are
adapting `jt051316` to RAM-fed 4bpp and deciding what to do about the YM2608,
which is the only genuinely new chip and the only item with an external
dependency the romset does not satisfy.
