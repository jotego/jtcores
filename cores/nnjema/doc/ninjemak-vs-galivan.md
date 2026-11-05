# Ninja Emaki (ninjemak) — hardware notes vs. galivan.cpp family

Source: MAME `src/mame/nichibutsu/galivan.cpp` (copy in this folder).

## Games supported by the MAME driver

| Game | Year | Machine config | Notes |
|---|---|---|---|
| galivan / galivan2 / galivan3 | 1985 | `galivan` | Cosmo Police Galivan, 3 revisions |
| dangar / dangara | 1986/87 | `galivan` | Ufo Robo Dangar |
| dangarj | 1986 | `dangarj` | galivan + NB1412M2 protection chip |
| dangarb / dangarbt | 1986 | `galivan` | bootlegs, protection patched |
| ninjemak | 1986 | `ninjemak` | Ninja Emaki (US) — target |
| ninjemat | 1986 | `galivan` (!) | Tecfri license, NOT_WORKING |
| youma / youma2 | 1986 | `ninjemak` | Youma Ninpou Chou = Japan Ninja Emaki |
| youmab / youmab2 | 1986 | `youmab` | bootlegs w/o NB1414M4, serial scroll hack, NOT_WORKING |

A ninjemak core covers youma/youma2 as well. galivan/dangar share ~80% of the
hardware and could be added later.

## Shared hardware (galivan == ninjemak)

- Main Z80B @ 6 MHz (12 MHz/2), IRQ at vblank, ack'd by IO write
- Sound Z80A @ 4 MHz (8 MHz/2): YM3526 + 2x R2R DACs (io ports 2/3),
  latch read at 6 / clear at 4, periodic IRQ @ 8 MHz/2/512 ~ 7.8 kHz
- Audio filters identical to the armedf.cpp boards (see driver comment)
- Video: 12 MHz/2 pixel clock, 384x263 total, 59.4 Hz, HS 15.6242 kHz
- Buffered sprite RAM, copied at vblank (DMA)
- Background tilemap stored in ROM (`bgtiles` 0x8000: 0x4000 code +
  0x4000 attr) — no BG VRAM, only scroll registers
- Sprite format: 4 bytes/sprite, 16x16x4bpp, sprite-palette-bank PROM +
  sprite LUT PROM; RGB 4-bit color PROMs

## Ninjemak-specific differences

1. **NB1414M4 custom chip** — text layer is not CPU-written. CPU places a
   command at videoram[0..1] + params at [2..0x11], writes port 0x86, the
   1414M4 blits text/attr into text RAM from its own 16 kB data ROM
   (`ninjemak.5`) and outputs the BG scroll values. MAME simulates it
   (`nb1414m4.cpp`, MACHINE_UNEMULATED_PROTECTION). The va7deo ArmedF core
   has a working RTL FSM (`armedf.sv:837+`, `nb1414m4_*`) — best reference;
   terraf/kozure/legion/cclimbr2 use the same chip.
2. **IO map**: ports 0x80-0x87 (inputs read / regs write overlapped) vs
   galivan 0x00-0x05 + 0x40-0x47; extra SERVICE input port; vblank ack at
   0x87 also triggers the 1414M4 vblank.
3. **Scroll**: 16-bit scrollx/scrolly produced by the 1414M4 exec, not by
   direct ports; no galivan layer-enable bits (5-7) — bit 4 of the gfxbank
   port is a display-disable instead.
4. **ROM banking**: 4 banks of 8 kB at 0xc000 (bits 7:6 of port 0x80) vs
   galivan 2 banks (bit 7). Main CPU region 0x18000 vs 0x14000.
5. **Sizes**: chars 0x8000 (2 hi code bits in attr) vs 0x4000; sprites
   0x20000 (code bank `(attr&0x06)<<7`) vs 0x10000; sprite RAM 0x200
   (128 sprites) vs 0x100.
6. **BG tilemap geometry**: 512x32 tiles, column scan (vs 128x128 row scan);
   different BG attr->color mapping: `((attr&0x60)>>3)|((attr&0x0c)>>2)`.
   Char palette decode is direct 0-0x7f (8 palettes) vs galivan banked.
7. Fixed layer order: bg -> sprites -> text on top. No priority bits.

## Memory / IO map (ninjemak)

Main CPU:
- 0000-bfff ROM
- c000-dfff banked ROM (4 x 8kB)
- d800-dfff videoram write-through (text RAM, 0x400 code + 0x400 attr)
- e000-e1ff sprite RAM (buffered)
- e200-ffff work RAM

IO (global mask 0xff):
- 80 r:P1        w:gfxbank (0-1 coin counters, 2 flip, 4 disp disable, 7:6 bank)
- 81 r:P2
- 82 r:SYSTEM
- 83 r:SERVICE
- 84 r:DSW1
- 85 r:DSW2      w:sound_command ((data&0x7f)<<1 | 1)
- 86 w:blit trigger (NB1414M4 exec)
- 87 w:vblank ack + NB1414M4 vblank trigger

Sound CPU: 0000-bfff ROM, c000-c7ff RAM.
Sound IO: 00-01 YM3526, 02 DAC1, 03 DAC2, 04 latch clear, 06 latch read.

## ROM regions (ninjemak set)

| Region | Size | Files |
|---|---|---|
| maincpu | 0x18000 | ninjemak.1 (8000), .2 (4000), .3 @10000 (8000, 4 banks) |
| audiocpu | 0xc000 | ninjemak.12 (4000), .13 (8000) |
| chars | 0x8000 | ninjemak.4 |
| tiles | 0x20000 | ninjemak.8/.9/.10/.11 |
| sprites | 0x20000 | ninjemak.16/.17/.14/.15 |
| bgtiles | 0x8000 | ninjemak.7 + ninjemak.6 (map in ROM) |
| nb1414m4 | 0x4000 | ninjemak.5 (text data for the custom chip) |
| proms | 0x400 | pr1/pr2/pr3 (RGB) + yncp-2d (sprite LUT) |
| sprpalbank_prom | 0x100 | yncp-7f |

## Reference repos (cloned in ~/develop)

- `~/develop/ArmedF` — va7deo 68k Nichibutsu core with RTL NB1414M4
- `~/develop/TerraCresta` — va7deo 68k Nichibutsu core with RTL NB1412M2
  (only relevant if dangarj is ever added)

## Effort shape for a jtcores core

- Main Z80 + banking + IO decode: standard jtframe
- Sound: jtframe Z80 + jtopl (YM3526) + two latched DACs
- Video: 8x8 char layer, ROM-backed 16x16 BG (512x32 col scan),
  128-sprite buffered engine with two lookup PROMs
- NB1414M4: the only new block — port the ArmedF FSM (note the ninjemak
  command divergence in MAME `blit_trigger_w`) fed by ninjemak.5
- MRA/toml for ninjemak + youma/youma2

## Online references (searched 2026-09)

- No factory schematics for YN-1/YN-2 (ninjemak) or GV-1412 (galivan) are
  archived online. No NB1414M4 datasheet exists (undocumented custom).
- No silicon decap: furrtek's SiliconRE has no Nichibutsu folder.
- Ninja Emaki conversion-kit service manual (pinouts/wiring, not schematics):
  https://manualzz.com/doc/11797968/
- MiSTer-devel/Arcade-Galivan_MiSTer — Z80 GV-1412 core (galivan/dangar):
  full CPU/video/sound chain, no 1414M4. Cloned in ~/develop.
- va7deo/ArmedF — RTL NB1414M4 FSM (armedf.sv). Cloned in ~/develop.
- MAME nb1414m4.cpp — behavioral simulation, de facto chip documentation.
