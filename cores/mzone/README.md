# JTMZONE — Mega Zone FPGA core

FPGA implementation of Konami's Mega Zone (1983, GX319), developed by
Ulf Skutnabba using the JTFRAME framework.

The core was developed using an original Mega Zone PCB, existing schematics,
and new schematics drawn during the hardware investigation. Custom ROM code
run through PicoROM was used to test hardware behaviour. The KiCad schematics
are in [sch/](sch/).

MAME was used for quick code verification and cross-checks. Final verification
is against the original PCB.

## Status

The core is under development for SiDi128, MiSTer FPGA, and Analogue Pocket.

| Platform | Hardware testing |
| --- | --- |
| SiDi128 | Tested on hardware |
| MiSTer FPGA | Tested on hardware |
| Analogue Pocket | Not tested; a device is needed for hardware validation |

SiDi128 HDMI alignment remains to be checked.

Builds for all three platforms passed JTCORE's timing checks with Quartus Prime
Lite 20.1 and fitter seed 1. MiSTer and Pocket reports include unconstrained
paths, and shared platform clock warnings remain under review. These build
results do not establish complete timing closure or replace hardware testing.

## Video options and PCB findings

Mega Zone uses a vertically oriented display. The **Video width** DIP-switch
option selects between the default 288-pixel width and the PCB's original
287-pixel non-flipped visible width. In flipped mode, the original-width setting
retains 288 pixels.

Comparison with the original PCB identified incorrect sprite positions and
tile-layer offsets in MAME. The PCB also gives sprites priority over tiles
at horizontal position 47 when a sprite occupies that position.

See [doc/timing.md](doc/timing.md) for counter mappings and object hardware details.

## Hardware

- Konami-1/6809-compatible main CPU.
- Z80 sound and input CPU, with shared RAM.
- 8039 CPU for DAC audio.
- AY-3-8910 programmable sound generator.
- Scrolling character layer, fixed character layer, sprites, and PROM palettes.

## Credits

- **Ulf Skutnabba** — Mega Zone core development and schematic work.
- **Ace9921** — Author of the `k501.v` Verilog module reused in this core.
- **JOTEGO and jtcores contributors** — JTFRAME and shared FPGA components.
- **MAME contributors** — Mega Zone emulation and hardware documentation used
  as reference material.
