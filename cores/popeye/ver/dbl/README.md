# dbl regression

Independent source-row/pixel tags check all eight measured fields, doubled rows, A/B sprite selection and positive ring read/write margins. Row tags follow VLATCH rather than the LVBL edge.

Run `simunit.sh --run cores/popeye/ver/dbl` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
