# JTS18

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

SEGA System 18 compatible FPGA core by Jose Tejada.

This core is built around the mixed video architecture used by System 18 boards: the classic System 16-style tile and sprite pipeline is combined with a SEGA VDP path, and both outputs are merged in the final video mixer. The source tree contains both the RTL implementation and the reverse-engineered schematics produced during the hardware study.

## Released Games

The current `release/mra` set includes:

* Alien Storm (World, 2 Players)
* Bloxeed (Japan)
* Clutch Hitter (US)
* Clockwork Aquario (prototype)
* D. D. Crew (World, 3 Players)
* Desert Breaker (World)
* Hammer Away (Japan, prototype)
* Laser Ghost (World)
* Michael Jackson's Moonwalker (World)
* Shadow Dancer (World)
* Wally wo Sagase! (rev B, Japan, 2 players)

The MRA generator for this core is based on `cores/s18/cfg/mame2mra.toml`. That file also shows per-game button naming, volume defaults, ROM-region layout, and special handling for protection devices and MCU-backed sets. `pontoon` is intentionally skipped there because the machine description is incomplete.

## Hardware Notes

The core contains game-specific handling for several System 18 board styles present in the original hardware study and in the RTL configuration:

* 5874-style boards
* 5987-style boards
* 7525-style boards
* 5873-style boards
* 7248-style boards

The main board logic includes:

* Motorola 68000 main CPU path with FD1094 encrypted variants handled through the header/key flow
* Intel 8751 MCU support for the games that need it
* Dual-video composition: System 16 video plus VDP video
* Per-game cabinet and custom-I/O handling, including Moonwalker-specific input mapping, Laser Ghost light-gun support, and rotary/dial support used by Wally wo Sagase!

The sound board implementation follows the hardware documented in `sch/sound_a.kicad_sch` and the generated `s18.pdf` schematic package:

* Z80 sound CPU
* Two YM3438 FM chips
* RF5C68-compatible PCM playback implemented in `jtpcm568`
* PCM and FM mixed as on the PCB, with the right FM/PCM output path effectively unused on the original board

## Schematics And Research

The reverse-engineered schematics for this core are in `cores/s18/sch/`. A consolidated PDF is also distributed in JTBIN as `sch/s18.pdf`.

Relevant devices and blocks documented in the schematic set include:

* 315-5313 memory mapper and bus arbitration logic
* 315-5373, 315-5374 and 315-5375 video-sync and video-mixing related logic
* YM3438-based sound board
* Cabinet I/O variations such as the Laser Ghost gun hardware and the extra connector used by Moonwalker

The JT team's work on this core benefited from a real SEGA MoonWalker PCB loaned by `amoore2600`.

## Video Notes

System 18 analog video can be picky on some CRT monitors. As discussed in GitHub issue [#692](https://github.com/jotego/jtcores/issues/692), some displays are troubled by the current analog output timing. The main suspect is horizontal sync pulse length rather than vertical timing. The original sync captures and screenshots used for comparison are in the `doc/` folder, and the issue notes that testing longer HS variants is useful when checking monitor compatibility.

## Inputs

Per-game control labels are defined in `cores/s18/cfg/mame2mra.toml`. Highlights:

* Laser Ghost uses light-gun inputs plus a special weapon button
* Moonwalker uses the two-button `Shot` and `Dance` layout
* Shadow Dancer uses `Attack`, `Jump` and `Ninja Magic`
* Desert Breaker and Alien Storm use three-button action layouts
* Wally wo Sagase! uses confirm/select style controls together with rotary input handling in the core
