# PIXBLT timing baseline (#144)

All six PIXBLT encodings have independent timing probes. Aligned opaque regular
copies now have a native word schedule validated on DataStorm and Verilator.
Aligned opaque binary expansion also has a native short-row schedule,
validated on DataStorm. Native interrupt continuation and 20 additional wide
row fixtures now pass local Verilator checks; their new FPGA image is pending.
Full timing compliance and condition coverage remain open.

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

The complete simulation and FPGA commands retain all binary cases. The
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

On that historical regular-copy image, all 144 binary fixtures returned individual verdicts,
without trace overflow (maximum 399/512 records). They all fail timing;
generic per-pixel bus counts and row cadence also fail where applicable.
Architectural and final-memory checks pass. Two B,XY PS2 N1/one-row cases now
take 1420/1448 INCLK (hit/CD), eight more than the historical baseline.
Fresh short Verilator runs reproduce those clocks and all checked events and
diagnostics exactly. That historical extra delay is superseded within the
aligned native binary domain below; the failing baseline and its original
expectations are retained. Standard equivalence refuses failing
inputs. The published MOVB-target command separately retains 27 CD failures.

## Native binary short-row schedule

The new B,L / B,XY microprogram supports nonempty opaque replacement with
PPOP0, PMASK0, T0, W0, PBH0/PBV0, aligned source/destination rows and pitches,
complete destination words, and DX<=32. It reads exactly one or two source
words per row before emitting the expanded words. Unsupported alignments,
pitches and widths return to the generic microprogram before any source
read or architectural pointer update. Other processing modes retain the
generic path.

S48 stores the bitmap and S49 the second source word. A 16-bit selector
repeats each bitmap bit according to PS and selects destination-aligned lanes
from the existing COLOR0/1 operand registers. The existing scalar DSP shifts
the bitmap for the next output word; no additional register bank, multiplier
or ALU is introduced. Graphics ROM remains 4096x64. Source responses establish
the two-state read plus processing schedule, each output word has two states,
and the final row carries the three-state completion tail. Posted requests
remain pending until their own response; external waits and CEN pauses freeze
the corresponding work.

Twenty-four representatives, including two regular controls, pass each of
base, W1/P7 and W3. Ten geometry representatives pass each profile, giving
102 focused observations. Every raw trace replays against the unchanged
independent oracle. Twenty new geometry fixtures are appended; all 141,932
predecessor fixture/program contracts remain unchanged. Current inventory is
141,952, including 164 binary and 360 regular PIXBLT fixtures. Deliberately
flipping an expanded output bit fails memory/bus checks; adding one source
processing state fails duration/row cadence with correct final memory. NOP
controls pass in both mutant runs.

The architectural runner also supports `--timed-word`, applying its existing
independent values and memory checks through TIMED_PROGRAM=1 and the physical
word/bus wrappers. All 70 binary boundary vectors pass normally and with HOLD,
140 architectural executions. They cover native aligned rows and
generic source/destination misalignment, unequal or unaligned pitches, partial
words and DX=33. These are architectural checks, not timing goldens for those
fallback conditions. `--hold-after-write` injects a real bus HOLD after a pixel
write and requires a grant and release. This proves architectural continuation
for this local wrapper test, not a HOLD timing equation or physical FPGA HOLD
scheduler. The normal runner includes both boundary profiles.

```sh
python3 modules/jttms10/ver/array/binary_programs.py --out binary-boundaries.yaml
python3 modules/jttms10/ver/run.py --timed-word --vectors binary-boundaries.yaml
python3 modules/jttms10/ver/run.py --timed-word --hold-after-write \
    --vectors binary-boundaries.yaml --case binary_bl_ps1_aligned
```

The native binary image at RTL `2a5e4a6d9` now passes all 141,952 fixtures /
133 forms /5,188 batches in each base/W1-P7/W3 without exclusions, including all
164 binary and 360 regular cases. All 102 focused physical observations match
original Verilator and every full raw verdict independently replays exactly.
Enclosing command walls are 305.33/311.54/323.21 s. The Rapid image has positive
final STA; the separate full attempt failed one HPS setup path and was rejected.
See [image identity, build costs and phase measurements](../ver/fpga/README.md).
That historical image predates the native IRQ/NMI continuation below.

## Native binary interrupt continuation

TI SPVU001A pp.7-8/9 and 12-175/176/180/182 require word/row checkpoints,
PBX context preservation and RETI continuation. The native path now cancels
an unaccepted next-word write or next-row read when an interrupt is pending,
then drains the preceding physical field before taking the interrupt. A posted
operation accepted during a CEN pause must finish. Normal uninterrupted words
retain the existing two-state schedule; there is no unconditional drain added
to each word. S49 snapshots the bitmap before speculative next-word expansion
so cancellation cannot discard unconsumed source bits.

The ISR-visible B0 points to the next 32-pixel source group, or the next row
at a row boundary; B2 points to the next destination word/row. TI reserves
B10..B14 for graphics continuation, but does not specify their bit layout.
This implementation's private native frame is:

| Register | Project restart value |
| --- | --- |
| B10 | Original width in the high half; original opcode with bit 0 set in the low half |
| B11 | Rows after the current row in the high half; remaining pixels in the low half |
| B12 | Unconsumed bitmap |
| B13/B14 | Next source/destination row bases |

The tag distinguishes this frame from generic binary continuation. RETI
restores the shared synchronous RF and ALU state, clears the private opcode
tag, restores the native word/final-row flags and starts a fresh timing budget.
An ISR may use graphics when it preserves B0..B14. No extra RF bank or DSP is
added; the graphics ROM remains 4096x64. This private frame is not a claim to
match undocumented TI intermediate register values.

`ver/array/timed_interrupt.sv` uses the real TIMED_PROGRAM=1 word adapter and
TIMING=1 bus, independent bitmap/color values and literal physical addresses.
The standard `binaryirq-timed` sweep passes 1,640 mode executions over PS1/2/4/8/16,
DX16/32, B,L/B,XY, first-word/row/penultimate/final-word interrupts, waits0/1,
and CEN pauses0/7/31. It checks IRQ, stacked NMI, no-stack NMI abandonment,
NMI+HLT, nested FILL under MMTM/MMFM, PBX/PC/ST, defined pointers/colors,
source/canary preservation, exact source and destination traffic, one original
opcode fetch and physical-field drain. It asserts that pauses actually cover
posted acceptance and, at 31 clocks, a pending IRQ with an accepted response.
This proves checkpoint/event ordering and architecture, not silicon interrupt
entry latency or instruction duration across an ISR.

Twenty added DX32 fixtures exercise N8/N16/N32 at PS4/8/16 through the unchanged
TI timing equation and Python pixel oracle. N8/N16 include one and two rows;
N32 uses one row to fit the bounded FPGA memory inventory. All 141,952 preceding
fixture/program contracts are unchanged. Inventory is 141,972, with 184 binary
and 360 regular fixtures. All 162 focused/geometry/wide observations pass base,
W1/P7 and W3 Verilator. The wider two-row N32 case is covered architecturally
by the interrupt bench, with its larger memory, rather than the ordinary runner.

The permanent mutation checks reject a missed word checkpoint, cancellation
of an already accepted write and lost timing state on resume. Separate timing
mutations add one native source-processing state: both cases must fail timing
with correct architecture and final memory. These checks change temporary RTL
copies, preserving the independent oracle.

```sh
bash modules/jttms10/ver/sim.sh binaryirq-timed
python3 modules/jttms10/ver/array/check_timed_interrupt.py --report irq-mutations.json
python3 modules/jttms10/ver/timing/mutations.py --group binary --report binary-mutations.json
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case blit_bl_ps16_n32_rows1_hit --report wide-reference.json
```

The current FPGA V3 runner cannot inject IRQ/NMI/HOLD. A new FPGA image and
ordinary matrices can validate the new RTL's uninterrupted timing and results;
they cannot establish physical interrupt continuation. That stimulus path,
silicon interrupt latency and full condition compliance remain open.

Run the complete regular domain through the ordinary FPGA fixture builder:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare --protocol-version 3 \
    --case blit_ll_ --case blit_lxy_ --case blit_xyl_ --case blit_xyxy_ \
    --output regular-manifest.json
```

The ordinary `--matrix` inventory includes all 184 binary cases; the historical
passing 141,952-case full manifests have no exclusions. The historical failing commands
remain preserved. This is not full instruction timing compliance.
Programs, expected results and supported wait/pause settings change without
another FPGA compilation. Physical IRQ/HOLD and broader graphics conditions
remain unvalidated. The old cached-MOVB receipt and failing-baseline evidence
retain their original identities.
