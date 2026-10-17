# Cyclone V area measurement

Use Quartus Prime Lite 20.1.1 (or pass `--quartus-bin`) and a fresh output
directory:

```sh
python3 modules/jttms10/ver/area/run.py --reference /tmp/jttms10-reference
python3 modules/jttms10/ver/area/run.py --scalar /tmp/jttms10-scalar
python3 modules/jttms10/ver/area/run.py --word /tmp/jttms10-word
```

All three projects target `5CSEBA6U23I7`, use a 20 ns `clk`, seed 1, high
performance effort, and virtual pins for every exposed port. The reference
adds the existing TMS34010 core timing exceptions. Sources and generated
microcode are copied into the output directory, whose `manifest.json` records
the tool version, repository and old-module commits, SHA-256 source hashes,
and scope. The script runs Analysis & Synthesis and Fitter; compare **fitted
ALMs** from `*.fit.rpt`. The map report additionally confirms whether the
generated control ROM and two 32×32 register-file mirrors become RAM.

The `--scalar` top is the currently incomplete scalar CPU. The `--word` top
adds its physical 16-bit field adapter. Both exclude the I/O/video registers,
arbitration, graphics, and NARC integration, so their ALM counts are inference
checks, not the 25% replacement acceptance result.

## Preliminary result, 2026-10-17

| Boundary | Fitted ALMs | Registers | Block RAM bits / blocks | DSPs |
| --- | ---: | ---: | ---: | ---: |
| Existing NARC `jtnarc_gsp` | 14,000 | 7,117 | 2,048 / 1 | 6 |
| Incomplete scalar `jttms10` alone | 404 | 203 | 51,200 / 7 | 0 |
| Incomplete `jttms10_word` with field adapter | 780 | 537 | 75,776 / 10 | 0 |

These were fitted by Quartus Prime Lite 20.1.1 Build 720 for Cyclone V
`5CSEBA6U23I7`, 20 ns `clk`, high performance effort, with exposed ports as
virtual pins. The old wrapper had the existing TMS34010 core SDC exceptions.
The standalone driver reproduced the reference measurement exactly: its
report and 33-source hash manifest are in
`/tmp/jttms10-141-area/reference-repro/`. The scalar report and source-hash
manifest are in `/tmp/jttms10-141-area/scalar-repro3/`.
The later word-adapter snapshot and manifest are in
`/tmp/jttms10-141-area/word-memory/`; its control ROM is 2048×36. The scalar
and word measurements use different evolving CPU source snapshots, so their
difference is not an isolated field-adapter cost.
That scalar snapshot predates the ADDI/SUBI/CMPI microcode additions; rerun
the driver to measure the current source rather than reusing its count.
The old TMS34010 submodule was at
`29bcb384ec3dba892ea54db2ee92b38ae395d575`. The 25% limit relative to
this old wrapper is 3,500 fitted ALMs. The scalar has only a subset of the ISA
and lacks the integrated peripherals and NARC memory boundary, so this result
does not establish that limit for a working replacement.

The scalar map report identifies a 2048×24 `ALTSYNCRAM` control ROM plus two
32×32 simple dual-port `ALTSYNCRAM` register mirrors. The generated ROM MIF
contains nonzero microinstructions. The current blocking assignment in the
clocked ROM read inferred block RAM in this Quartus build.
