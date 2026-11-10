# obj regression

Synthetic bitplanes check both fields/flips, sprite lookup, clipping and independently calculated pixels.

Run `simunit.sh --run cores/popeye/ver/obj` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
