# colmix regression

Checks layer priority, palette bank and bootleg inversion for TPP2, TNX1 and bootleg wiring, including 4096 independent reference cases.

Run `simunit.sh --run cores/popeye/ver/colmix` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
