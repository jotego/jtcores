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
result pages after the suite completes. Inspect the nonblank PNGs in `frames/`.
The current script is for observing the existing core; it does not yet check
reference CRCs or assert agreement with the PCB.

`firmware.bin` is the 12,132-byte V14 program including its embedded identity
fields. `marker.bin` is the eight-byte V14 end-of-ROM identity marker. The
remaining CPU window is filled with FF as in the physical image. This binary
is larger than the originally contemplated 2–4 KiB but allows the exact PCB
suite to run without a cross toolchain. To verify the source reproduces it,
run `python3 verify-build.py`; this needs the m68k-linux-gnu binutils and GCC.
The generated `case_table.h` and linker layout are retained with the source.
The original full V14 CPU image SHA-256 is
`cd0b136ef4221badbac1eeac59aa769b01ab2645bc8889e5e431ce20d029ec84`.

No reference images are accepted yet. The full issue also includes matching
PCB timings and automated image CRC checks; those remain future work.

The local Verilator 5.018 does not recognize `--quiet-stats`, which this
checkout's `jtsim` currently passes. A newer compatible Verilator is required,
or an equivalent local compatibility wrapper can remove that option. This is
a tool-version issue, not a timing change in the core.
