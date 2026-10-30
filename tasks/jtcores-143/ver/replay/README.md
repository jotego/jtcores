# Hardware raw replay

Replays a saved four-pin capture through the RTL Yamaha sampler and compares every
full word, including dummy bits, with the independent Go decoder. Raw files remain
local artifacts. Default input is `artifacts/high.cap`; override with the absolute
path in `YAMAHA_REPLAY`. Requires the file and a sourced root `setprj.sh`.

```
bash tasks/jtcores-143/ver/replay/sim.sh [--keep] [CAPTURE]
```

This is deliberately a standalone Verilator simulation: it needs uncommitted
hardware recordings, so it is not a simunit/CI test. `--keep` enables `test.fst`.
