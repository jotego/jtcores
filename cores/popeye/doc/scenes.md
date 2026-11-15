# MAME scene capture

The maintained `~/mame/scene` worktree includes Popeye in `mkmame.sh`. Its
`tnx1_state` scene hook writes the 14340-byte payload described in the core
README. Work RAM is reordered into physical AD wiring. The CPU source table
is frozen at the DMA that produced the displayed image; FPGA DMA and derived
buffers still run normally after restore.

With `JOTEGO` set, first let `jtsim -s` establish each game's canonical scenes
link (or create that link explicitly before capturing). From the MAME scene
worktree, run with a locally available ROM directory:

```bash
timeout 5m ./mame popeye -rompath /path/to/roms -video none -sound none \
  -nothrottle -skip_gameinfo -dump_scenes 1000,2000 \
  -jtcore_path "$JTROOT/cores/popeye" -seconds_to_run 35
```

Repeat for `popeyej`, `popeyebl` and `skyskipr`. To capture a forced flip fixture,
use `-dump_scenes 2300 -autoboot_script
$JTROOT/cores/popeye/ver/integration/flip.lua`. This script intercepts AY port B
writes after frame 2100, keeping bit 0 set, and exits after frame 2400. It is a
rendering fixture, not a demonstration of naturally entering cocktail play.

Run `./ver/scene.sh popeye 1000` from the core folder. The helper explicitly
compares the final full frame even when ROM download causes the harness to
omit frame 1. Snapshot differences fail the comparison and produce the normal
CSV/difference image in the canonical scene directory.

The initial captures reproduce nonblank text and graphics across the board
families. They are not claimed to match MAME pixel-for-pixel: palette levels
differ (the RTL expands raw resistor bits linearly, MAME models its resistor
network), and some interlaced object/background pixels differ. Keep the raw
MAME snapshots and the failing comparisons for investigation; do not adjust
board timing or normalize the references to hide those differences.
