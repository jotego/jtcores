# JTMNYMNY FPGA core compatible with Zaccaria Z80µP hardware (Money Money)

Money Money is a 1983 arcade game by Zaccaria, running on their Z80µP board
set: a Z80 main board (1B1141 I/O board), a video board, a ROM board (1B11147,
with a PAL16L8 protection device) and the 1B11142 sound board. The player
drives an ice-cream van collecting money while avoiding the taxman and other
hazards. Vertical screen (ROT90).

The same hardware runs Jack Rabbit (1984), so this core targets both games.

# Supported Games

Games in MAME's zaccaria.cpp driver. All of them use the same machine
configuration, so a single core covers the whole driver:

Set       | Game                  | Year | Parent   | Hardware
----------|-----------------------|------|----------|--------------------
monymony  | Money Money (set 1)   | 1983 | -        | Zaccaria Z80µP
monymony2 | Money Money (set 2)   | 1983 | monymony | Zaccaria Z80µP
monymony3 | Money Money (set 3)   | 1983 | monymony | Zaccaria Z80µP
jackrabt  | Jack Rabbit (set 1)   | 1984 | -        | Zaccaria Z80µP
jackrabt2 | Jack Rabbit (set 2)   | 1984 | jackrabt | Zaccaria Z80µP
jackrabts | Jack Rabbit (special) | 1984 | jackrabt | Zaccaria Z80µP

# Hardware Summary

Element    | Details
-----------|------------------------------------------------------------
Main CPU   | Z80 @ 3.072 MHz (18.432 MHz XTAL / 6, verified on PCB)
Sound      | 1B11142 board: 2 x M6802, 2 x AY-3-8910, TMS5220 speech
Video      | 6.144 MHz pixel clock (18.432 MHz / 3), 384x264 total, 256x224 visible
GFX        | 8x8x3 tiles and 16x16x3 sprites from a shared 24kB region
Palette    | 512 colours (2 x 82S131 PROMs), 32x8 tile + 32x8 sprite pens
Protection | PAL16L8 at 1A on the ROM board (1B11147), read on data bits 4-7
Other      | i8255 PPI for inputs, LS259 latch, watchdog

Sprites come from two independent RAM sections drawn as three layers with
their own palettes and priorities. The tilemap has per-column scroll
(32 columns).

# Documentation

* `doc/zaccaria.cpp`: MAME driver this core is based on
