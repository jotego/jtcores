# JTCNINJA — Data East "Caveman Ninja" / Joe & Mac

FPGA reimplementation of Data East's DECO 16-bit hardware
(MAME driver `dataeast/cninja.cpp`). Bring-up target: **cninja** (World
parent). `joemac` (Japan) and the rest of the cninja.cpp family are
follow-ups once the protection and video chips are correct.

This is an **early scaffold** — see [doc/STATUS.md](doc/STATUS.md) for the
hardware map, the build order, and the per-block checklist.

## Hardware summary

| Block      | Part                       | Clock           |
|------------|----------------------------|-----------------|
| Main CPU   | MC68000                    | 24MHz/2 = 12MHz |
| Sound CPU  | HuC6280 (H6280)            | 32.22MHz/8      |
| FM 1       | YM2203 (OPN+PSG)           | 32.22MHz/8      |
| FM 2       | YM2151 (OPM)               | 32.22MHz/9      |
| ADPCM      | 2× MSM6295                 | /32 and /16     |
| Tilemaps   | 2× DECO 16IC               | —               |
| Sprites    | DECO sprite (MXC06 family) | —               |
| Protection | **DECO 104** (146 family)  | —               |
| Video      | 256×240, ~58.2Hz, 6MHz pxl | —               |

## Reuse from the existing DEC0 core (`cores/cop`)

`cop` implements the predecessor `dec0.cpp` hardware and shares the sprite
engine (MXC06), the tilemap lineage (BAC06 → DECO 16IC), the palette/priority
mixer, and the H6280. The genuinely new piece is the **DECO 104 protection**
(`hdl/jtcninja_deco104.v`), ported from `doc/deco146.cpp` + `doc/deco104.cpp`.
