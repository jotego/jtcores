# timing regression

Checks both flips, resets, 513 half-lines, counters, blanking and independent PROM decode against the schematic reference.

Run `simunit.sh --run cores/popeye/ver/timing` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
