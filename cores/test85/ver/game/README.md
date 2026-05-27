# TEST85 game simulation

This folder is the core-local `jtsim` entry point for TEST85.

Run from the repository root with:

```bash
source setprj.sh >/dev/null && jtframe mra test85
source setprj.sh >/dev/null && cd cores/test85/ver/game && jtsim -mister -setname test85 -video 30 -q
```

The `SIMULATION` monitor in `jttest85_game.v` checks that the CPU writes `TEST85`, validates the downloaded SDRAM payload first with `PASS ROM`, starts the destructive `FILL` phase, and continues issuing cache write/flush traffic during the 30-frame validation window. The full 64MB fill, `FILL DONE`, and later random tag checks take longer than the smoke run.
