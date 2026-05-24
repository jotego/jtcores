# TEST85 game simulation

This folder is the core-local `jtsim` entry point for TEST85.

Run from the repository root with:

```bash
source setprj.sh >/dev/null && jtframe mra test85
source setprj.sh >/dev/null && cd cores/test85/ver/game && jtsim -mister -setname test85 -video 90 -q
```

The `SIMULATION` monitor in `jttest85_game.v` checks that the CPU writes `TEST85`, writes `PASS CACHE`, exercises cache write/read/flush handshakes by the end of the first active frame, and then writes `PASS ROM` after validating the downloaded SDRAM payload.
