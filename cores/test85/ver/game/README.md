# TEST85 game simulation

This folder is the core-local ROM-less `jtsim` entry point for TEST85.

Run from the repository root with:

```bash
source setprj.sh >/dev/null && cd cores/test85/ver/game && jtsim -mister -video 3 -q
```

The `SIMULATION` monitor in `jttest85_game.v` checks that the CPU writes `TEST85`, writes `PASS`, and exercises cache write/read/flush handshakes by the end of the first active frame.
