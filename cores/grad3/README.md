# JTGRAD3

FPGA implementation of Gradius III (Konami GX945, 1989) for MiSTer, built on
jtframe.

## Status

- Supported set: `gradius3` (Gradius III, World, version R).
- Boots through RAM/ROM check, reaches attract/title, and runs in-game.
- Original DSW1/DSW2/DSW3 DIP banks are exposed in the OSD.
- Schematics are included under `sch/`.

## Credits

- HDL framework and shared core modules: Jose Tejada Gomez and jtcores
  contributors.
- Gradius III and 052535 KiCad schematics: Ulf Skutnabba.
- 052535 source imagery credit is preserved in the schematic sheets.
