# JTARGUS

FPGA implementation work-in-progress for **Argus** (NMK/Jaleco, 1986).

This core is being brought up from MAME and FBNeo source references because no
schematics have been found. Reusable blocks are taken from JTFRAME/JTCORES:

- Z80 CPUs: `jtframe_z80_romwait`
- YM2203: `jt03`
- video timing: `jtframe_vtimer`
- tile layers: `jtframe_scroll` and `jtframe_8x8x4_packed_msb`
- sprite drawing: `jtframe_objdraw`
- local RAMs: `jtframe_dual_ram` and `jtframe_dual_ram16`

The Argus-specific RTL is limited to address decoding, the MAME-described VROM
BG0 lookup, palette/intensity rules, and sprite table scanning.

## References

Source:
https://github.com/mamedev/mame/blob/master/src/mame/jaleco/argus.cpp

Source:
https://github.com/mamedev/mame/blob/master/src/mame/jaleco/argus_v.cpp

Source:
https://github.com/finalburnneo/FBNeo/blob/master/src/burn/drv/pre90s/d_argus.cpp

Local copies:

- `doc/argus.cpp`
- `doc/argus_v.cpp`
- `doc/argus.h`
- `doc/fbneo_d_argus.cpp`

## Bring-Up Notes

- Current target set: `argus`.
- MRA generation overrides Argus to vertical clockwise orientation so JTFRAME's
  core-mod rotation presents the vertical cabinet image upright.
- `jtframe mem argus`, `jtframe files plain argus --local --rel`, and MRA/ROM
  generation for `argus` have been smoke-tested using
  `/Users/fulvio/Downloads/argus.zip`.
- `cores/argus/ver/argus/sim.sh -lint` completes cleanly through `jtsim`.
- `cores/argus/ver/argus/sim.sh -frame 80 -fast` transfers the 640 KiB ROM
  image by frame 12 and reports 54.26 Hz. The CPU now fetches from ROM and
  writes text RAM; the frame capture shows early blue boot/title text.
- `cores/argus/ver/argus/sim.sh -frame 260 -fast -inputs start_game.cab`
  drives the repeatable coin/start input file and produces fresh viewer frames
  through the title/credit path.
- `cores/argus/tools/framewatch.py` serves sim frames, defaulting to port 8766.
- Related games `valtric`, `butasan`, and `butasanj` share parts of the MAME
  driver but are out of scope for the first hardware pass.
- MAME marks graphics as imperfect and documents half-transparent colors; this
  core implements the BG0 palette intensity add/subtract path and the sprite
  blend nibble used by MAME's Jaleco blend device. BG0 now decodes the
  MAME-described VROM map through a small `jtframe_dual_ram` metadata cache
  instead of racing four SDRAM reads at each tile edge.
- MAME uses a 5 MHz Z80 clock for Argus even though the driver comment says the
  original was 4 MHz; this core follows MAME for now.
