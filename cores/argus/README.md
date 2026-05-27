# Argus Core

FPGA implementation of **Argus** (NMK/Jaleco, 1986), targeting the MiSTer
platform through JTFRAME. Copyright (C) 2026 Fulvio Venturelli, distributed
under the GNU General Public License version 3 or later (see
[LICENSE](../../LICENSE)).

Built on top of Jose Tejada's `jtframe` framework (also GPL-3). This core is
being brought up from emulator references because no original schematics have
been found. The implementation is guided by MAME's Jaleco `argus.cpp` /
`argus_v.cpp` driver, the local MAME-compatible `argus.zip` ROM set, and live
Verilator comparison against MAME reference frames.

# Authors

Core implementation:

- Fulvio Venturelli

JTFRAME/JTCORES reusable infrastructure:

- Jose Tejada Gomez and contributors

Reference emulation:

- MAME Argus driver by Yochizo
- FinalBurn Neo Argus driver contributors

## Status

Supported MAME set for the jtframe config:

- `argus`: **Argus**.

Related MAME sets `valtric`, `butasan`, and `butasanj` share parts of the same
driver, but they are out of scope for this first hardware pass.

Verilator board simulation currently boots the real `argus` ROM image, transfers
ROM by frame 12, accepts the repeatable coin/start input script, and reaches the
title/credit path with recognizable background, logo, text, palette, and sprite
output.

Current implemented video work includes:

- MAME-described BG0 VROM metadata lookup cached with `jtframe_dual_ram`
- BG0 palette intensity add/subtract path
- Jaleco blend-device sprite alpha nibble handling
- Argus packed-MSB 4bpp tile conversion for BG, text, and sprites
- 256x224 active timing aligned to the MAME visible area, then rotated by
  JTFRAME core-mod for the vertical cabinet view
- live frame viewer inherited from the Operation Wolf/Rainbow Islands workflow

Known issues:

- Ship departing smoke animation is corrupted.
- Background becomes black after the supernova.
- Scroll stuttering remains; movement is not yet as smooth as MAME/arcade.
- Cursor is offset upward on the score name entry screen.

MAME itself marks the Argus driver as imperfect graphics, so each visual fix
should be checked against a saved MAME frame rather than assumed correct.

## Repo Layout

| Path | What it is |
|---|---|
| `hdl/` | Verilog - Argus-specific CPU, video, palette, sprite, and sound glue |
| `mist/` | Generated MiSTer SDRAM wrapper and memory port includes |
| `cfg/` | `files.yaml`, `mem.yaml`, `macros.def`, MRA, DIP, and pause text inputs |
| `doc/` | Local MAME/FBNeo reference snapshots |
| `ver/argus/` | Verilator sim wrapper and repeatable input script |
| `tools/` | `framewatch.py`, the live browser frame viewer |

## Reused Blocks

The Argus-specific RTL is intentionally limited to address decoding, BG0 VROM
lookup, palette/intensity rules, sprite table scanning, and board glue. Reused
JTFRAME/JTCORES blocks include:

- Z80 CPUs: `jtframe_z80_romwait`
- YM2203: `jt03`
- video timing: `jtframe_vtimer`
- tile layers: `jtframe_scroll`
- sprite drawing: `jtframe_objdraw`
- local RAMs: `jtframe_dual_ram` and `jtframe_dual_ram16`

## Building & Simulating

Generate the MRA and ROM payloads from a MAME-compatible `argus.zip`:

```bash
cd /path/to/jtcores
JTROOT=$PWD \
JTFRAME=$PWD/modules/jtframe \
CORES=$PWD/cores \
MODULES=$PWD/modules \
JTBIN=$PWD/release \
PATH=$PWD/modules/jtframe/bin:$PATH \
modules/jtframe/bin/jtframe mra argus --setname argus --path /path/to/roms
```

Expected local outputs:

```text
release/mra/Argus.mra
rom/argus.rom
rom/argus.dip
rom/argus.mod
```

The local sim wrapper sets up the JTFRAME environment, refreshes
`rom/argus.rom`/`rom/argus.mod` when needed, and invokes `jtsim`:

```bash
cd cores/argus/ver/argus
ARGUS_ROM=/path/to/roms ./sim.sh -frame 300 -fast
```

For a repeatable credit/start run:

```bash
cd cores/argus/ver/argus
ARGUS_ROM=/path/to/roms ./sim.sh -frame 300 -fast -inputs start_game.cab
```

For a visual frame capture run:

```bash
cd cores/argus/ver/argus
JTFRAME_SIM_VIDEO_EVERY=90 ARGUS_ROM=/path/to/roms ./sim.sh -frame 91 -fast
```

The live frame viewer can stay open across sim runs:

```bash
python3 cores/argus/tools/framewatch.py --port 8766
```

Open `http://127.0.0.1:8766/` and leave it running while the sim writes frames
under `ver/argus/frames/`.

## Reference Sources

- MAME Jaleco driver: `doc/argus.cpp`
- MAME Jaleco video driver: `doc/argus_v.cpp`
- MAME state header: `doc/argus.h`
- FBNeo reference driver: `doc/fbneo_d_argus.cpp`

Upstream references:

- <https://github.com/mamedev/mame/blob/master/src/mame/jaleco/argus.cpp>
- <https://github.com/mamedev/mame/blob/master/src/mame/jaleco/argus_v.cpp>
- <https://github.com/finalburnneo/FBNeo/blob/master/src/burn/drv/pre90s/d_argus.cpp>

## License

GPL-3-or-later. Every HDL file carries its own attribution header where
applicable. The implementation uses JTFRAME/JTCORES reusable modules by Jose
Tejada and contributors, plus behavioural details derived from MAME and FBNeo
reference drivers. See [LICENSE](../../LICENSE) and [AUTHORS.md](AUTHORS.md).
