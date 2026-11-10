# objbuf regression

Runs the complete descriptor/line schedule with both flips. Pixel descriptors, buffer strobes and field selection are asserted; known asynchronous 2020 reference differences are diagnostic. The original duplicate run only inverted reference polarity and added no DUT coverage.

Run `simunit.sh --run cores/popeye/ver/objbuf` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
