# CRT interlacer deflicker

Checks the four filter kernels (Off, Low, Mid, High), including every possible
numerator of Mid's 20% / 60% / 20% blend, random line triples and preservation
of constant colours. All 1,024 resampling-ROM entries are checked against an
independent floating-point convolution of the selected kernel and linear
interpolation, with the distant fourth tap discarded and the rest normalized.
The synchronous ROM read and weighted pixel arithmetic are also exercised.

Run with `simunit.sh --run modules/jtframe/ver/video/crt_480i_filter`.
