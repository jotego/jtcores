# sound regression

Normal and NOSOUND cases check PSG/DIP/flip I/O. Normal audio checks raw PSG tone periods before the moving-average filter, nonzero channel peaks and channel isolation.

Run `simunit.sh --run cores/popeye/ver/sound` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
