# Cyclone V area measurement

Use Quartus Prime Lite 20.1.1 (or pass `--quartus-bin`) and a fresh output
directory:

```sh
python3 modules/jttms10/ver/area/run.py --reference /tmp/jttms10-reference
python3 modules/jttms10/ver/area/run.py --scalar /tmp/jttms10-scalar
python3 modules/jttms10/ver/area/run.py --word /tmp/jttms10-word
python3 modules/jttms10/ver/area/run.py --fabric /tmp/jttms10-fabric
python3 modules/jttms10/ver/area/run.py --system /tmp/jttms10-system
python3 modules/jttms10/ver/area/run.py --narc --source-ref HEAD /tmp/jttms10-narc
```

All six projects target `5CSEBA6U23I7`, use a 20 ns `clk`, seed 1, high
performance effort, and virtual pins for every exposed port. The reference
adds the existing TMS34010 core timing exceptions. Sources and generated
microcode are copied into the output directory, whose `manifest.json` records
the tool version, repository and old-module commits, SHA-256 source hashes,
and scope. For scalar and word fits, it copies instruction YAML before
generating microcode with `MODULES` set to that snapshot, so the ROM comes
from the exact YAML recorded in the manifest. The script runs Analysis &
Synthesis and Fitter; compare **fitted
ALMs** from `*.fit.rpt`. The map report additionally confirms whether the
generated control ROM and two 32×32 register-file mirrors become RAM.

The `--scalar` top is the currently incomplete scalar CPU. The `--word` top
adds its physical 16-bit field adapter and instruction cache. Both exclude the I/O/video registers,
arbitration, graphics, and NARC integration, so their ALM counts are inference
checks, not the 25% replacement acceptance result.
The `--fabric` top measures I/O, video, refresh, bus arbitration, and the
synchronous host-indirect engine. Its six HDL files are analyzed as plain
Verilog, as in JTFRAME synthesis.
The manifest also hashes the current instruction YAML for snapshot context,
but the fabric project does not generate or instantiate microcode. Its exposed
host request/data, external sync, HOLD, and sideband ports are virtual; NARC
will tie some of those signals to constants. It excludes the CPU, field
adapter, asynchronous physical host-pin interface, and graphics datapath. A
combined replacement must be fitted
separately; standalone counts are not additive area evidence.
The `--system` top combines CPU, field adapter, I/O/video/refresh,
arbitration, and the generic synchronous host engine under one physical-word
boundary. Its graphics instructions and timing validation are incomplete, and
the fit excludes asynchronous physical host-pin timing and the board's NARC
cycle controller. The system boundary is the closest current replacement
area estimate, but it cannot establish functional or timing acceptance yet.

The `--narc` top is the same `jtnarc_gsp` wrapper and port list as the old
reference, with `JTNARC_UCODE` selecting the new implementation. NARC's host,
HOLD and external-video-sync tie-offs can therefore be optimized exactly as
in the old boundary. Both sides exclude the board cycle controller. Use
`--source-ref COMMIT` to copy the new HDL, YAML and NARC wrapper directly from
one committed tree while development continues elsewhere. Its resolved
`source_commit` and all copied/generated hashes are recorded in the manifest.
The reference mode continues to use the unchanged pinned old submodule.

## Preliminary result, 2026-10-17

| Boundary | Fitted ALMs | Registers | Block RAM bits / blocks | DSPs |
| --- | ---: | ---: | ---: | ---: |
| Existing NARC `jtnarc_gsp` | 14,000 | 7,117 | 2,048 / 1 | 6 |
| Incomplete scalar `jttms10` alone | 404 | 203 | 51,200 / 7 | 0 |
| Incomplete `jttms10_word` with field adapter | 780 | 537 | 75,776 / 10 | 0 |
| Later `jttms10_word` with stack, unary, and HOLD restart | 968 | 537 | 96,256 / 12 | 0 |

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
The stack/unary/HOLD-restart snapshot is in
`/tmp/jttms10-141-area/word-stack/`; its manifest records repository commit
`062fd0750e5be9c9ebc09eb0925a4cdb5cc6559c` and hashes all 12 source,
microcode, and generated files. Every copied file matched its manifest hash.
Its 2048×46 ROM and both 32×32 register mirrors inferred `ALTSYNCRAM`.
This later count still excludes on-chip I/O, video, bus arbitration, graphics,
and NARC integration, and the ISA remains incomplete.
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

## Standalone peripheral budget check, 2026-10-17

The fresh plain-Verilog `--fabric` snapshot at
`/tmp/jttms10-141-area/fabric-verilog/` fitted **731 ALMs**, **716 registers**,
**0 block RAM bits / 0 RAM blocks**, and **0 DSPs**. It used Quartus Prime Lite
20.1.1 Build 720, Cyclone V `5CSEBA6U23I7`, a 20 ns `clk`, seed 1, high
performance effort, and 444 virtual top-level pins. The Fitter succeeded;
`fabric.fit.rpt` and `manifest.json` in that directory record the exact
resources, tool, repository commit `f2b7cd30ac932ead8aed23cc43ffe51db1134b69`,
old-module commit `29bcb384ec3dba892ea54db2ee92b38ae395d575`, and SHA-256
hashes of the five peripheral HDL files and three instruction YAML files. The
post-portability I/O and refresh source hashes are respectively
`d9221c2004c0812d48efc89b0e2f6c7acb9536645efe37e7c9116faa93d60e76`
and `daef41f1a9e7a52943c141a2da7f8582433960cc717f922616b8ed94f2b3819d`.
This snapshot predates the synchronous host engine; there is no CPU, field
adapter, host indirect engine, or graphics datapath in this fit.
This number is a peripheral budget check, **not** a full replacement result or
an independently addable term in the 3,500-ALM target.

## Divide and synchronous-host snapshots, 2026-10-17

Fresh fits at repository commit `884da7b3a9b27473dc551672e31b6ae176217e19`
used the same Cyclone V device, 20 ns clock, seed, optimization effort, and
virtual-pin constraints as above:

| Boundary | Fitted ALMs | Registers | Block RAM bits / blocks | DSPs | Virtual pins |
| --- | ---: | ---: | ---: | ---: | ---: |
| `--word` with scalar divide | 1,519 | 586 | 131,072 / 15 | 0 | 155 |
| `--fabric` with synchronous host | 1,013 | 808 | 0 / 0 | 0 | 484 |

Both Fitters succeeded. The word map report infers a 2048×63 control ROM and
two 32×32 register-file mirrors as `ALTSYNCRAM`; the fabric infers no RAM or
DSP. Reports and manifests are in `/tmp/jttms10-141-area/word-divide/` and
`/tmp/jttms10-141-area/fabric-host/`. Every copied/generated file matches
its SHA-256 manifest entry (18 entries for word, 9 for fabric). In particular,
the word ROM hash is
`f1674c8cb8a159517ed764c23a88e81eaaaabc63b1f90c1c2604bc5f4e9e81ae`;
the copied `control.yaml` and `memory.yaml` hashes are
`eec61a086dd9db4afea9d84a4a79ed28c5b61323e42c13f1cf9d8a02320972aa`
and `a19c0de6f4065ca26b1d98ffdcdc8a799fb8c462411e6d3f8f39d0f1069bccfb`.
The word ROM was generated from those copied YAML files. The host HDL hash is
`98d1f911655eabc6924aae2c960454703ba48b1f11f1334bae64a22faa5723e9`
in both snapshots.

The word fit excludes I/O, video, arbitration, graphics, and physical NARC
integration. The fabric fit excludes the CPU, field adapter, graphics, and
asynchronous physical host pins. Their ALM counts are standalone resource
checks, not an additive or complete replacement measurement against the
3,500-ALM limit.

## Integrated IRQ system snapshot, 2026-10-17

The fresh `--system` fit at `/tmp/jttms10-141-area/system-irq/` succeeded with
**2,461 fitted ALMs**, **1,507 registers**, **131,072 block-memory bits in 15
RAM blocks**, **0 DSPs**, and **302 virtual pins**. It used Quartus Prime Lite
20.1.1 Build 720 on Cyclone V `5CSEBA6U23I7`, a 20 ns `clk`, seed 1, and high
performance effort. The map report confirms the 2048×63 control ROM and two
32×32 register-file mirrors infer `ALTSYNCRAM`. All 20 copied HDL/YAML and
generated files still match their manifest SHA-256 hashes; the ROM hash is
`b2989267caca3960543df27fe4daaf187d4d4abb05b0e21a89f46c9583a0ce14`.
The system wrapper hash is
`c1c533488a4edb3b23432d2e6a54eff13221f968d68608099229f93719fbbdd7`.
The manifest records repository HEAD `40980ea8d76531fc0b1c56aa71a222756a6a0496`
at snapshot time and old-module commit
`29bcb384ec3dba892ea54db2ee92b38ae395d575`; the per-file hashes pin the
new IRQ source snapshot even though some of those files were not yet committed
at that HEAD.

This integrated count is below the provisional 3,500-ALM ceiling (25% of the
14,000-ALM old wrapper), with 1,039 ALMs of arithmetic headroom. Graphics
instructions and cache behavior are incomplete, and the external NARC timing
controller plus asynchronous physical host pins are outside this generic
synchronous host boundary. A 20 ns fit of this snapshot is not full-system
timing signoff or a completed 25% acceptance result. A new fit is required
after graphics and remaining architectural functions are integrated.

## Pixel instructions and integrated cache, 2026-10-17

| Boundary | Fitted ALMs | Registers | Block RAM bits / blocks | DSPs |
| --- | ---: | ---: | ---: | ---: |
| Generic system with PIXT/DRAV and cache | 3,197 | 1,900 | 133,120 / 16 | 0 |
| Same CPU/cache at NARC GSP boundary | 2,836 | 1,676 | 133,120 / 16 | 0 |

The generic snapshot is `/tmp/jttms10-141-area/system-pixel`, with 21 verified
HDL/YAML/generated hashes. Its functional inputs match commit `ca7232750`;
the only source difference is a later unused-signal reduction for lint. The
NARC snapshot is `/tmp/jttms10-141-area/narc-pixel-cache`, generated with
`--narc --source-ref ca7232750`. All 23 copied/generated hashes match and all
non-generated inputs match that committed tree. Both fits use the same device,
20 ns clock, seed and effort as the reference. The instruction cache adds a
128×16 block RAM alongside the control ROM and mirrored register RAM.

The NARC count leaves 664 ALMs below the 3,500 ceiling, but this source still
lacks FILL/PIXBLT/LINE and interruptible graphics continuation. These are
intermediate resource measurements. The completed implementation and working
NARC simulation/hardware must pass before the 25% goal is accepted.

## FILL/PIXBLT checkpoint, 2026-10-17

The exact committed array checkpoint `38b60f7b0c105f409a38abcce8827482d6de85cd`
fits at **3,896 ALMs / 2,146 registers / 135,168 block-memory bits in 16 RAM
blocks / 0 DSPs** at the same NARC GSP boundary, device, 20 ns clock, seed and
effort. Report and manifest: `/tmp/jttms10-141-area/narc-array`. All 23
copied/generated hashes and all committed source blobs were verified.

This is **396 ALMs above** the 3,500 ceiling and predates interruptible
arrays and LINE. The area requirement is not met. Relative to the pre-array
2,836-ALM fit, the core's own logic grows by 1,159 ALMs and 541 registers;
other blocks are largely unchanged. The next area work targets transient
array/window state and its wide operand selectors, with further measured
fits required after the remaining graphics behavior is complete.
