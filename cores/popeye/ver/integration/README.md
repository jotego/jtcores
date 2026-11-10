# Private ROM diagnostics

These historical CPU diagnostics require a locally supplied, unprotected Popeye
ROM zip. Run `./main.sh <path-to-zip>`; do not add ROMs to git. The public
`../main` simunit uses generated firmware and covers all four board wirings,
RAM/DMA arbitration, I/O, NMI pause/rearm and the refresh watchdog without ROMs.

`flip.lua` is the MAME-only rendering fixture described in `../../doc/scenes.md`.
It forces AY port-B flip after frame 2100; it does not establish cocktail-game
input behavior.
