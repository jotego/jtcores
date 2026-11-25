# CPS1 PCB timing diagnostic simulation

This uses the V14 diagnostic measured on the SF2 90629B-3 PCB in issue #226.
It retains the 77-case suite, setup, interrupt handler, and measured loops
unchanged. Memory tests use one transition sample and eight steady samples;
the displayed MED is the lower middle of those eight. ROMF-NONE has no
explicit data accesses, but its instructions are still fetched from ROM.

From the project root, `source setprj.sh`, then run `cores/cps1/ver/pcb_timing/sim.sh`.
It generates the SF2 ROM with `jtframe mra cps1` if needed, overlays the
program onto the first 256 KiB CPU region, and uses `jtsim -load`. The MRA
header and remaining ROM regions are preserved. `results.cab` advances through
the nine result pages after the suite completes, and the simulation runs for
1400 frames (about 85 minutes).

`check.py` then takes the last frame of each page window listed in
`frames.ref`, requires it to be nonblank and compares the CRC-32 of its RGBA
pixels. Any timing change in the core alters the displayed counts and fails
the check. After an intended timing change, inspect the pages and refresh the
reference with `python3 check.py --update`.

The reference CRCs come from the core after issue #229. Its counts match the
PCB within 0.23% in every case (rms 0.11%). The largest residuals are:

| Case | Core | PCB | Error |
|------|-----:|----:|------:|
| ROMF-x4 (four accesses per loop) | 2666 | 2660 | +0.23% |
| S1-V1 (unaligned scroll 1) | 7413 | 7428 | -0.20% |
| ROMF-NONE | 3965 | 3960 | +0.13% |

The memory residuals come from the 68000 bus-cycle quantization of each DMA
grant and do not improve by releasing the bus later. On the PCB, scroll 1
costs the same at any vertical phase, while the core loads one more row when
the scroll is unaligned.

`firmware.bin` is the 12,132-byte V14 program including its embedded identity
fields. `marker.bin` is the eight-byte V14 end-of-ROM identity marker. The
remaining CPU window is filled with FF as in the physical image. This binary
is larger than the originally contemplated 2–4 KiB but allows the exact PCB
suite to run without a cross toolchain. To verify the source reproduces it,
run `python3 verify-build.py`; this needs the m68k-linux-gnu binutils and GCC.
The generated `case_table.h` and linker layout are retained with the source.
The original full V14 CPU image SHA-256 is
`cd0b136ef4221badbac1eeac59aa769b01ab2645bc8889e5e431ce20d029ec84`.
