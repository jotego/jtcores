# prot regression

Checks all eight shifts and 256 old-byte values, synthetic new bytes, held strobes, status reads, reset and deselected writes (2048 shift checks).

Run `simunit.sh --run cores/popeye/ver/prot` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
