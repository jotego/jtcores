# YM7101 current-source smoke test

This `simunit` checks the YM7101 in both `PASSIVE=0` and `PASSIVE=1` builds.
It exercises the normal clock phases, legal 68000 MMR and status accesses,
two sequential VRAM writes with autoincrement and CPU readback, and verifies
that RGB stays black while the external raster is blank. In passive mode it
also checks YS remains low before acquisition.

The test uses only the current YM7101, raster tracker, YM library, and VRAM
model from `gather.f`. It does not depend on a historical checkout and does
not wait for frame acquisition. Run it with:

```sh
source modules/jtframe/bin/setprj.sh
simunit.sh --run cores/s18/ver/ym7101_passive
```

The full external-raster acquisition and frame comparison against the
identified historical YM7101 source is maintained separately in
[`../ym7101_render`](../ym7101_render/README.md). That timed Verilator runner
is not part of this short CI smoke test.
