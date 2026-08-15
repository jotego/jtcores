# JTTAITOX — Taito-X (Taito 1988) FPGA core

By Jose Tejada (aka jotego — @topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)

## Hardware

This core targets the **Taito X System** PCB used by Superman in 1988
(Taito P0-039A, ROM-set prefix `b61`). The board was Seta-built and runs:

| Chip | Role | Clock |
|---|---|---|
| Motorola 68000 | Main CPU | 16 MHz / 2 = 8 MHz |
| Zilog Z80 | Sound CPU | 16 MHz / 4 = 4 MHz |
| Yamaha YM2610 | FM + ADPCM-A samples | 16 MHz / 2 = 8 MHz |
| Seta X1-001A / X1-002A | Sprites + tilemap | 16 MHz |
| Seta X1-006 / X1-007 | Palette / DAC | — |
| Seta X1-004 | I/O | — |
| Taito TC0140SYT | 68k↔Z80 sound comms | — |
| Taito C-chip (uPD78C11) | Security + cabinet I/O | 16 MHz / 2 = 8 MHz |

## Supported sets

Only Superman is supported (this core's name reflects that). The cousin
games on the same hardware — Ballbros, Gigandes, Last Striker, Twin Hawk
— may be added in a future re-spin called `taitox`.

| Setname | Notes |
|---|---|
| `superman`   | World |
| `supermanu`  | US |
| `supermanj`  | Japan |

## Status

See `doc/STATUS.md` for current bring-up state, what's verified against
MAME's reference, and the per-block roadmap. **Short version:** 68k +
sound + framework all elaborate and sim cleanly; the C-chip (uPD78C11
MCU) is the remaining major piece blocking a full boot.

## Documentation

The cores have been developed by combining information in the MAME
drivers (mirrored in `doc/taito_x.cpp` and `doc/taitosnd.cpp`) with
public references for the Seta X1-001 chip (`doc/seta_x1-001.md`).
The F2 MiSTer core (GPLv2) was used as a structural reference for the
TC0140SYT — our implementation is a clean rewrite in JT style, not a
verbatim port; see `doc/tc0140syt.sv.ref` for the reference RTL.

## Build & sim

```bash
# Verilator sim from the repo root (requires jotego/simulator Docker image
# and a Superman ROM at ~/.mame/roms/superman.zip):
FRAMES=80 ./sim-core.sh superman superman

# Lint:
docker run --rm --platform linux/amd64 --network host \
    -v "$(pwd)":/jtcores jotego/linter \
    /jtcores/modules/jtframe/bin/lint-all.sh
```
