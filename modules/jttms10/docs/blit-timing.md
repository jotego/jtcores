# PIXBLT timing baseline (#144)

All six PIXBLT encodings have independent timing probes. Aligned opaque regular
copies now have a native word schedule validated on DataStorm and Verilator.
Binary expansion still transfers through the general graphics microcode and
fails timing. Full timing compliance and condition coverage remain open.

The authority is TI's June 1988 SPVU001A [TMS34010 User's Guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
The regular setup/transfer/graphics tables are 13-8/9/10, printed
pp.13-18/20/24; binary expansion uses Tables13-11/12/13 and pp.13-32..35.
The scanned tables were inspected, rather than relying only on OCR.

## Independent expectations

The first domain is nonempty, opaque replace: PPOP0, PMASK0, T0, W0,
PBH0/PBV0, with word-aligned source and destination rows. All five pixel sizes
are exercised. Regular copies span one through four destination words and one
or two rows. Binary rows contain at most 32 source bits; longer set/remainder
equations remain outside this initial domain and raise explicitly in the model.

At G=2 and destination alignment A, with D>=S:

| Operation | Setup states | Transfer states |
| --- | ---: | --- |
| L,L | 7 | N=1: `6L+5`; N=2: `10L+5`; N>=3: `4NL+5` |
| L,XY or XY,L | 9 | Same transfer equation |
| XY,XY | 12 | Same transfer equation |
| B,L | 4 | `(3+2R+2N)L+3` in the short/medium binary domain |
| B,XY | 6 | Same binary transfer equation |

N is the destination words per row, L the rows, and R the source words read
for a binary row. CD adds the separate three-state opcode-fetch cost. Each
physical transfer adds its own configured waits; early CEN pauses retain the
shared checker’s measured pause and bus-alignment rules.

Pixels are copied bit by bit in Python. Binary expansion selects the COLOR0
or COLOR1 pixel aligned with the destination lane, as pp.12-175/180 specify;
the colors deliberately contain nonuniform patterns. It does not broadcast
their lowest pixel. Source words and destination canaries are preserved.
All defined registers, the shared SP and all defined ST bits remain checked.
TI marks NZCV undefined for these instructions; only those four bits are masked.
B10..14 are reserved graphics scratch registers and have no final golden.

The bus checker requires the expected forward source reads and destination
writes, payloads, IAQ, two-state cycles, target readiness and the repeated-row
coefficient. A destination cannot be written before its required source is
captured. Buffering multiple source words is allowed; the model does not invent
a first-write phase or require one particular read/write interleaving.

## Historical physical failing baseline

The published baseline contains 464 new fixtures. All 141,428 predecessor fixture/program contracts
are unchanged, giving 141,892 fixtures with probe presence for 133/133 forms.
These counts do not establish timing compliance or complete condition coverage.

The unchanged cached-MOVB DataStorm image runs all new programs without a new
FPGA compilation. Twenty-eight representatives cover all six encodings plus
patterned binary colors at every pixel size. They repeat at base, W1/P7-after0
and W3. All 84 observations, memory snapshots and exact diagnostic errors match
short original Verilator runs. Every command returns 1; all raw transports
return 0. Standard equivalence continues to refuse failing captures.

The complete 464-case base batch run also returns 1, with transport exit 6.
Its report contains 311 individual failing verdicts, all failing duration with
architectural and final-memory checks active. There are 490 additional bus
trace-count/cadence diagnostics. Nine batches reject another 153 requested
cases because of trace overflow; they have no individual oracle verdicts.
The raw results contain 40 actual overflowing cases, each explicitly flagged
at 512 records. Do not describe the other 113 DONE results inside those failed
batches as individually validated. Later batches rearm and return ordinary
verdicts; the last batch contains five cases. Root replay reproduces every
saved report, including the batch-level failures, without clearing errors.

The three focused host commands take 4.279/3.592/3.468 seconds; the full new
base batch command takes 5.142 seconds. These are failing-baseline command
measurements, not a matched software speedup or a CPU timing improvement.
Raw evidence is under `/nobackup/tasks/jtcores-144/artifacts/pixblt-baseline/`.
The historical image identity and its current replacement are in the
[FPGA runner documentation](../ver/fpga/README.md).

```sh
python3 modules/jttms10/ver/timing/test_blit_oracle.py
python3 modules/jttms10/ver/timing/test_blit_cases.py
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case blit_ll_ps16_n1_rows1_hit --report blit-reference.json
python3 modules/jttms10/ver/fpga/check_results.py prepare \
    --protocol-version 3 --case blit_ --output blit-manifest.json
```

The complete simulation and FPGA commands retain failing binary cases. The
normal runner includes the model tests and fixtures. Empty arrays, partial alignments, long binary rows, other
graphics/window/mask/transparency operations, overlap/reverse traversal,
HOLD/IRQ/context resumption and full clean/CI acceptance still require work.

## Native regular word schedule

The regular L,L / L,XY / XY,L / XY,XY paths reuse the synchronous register RAM,
scalar ALU/DSP, operand registers and field adapter. A posted source read lets
pointer and count work overlap memory. Collection waits for the real field
response before loading MD; an older posted write cannot acknowledge a newly
scheduled read while its request is inhibited. A queued source remains pending
across the preceding write's drain. No new register bank or arithmetic unit is
introduced. The graphics control ROM grows from 63 to 64 bits per word.

The controller retains separate setup, four-state word work, two extra states
for one/two-word rows, and the five-state completion tail. External waits stop
overlapped CPU work; early CEN pauses retain state-grid alignment. Word bus
duration, target readiness and row cadence are checked independently of total
instruction clocks. Source and destination XY conversions share the existing
DSP and use their separate CONVSP/CONVDP values.

Nineteen representatives pass each of base, W1/P7 and W3. Another nine address
representatives pass each profile with nonzero X/Y, OFFSET, different conversion
factors and unequal row pitches. All checked registers, defined status, source,
destination, canaries, bus events and durations remain active. Forty permanent
address fixtures are appended after the original 464 cases. Every preceding
141,892 fixture/program contract remains unchanged; inventory is 141,932.
These targeted simulations do not establish complete graphics condition or
native interrupt-resumption coverage.

The retained-IP `/opt/quartus_free` build of RTL commit `cb113446b` passes final
STA and runs on DataStorm with a new source-bound receipt. All 84 representatives
above pass physically and match the original Verilator observations, including
relative bus/target events. All 360 regular fixtures pass each of base, W1/P7
and W3. The full passing subset has 141,788 cases / 131 forms / 5,179 batches
per profile: 425,364 executions on one configuration. Every raw verdict was
independently replayed. Full host walls are 291.21/298.16/316.90 seconds;
these are command measurements rather than a matched software speedup study.
See the [current FPGA image and timings](../ver/fpga/README.md).

All 144 binary fixtures also return individual verdicts on the new image,
without trace overflow (maximum 399/512 records). They all fail timing;
generic per-pixel bus counts and row cadence also fail where applicable.
Architectural and final-memory checks pass. Two B,XY PS2 N1/one-row cases now
take 1420/1448 INCLK (hit/CD), eight more than the historical baseline.
Fresh short Verilator runs reproduce those clocks and all checked events and
diagnostics exactly. The additional delay remains an open binary timing
regression; no expectation was changed. Standard equivalence refuses failing
inputs. The published MOVB-target command separately retains 27 CD failures.

Run the complete regular domain through the ordinary FPGA fixture builder:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare --protocol-version 3 \
    --case blit_ll_ --case blit_lxy_ --case blit_xyl_ --case blit_xyxy_ \
    --output regular-manifest.json
```

The ordinary `--matrix` inventory includes the 144 failing binary cases. The
passing full manifests explicitly record their exclusion and preserve them in
a separate failing command; this is not full instruction timing compliance.
Programs, expected results and supported wait/pause settings change without
another FPGA compilation. Native IRQ/HOLD and broader graphics conditions
remain unvalidated. The old cached-MOVB receipt and failing-baseline evidence
retain their original identities.
