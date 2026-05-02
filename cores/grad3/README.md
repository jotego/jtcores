# JTGRAD3

FPGA implementation of **Gradius III** (Konami GX945, 1989), targeting the
MiSTer platform. Copyright (c) 2026 Fulvio Venturelli, distributed under the
GNU General Public License version 3 (see [LICENSE](../../LICENSE)).

Built on top of Jose Tejada's `jtframe` framework (also GPL-3). The core
reuses the existing Konami/Twin-68000 work where possible: `cores/tmnt` and
`cores/aliens` for the K052109/K051962/K051960 video family, `cores/twin16`
for the dual-MC68000 structure, and the existing `jt51`/`jt007232` sound
modules. The KiCad board schematics in `sch/grad3/` were traced from the real
PCB by **Ulf Skutnabba** (`@skutis77`). The Konami 052535 schematic in
`sch/052535/` is also credited to Ulf, with source imagery credited in-sheet to
Caius on jammaarcade.net.

## Status

- Supported set: `gradius3` (**Gradius III (World, version R)**).
- Verilator boots through RAM/ROM check, reaches attract/title, and runs
  in-game from the included `start.cab` input script.
- MiSTer hardware bring-up reaches gameplay with working controls and life-loss
  behavior.
- Original DSW1/DSW2/DSW3 DIP banks are exposed in the MiSTer OSD.
- The pause screen is one non-scrolling page.

Known issues:

- K051960 priority, zoom, and shadow still need broader gameplay coverage.
- The 052535 color/priority mixer is functional enough for bring-up but still
  provisional.
- Clone/split ROM variants have not been added.

## Repo Layout

| Path | What it is |
|---|---|
| `hdl/` | Gradius III-specific SystemVerilog modules |
| `cfg/` | `files.yaml`, `mem.yaml`, `macros.def`, `mame2mra.toml` jtframe inputs |
| `mist/` | Generated MiSTer SDRAM wrapper support |
| `sch/grad3/` | KiCad board schematic project traced by Ulf Skutnabba |
| `sch/052535/` | KiCad 052535 color/priority schematic credited to Ulf Skutnabba |
| `tools/` | `framewatch.py`, the live sim-frame viewer |
| `ver/gradius3/` | Verilator sim harness, input macro, generated frames, and dumps |

## Simulating

```bash
cd cores/grad3/ver/gradius3
./sim.sh -frame 5000 -load -inputs start.cab -fast
python3 ../../tools/framewatch.py
```

Set `GRAD3_ROM` or `MAME_ROM_PATH` if `rom/gradius3.rom` has not already been
generated.

## License

GPL-3-or-later. HDL reuse is from the GPL-3 jtcores tree and keeps the original
file headers where present. Schematic-derived implementation notes in this core
come from the Gradius III and 052535 KiCad traces credited above.
