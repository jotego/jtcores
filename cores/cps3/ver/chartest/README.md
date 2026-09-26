# CPS3 Character DMA Dump Test

This is a Verilator regression for `jtcps3_chardma` using the real memory path:

- source reads through the `zipchar` cache lane
- destination command-list reads and tile-store writes through `tiles_wr`
- destination verification reads through the 128-bit graphics `tiles` cache lane
- `tiles_wr` flushes and invalidates `tiles` after each character DMA completion
- SDRAM service through `jtframe_burst_sdram`
- SDRAM contents backed by the JTFRAME Verilator `SDRAM` wrapper

The runner reads the MAME dump corpus from `$HOME/.mame/debug/sfiiin/char`, replays each character-DMA activation, and compares the written destination ranges against the corresponding dump BIN.

Run from repo root:

```bash
source setprj.sh >/dev/null
cd cores/cps3/ver/chartest
bash ./sim.sh
```

Useful options:

```bash
bash ./sim.sh --dump 1
bash ./sim.sh --limit 10
bash ./sim.sh --keep --dump 100
```
