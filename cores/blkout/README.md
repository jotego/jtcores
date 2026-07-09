# Block Out

FPGA core for the Technos **Block Out** board (MAME `technos/blockout.cpp`,
1989, Technos Japan / California Dreams), plus the `agress` variant on the same
PCB (Palco, 1991).

## Status

Scaffold / WIP — **cfg only**. See [doc/STATUS.md](doc/STATUS.md) for the full
bring-up plan and hardware notes; the verbatim MAME driver is mirrored in
[doc/blockout.cpp](doc/blockout.cpp).

## Hardware in one line

A pure CPU-drawn **framebuffer** board: 68000 @ 10 MHz + Z80 @ 3.58 MHz +
YM2151 + OKI M6295. **No tilemap, no sprite engine, no gfx ROMs.** Graphics are
two byte-per-pixel 512×256 planes plus a 1bpp overlay, through an xBGR-444
palette. 320×240, ~57 Hz, horizontal.

## Donors

- **rastan** — 68k + Z80 + YM2151 spine on `JTFRAME_CLK24`.
- **volfied** — SDRAM-backed player-drawn bitmap framebuffer (`jtvolfied_fb.v`).
- **dd2** — YM2151 + OKI M6295 audio-channel pairing.

## Sets

`blockout` (parent), `blockout2`, `blockout3`, `blockoutj`, `agress`, `agressb`.
