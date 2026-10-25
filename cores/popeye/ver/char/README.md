# char regression

Checks both flips, tile/palette addressing, first-half-dot pipeline timing, overlapping CPU writes and the following field against independent tile bytes and the 2020 schematic circuit.

Run `simunit.sh --run cores/popeye/ver/char` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
