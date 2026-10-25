# dma regression

Checks bus request/acknowledge, full scrambled RAM addresses, descriptor strobes and background fetches against the pinned TTL circuit.

Run `simunit.sh --run cores/popeye/ver/dma` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
