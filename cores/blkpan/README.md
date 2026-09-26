# JTBLKPAN — Black Panther (Konami GX604, 1987)

MAME implements the video for this game and for Nemesis with **one shared
`gx400_base_state`** (`nemesis_v.cpp`, 292 lines, inherited unmodified by both
`gx400_state` and `salamand_state`), and both use the same `gfx_nemesis`
RAM-tile layouts and the same `set_screen_raw_params`. So the GFX board is the
same silicon, and this core reuses it directly from `cores/nemesis/hdl`:

- `GX400A_VIDEO` and the K005290/91/92/93/94/95 custom ICs
- `gx400_priority_handler`, `gx400_cen` and the `util/` primitives

That work is by **LMN-san, OScherler and Raki** (GPLv3), imported from
<https://github.com/GX400-Friends/gx400-src>. Support them:
patreon.com/ikamusume · ko-fi.com/lmnsan · ko-fi.com/oscherler

## What is specific to this board

| | Nemesis (GX400) | Black Panther (GX604) |
|---|---|---|
| Sound CPU | Z80 @ 1.7897725 MHz | Z80 @ 3.579545 MHz |
| Sound chips | 2x AY-3-8910 + K005289 | **YM2151 + K007232**, stereo |
| Palette | resistor-ladder LUT, 8-bit guns | **plain xBGR_555**, 5-bit guns |
| Interrupt | IRQ1 on vblank | **IRQ2** on vblank |
| Z80 IRQ source | outlatch bit 2 | **outlatch bit 3** |
| Inputs | active low | **active HIGH** (`IP_ACTIVE_HIGH`) |
| gfx ROMs | none (64kB charram) | none (64kB charram) |

`jtblkpan_main.v`, `jtblkpan_addr_dec.v` and `jtblkpan_snd.v` are new.

## Gotchas worth keeping

- **colorram and videoram are swapped.** Black Panther puts colorram in the
  lower block (`0x100000/0x101000`) and videoram in the upper
  (`0x102000/0x103000`). Nemesis *and* Salamander both do the reverse. Getting
  VCS1/VCS2 backwards renders plausible-looking garbage.
- `GX400A_VIDEO` masks each RAM's address internally (`i_addr[11:1]`,
  `[12:1]`, `[15:2]`), so the region base addresses do not have to match
  Nemesis — the chip select does the region decode.
- The `intlatch` byte is bit-swapped by MAME before the shared handler
  (`bitswap<8>(d,7,6,5,4,3,2,0,1)`), i.e. irq1/irq2 are exchanged relative to
  Salamander: b0 = IRQ2 enable, b1 = IRQ1 enable, b2 = flip X, b3 = flip Y.
- `maincpu` needs `width=16, reverse=true` in `mame2mra.toml`; without it the
  68000 reads its reset vector byte-swapped and double-faults on an odd stack
  pointer. MAME also leaves a hole at `0x20000-0x3FFFF`, which the generated
  MRA fills with `<part repeat="0x20000"> FF</part>`.
- The address decoder is transcribed from MAME, not from schematics.

## Status

Boots and renders. Palette channel wiring is still wrong (see git log / open issues).
