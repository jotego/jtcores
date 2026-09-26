# CPS3 Palette DMA Dump Test

This is a Verilator regression for `jtcps3_paldma` using the real memory path:

- source reads through `jtframe_cache_mux`
- SDRAM service through `jtframe_burst_sdram`
- palette writes into `jtframe_dual_ram16`
- SDRAM contents backed by the JTFRAME Verilator `SDRAMModel`

The runner reads the MAME dump corpus from `$HOME/.mame/debug/sfiiin/pal`, replays each DMA transaction, and compares the written palette words at MAME's destination-XOR indices against the corresponding dump BIN after applying the programmed fade.

Run from repo root:

```bash
source setprj.sh >/dev/null
cd cores/cps3/ver/paltest
bash ./sim.sh
```

Useful options:

```bash
bash ./sim.sh --dump 1
bash ./sim.sh --limit 10
bash ./sim.sh --keep --dump 100
```
