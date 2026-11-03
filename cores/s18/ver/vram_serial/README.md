# S18 VRAM serial read latency

This unit test compares `SERIAL_LOOKAHEAD=0` (the module default) with the
passive-wrapper setting `SERIAL_LOOKAHEAD=1`. It primes an old serial page,
loads bytes `05 00 fd 03` from a new page, then checks immediate, two-MCLK,
and four-MCLK SC cadence. The default instance must expose the previously
registered old-page byte at immediate SC; the lookahead instance must expose
`05`. Both must emit the remaining bytes in order on registered SC events.

The test also checks that page-load wins over a coincident SC edge and that
ordinary DRAM writes and reads still use the same memory address and data path.
Run with `simunit.sh --run cores/s18/ver/vram_serial`.
