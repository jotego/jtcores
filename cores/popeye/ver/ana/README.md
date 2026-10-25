# ana regression

Ten option cases cover every deflicker level, both widths, signed H/V extrema and combined positioning. Checks four fields, interlace phase, active dimensions and RGB windows.

Run `simunit.sh --run cores/popeye/ver/ana` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
