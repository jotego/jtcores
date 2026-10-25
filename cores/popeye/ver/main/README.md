# main regression

Generated Z80 firmware runs all four board wirings with synchronous ROM/RAM latency and varying SDRAM acknowledgements. Checks RAM/DMA, cabinet/AY I/O, text/background strobes, pause, NMI rearming and refresh watchdog. Real-ROM diagnostics remain in ../integration.

Run `simunit.sh --run cores/popeye/ver/main` or
`simunit-all.sh --only popeye`. Generated inputs and pinned test-only circuits
are described in `../fixtures/README.md`; no game ROMs are required.
Each run has a finite clock timeout and saves only an initial waveform.
