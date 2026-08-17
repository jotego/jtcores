# JTTAITOX — Taito X System FPGA core

Core by Andrea Bogazzi, built on JTFRAME by Jose Tejada (jotego, @topapate).

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github sponsors](https://github.com/sponsors/asturur)

## Disclaimer

This work is for research and historical purposes. This work itself does not
contain copyrighted software and should not be packed or distributed with
illegal copies of the copyright protected software.

## Hardware

The Taito X System is a Seta-designed board sold to Taito and licensed on to
East Technology. Three variants exist and the differences between the games
follow the board, not the title:

| Board | Built by | Games |
|---|---|---|
| P0-039A | Taito Corp. | Superman |
| P0-051A | Taito Corp. | Twin Hawk, Daisenpu |
| P0-057A | East Technology | Gigandes, Last Striker, Balloon Brothers |

A single 16 MHz oscillator feeds everything — confirmed on both the Superman
schematic (drawing W5100307A, sheet 3) and the board photo in `doc/`. The
X1-001 divides it down and emits the taps `CK`, `CK3`, `H1`, `H2`, `H3`; the
Z80 clock is `H1` and the 68000 is strapped to `CK` through a jumper box.

| Chip | Role | Clock |
|---|---|---|
| Motorola 68000 | Main CPU | 16 / 2 = 8 MHz |
| Zilog Z80 | Sound CPU | 16 / 4 = 4 MHz |
| Yamaha YM2610 | FM + ADPCM-A + Delta-T | 16 / 2 = 8 MHz |
| Yamaha YM2151 | FM, P0-051A only | 16 / 4 = 4 MHz |
| Seta X1-001 | Sprite controller, video timing, OBJ-RAM master | 16 MHz |
| Seta X1-002 | Sprite renderer, holds spritectrl / spriteylow | 16 MHz |
| Seta X1-003 | RGB DAC, drives three R-2R ladders | — |
| Seta X1-006 | 68k ↔ palette bridge | — |
| Seta X1-004 / X1-007 | I/O | — |
| Taito TC0140SYT | 68k ↔ Z80 sound comms | — |
| Taito PC060HA | same silicon, P0-051A only | — |
| Taito TC0030CMD | C-chip, uPD78C11 MCU, P0-039A only | 16 / 2 = 8 MHz |

There is **no tilemap chip**. MAME's single gfxdecode entry is "sprites &
playfield", and the playfield is the X1-001's background *column* mode.

## Supported sets

| Setname | Game | Board | State |
|---|---|---|---|
| `superman` `supermanu` `supermanj` | Superman | P0-039A | boots, renders |
| `gigandes` `gigandesa` | Gigandes | P0-057A | boots, renders |
| `ballbros` | Balloon Brothers | P0-057A | boots, renders |
| `kyustrkr` | Last Striker | P0-057A | boots, renders |
| `daisenpu` `twinhawk` `twinhawku` | Daisenpu / Twin Hawk | P0-051A | not enabled |

Daisenpu and Twin Hawk are skipped in `cfg/mame2mra.toml` until the YM2151
path lands.

## Status

**Working**

- 68000 boot verified against MAME: the FPGA fetch stream contains every one
  of MAME's 1464 distinct PCs on Superman, with no divergence.
- TC0030CMD C-chip runs the real MCU (`modules/jttc0030cmd`) and clears the
  signature handshake with no HLE anywhere.
- Sprites and the background column layer render. Superman's title screen is
  byte-identical to a MAME screenshot — 0 of 92160 pixels differ.
- Gigandes exercises the paths Superman never touches: the direct input port
  at `900000`, the level-2 interrupt, and the ADPCM-B SDRAM bank.
- Sound: YM2610 and the TC0140SYT play correctly on hardware.

**Not working**

- **Sprite alignment is unverified** beyond the static title screen.
- **Scene replay does not exist yet.** `ver/superman/mame_scripts/dump_burst.lua`
  captures 20 MAME scenes 300 frames apart (palette, spriteylow, spritectrl,
  OBJ-RAM, plus `screen.png`), but the FPGA side still needs `rest2bin.sh`,
  `simfile:` bindings in `mem.yaml` and a NOMAIN replay branch.
- **No hardware build has been attempted**; timing closure is unknown.

## Video timing

The X1-001 divides the 16 MHz oscillator to an 8 MHz dot clock over a
512x272 grid: 15.625 kHz horizontal, 57.4449 Hz vertical, matching the
driver's 57.43. MAME's `set_size(52*8, 32*8)` is the usual Seta
approximation — at MAME's own refresh it implies a 6.117 MHz dot clock and a
14.7 kHz line rate, which no JAMMA monitor would lock to.

The H and V totals are **not** derivable from the schematic: the dividers are
inside the X1-001 die and the board carries no counter chain. The only
measured figures in the MAME driver (58 Hz / 15.22 kHz, line 217) belong to a
P0-057A board, not to Superman, whose value has no measurement behind it.
These numbers are due a scope check on real hardware.

## MRA header

One byte, three bits, carrying the board type only:

| bit | name | sets |
|---|---|---|
| 0[0] | `p039a` | superman ×3 |
| 0[1] | `p051a` | daisenpu, twinhawk ×2 |
| 0[2] | `p057a` | gigandes ×2, ballbros, kyustrkr |

Everything else is derived in HDL, because it all follows the board split:
the C-chip, the direct input port (`~p039a`), the interrupt level (`~p039a`)
and the sprite Y offset (`p057a ? -0x0a : -0x12`).

## Documentation

`doc/` holds primary sources only — the MAME driver and device sources
(`taito_x.cpp`, `seta001.cpp`, `taitosnd.cpp`, `taitocchip.cpp`) and photos of
the P0-039A and P0-057a board. The Superman schematics are the maker's IP and are kept
out of the repo.
