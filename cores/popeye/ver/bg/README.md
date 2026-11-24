# bg regression

Eight cases cover TPP2/TPP1/TNX1, both flips and TNX1 horizontal wrapping. Checks static scrolls, CPU display-time writes, nibble enables and pixel coordinates against a software oracle. The 2020 circuit comparison remains diagnostic because its gate effects differ.

Run `simunit.sh --run cores/popeye/ver/bg` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
