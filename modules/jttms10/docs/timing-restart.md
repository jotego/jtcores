# Timing restart — issue #149

[#144](http://gitea.jotego.es/jotego/jtcores/issues/144) is closed **unsolved**.
Its tested instruction examples did not establish complete condition timing,
and its implementation exceeded the area and constrained speed limits.
[#149](http://gitea.jotego.es/jotego/jtcores/issues/149) starts again from the
accepted #141 CPU, with the verification and DataStorm transport considered
separately.

## Status

The starting HDL and YAML were exactly the accepted #141 implementation
`a0d3612799adaa1df556aac8b5f6f2b27ae33b5b`, through its closing documentation
checkpoint `740709abbf72cb8af0f5e5e7668753979f5fd28f`. That implementation
passed the recorded functional suites, NARC simulation and MiSTer gameplay.
It explicitly did not establish instruction-cycle accuracy. No new #149
instruction form is yet qualified as fully timing compliant. The first increment
now has passing resident-cache examples for NOP, MOVK, ADD and MOVE using four
explicit YAML words at the existing two-clock microinstruction cadence. The
next bounded shift/LMO increment adds passing warm-cache examples for SLL,
SRA, SRL, RL, SLA and LMO. Ten mnemonics therefore have passing examples;
none has full-condition timing signoff. Instruction timing remains in YAML.

The currently programmed CPU source is
`cce1555c6c54602d0e03493946f874c088c8e7ed`, RBF SHA256
`525804aadbf1fcf59aac7f7e97fdb25ee436e7edb6294309181c46c35244cc92`.
Its SOURCE/SOURCE DataStorm build took 789.78 s in Quartus /800.630 s overall,
using `/opt/quartus_free` and retained generated infrastructure. This was a new
partition seed; no fitted Top preservation or recompilation speedup is claimed.
The six asset transfers took 4.797937 s. One programming operation took
0.326385 s on the target /1.195646 s over SSH. Board health passed.

All **99 representative physical cases** pass the unchanged independent Python
oracle and exactly match Verilator across BASE/W1P7/W3. This includes the
previously failing cache-disabled NOP and two cold four-word miss controls.
`measure_pass=0` selects the first/cold execution; it does not disable duration
checking. All 99 cases have duration scoring. A one-clock mutation in each of
the six cold-profile captures is rejected by the frozen checker.

The source-bound receipt is
`/nobackup/tasks/jtcores-149/artifacts/fpga-seed-003/program-001/source-bound-programming-receipt.json`
(SHA256 `06ae9a405cdf2005878cb756a484799e7aeac71f3a577fc5ec68ab0b483f96a7`).
The representative raw replay is `fpga-seed-003/representative-99/execution-001/root-review.json`.
The same image also passes **7,530/7,530 cached matrix executions**, with 657
scalar +1,853 shift/LMO cases per profile, across 237 batches. All six driver
and transport commands exit zero; no timeout or trace overflow occurs, and
before/after health passes. Root independently replayed all 237 raw captures.
This covers 15 encoding forms across ten mnemonics, with zero forms having
all-condition timing signoff; 118 forms have no new cached matrix. The 99-case
Verilator comparison is separate from the large matrix.

Six driver walls total 28.010364 s, including transfer/execution/checking.
Transfers total 9.778567 s; checking takes 1.510004 s. Target staging/run/drain
sums are 0.347/2.401/4.659 s, nested in the SSH execution time of 10.365592 s.
These phases are not additive independent end-to-end durations and establish
no matched software speedup ratio. Full matrix evidence is
`fpga-seed-003/scalar-shift-matrix/execution-001/root-review.json`
(SHA256 `b427c6cf532f312aab85af1352eb6f1596ddd5bebd5f3f0ce8749ab38cbdae91`).

The following table records the earlier scalar and shift increments. The
current bus/fetch CPU measurements appear in the next section.

| Matched four-fit mean | #141 baseline | Stopped #144 | Scalar increment | Shift/LMO increment |
| --- | ---: | ---: | ---: | ---: |
| ALMs | 2,752 | 5,129 | 2,804.5 | 3,128 |
| Reported Fmax | 56.415 MHz | 47.2075 MHz | 56.0075 MHz | 53.2275 MHz |
| Registers | 1,523 | 1,669 | 1,601 | 1,596 |
| RAM bits | 542,720 | 538,624 | 546,816 | 542,720 |
| M10Ks / DSPs | 69 / 0 | 71 / 5 | 69 / 0 | 69 / 0 |

The final acceptance limits remain **3,500 ALMs** at the complete NARC CPU
boundary and positive constrained **20 ns / 50 MHz** timing. This increment is
**+13.66% area /-5.65% reported Fmax** versus #141, and +11.54% /-4.96%
versus the scalar increment. Every seed passes constrained setup/hold with zero
endpoint TNS; minimum setup slack is +0.902 ns. Used RAM bits return to the
#141 value, with unchanged 69 physical M10Ks and zero DSPs. This is a measured
cost increase for bounded real shift/LMO work. The full Stage B planning gate
is 3,250 mean ALMs: only 122 ALMs remain below it, and field/posted-write/HOLD
feasibility is still open. Reassess resource sharing before broader expansion
if that gate cannot be met; do not accumulate unmeasured family fast paths.

## Bus/fetch checkpoint and current local experiment

The NOP bus/fetch increment passes all 12 short protocol-v5 controls with
the unchanged independent Python checker. Cache-disabled NOP takes 32/48/56
INCLK in BASE/W1P7/W3; the two cold four-word-fill controls take 80/120/176.
Warm NOP remains 8 INCLK, plus the seven explicit pause clocks in W1P7.
Actual logical bus slots and raw target handshakes are checked separately.
The same controls now agree on FPGA and Verilator. This extends selected NOP
conditions; it does not expand the 15-form cached matrix inventory or establish
full-condition instruction compliance.

Timing selection remains in YAML: a small bus service image schedules real
allocation/response/release, and NOP explicitly selects an earlier next read.
The generic one-owner RTL preserves the tuple and completion through pauses
and drains canceled work. It contains no instruction timer or opcode-family
timing scheduler. The two-bit CPU flow selector keeps the control ROM at
64 bits. See [the bus contract](bus.md).

The frozen v3 source passes `modules/jttms10/ver/run.sh`: 180 architectural
programs and every unit, including the permanent NMI/IRQ owner cancellation
test, in 72.91 seconds including compilation. An archived pre-fix version
fails the CEN-low new-stack-request assertion. Independent Sol review checks
both the source and event-based bus bench adaptations. The final lint-only
include annotation leaves functional tokens and all ten generated payloads
unchanged; bus/fabric lint passes, while inherited CPU/pixel warnings remain.

Four fresh, matched NARC CPU fits with `/opt/quartus_free` now measure the
owner/address path:

| Four-fit mean | #141 original | Previous qualified e088 | Bus/fetch experiment |
| --- | ---: | ---: | ---: |
| ALMs | 2,752 | 3,128 | 3,209.5 |
| Reported Fmax | 56.415 MHz | 53.2275 MHz | 53.465 MHz |
| Registers | 1,523 | 1,596 | 1,641 |
| RAM bits | 542,720 | 542,720 | 546,816 |
| M10Ks / DSPs | 69 / 0 | 69 / 0 | 69 / 0 |

This is +2.61% area versus the preceding qualified source, and +16.62% area /
-5.23% reported Fmax versus #141. The small frequency difference from e088
does not establish a speed improvement. All 48 constrained STA groups have
positive slack and zero endpoint TNS. The slowest seed reaches 50.51 MHz
with +0.202 ns minimum setup slack; only 40.5 mean ALMs (19 in the largest
seed) remain below the 3,250 planning gate. Field/posted-write feasibility
must stay within the remaining budget before broad instruction migration.
The 4,096-by-64 control ROM preserves its width from the earlier bus-only
experiment, and physical RAM blocks/DSPs remain unchanged. These are fresh
standalone fits, separate from the instrumented DataStorm appliance. Physical
qualification uses this exact source and its own receipt.

The permanent earlyfetch unit also passes held HLT, CF and CD cancellation.
CF/CD drain an old NOP response, then fetch a distinct MOVK signature from
the same instruction address, checking decode identity, one register write
and the corresponding retirement. `modules/jttms10/ver/run.sh --unit earlyfetch`
runs all five modes; the archived pre-fix CPU still fails the CEN-low request
guard with this final fixture. These are functional checks, not TI interrupt
or cache-control timing signoff.

Evidence is under `/nobackup/tasks/jtcores-149/artifacts/`:
`bus-phase-prototype/early-read-owner-v3-{normal12-run2,full-suite}/` and
`bus-phase-fit-002/`. The final immutable fit manifest is
`f7d23a247e8f3fb8e461ac753c4c9374d3ff38ac03b77e1b4c2a157980d11349`.
The additional permanent-unit proof is `earlyfetch-permanent-unit-runsh-v1/`.
Broader conditions, field/posted-write feasibility, clean CI and final
NARC/MiSTer acceptance remain open.

The latest source removes the combinational early-fetch start from request
and address selection. It reuses the existing registered owner/address, adds
no registers and changes no YAML. All twelve short timing controls and five
cancellation modes pass; raw result/bus captures match cce1555 exactly. The
full permanent Verilator suite passes all 180 architectural programs and units.

Four matched complete NARC CPU fits measure **3,142.5 mean ALMs /53.875 MHz**,
with unchanged 1,641 FF, 546,816 RAM bits, 69 M10Ks and zero DSPs. ALMs by seed
are 3131/3153/3136/3150; conservative Fmax is 52.71/53.80/53.77/55.22 MHz.
That recovers 67 ALMs versus cce1555. Versus #141, current mean area is
**+14.19%** and reported Fmax **−4.50%**. All 48 constrained STA groups have
positive slack and zero TNS; minimum setup improves to +1.028 ns. The small
mean Fmax change is not a demonstrated speedup. Reserve below the 3,250
planning gate is now 107.5 mean ALMs (97 in the largest seed).

The actual worst-corner path is control ROM to `pc[28]`, at Slow 1100 mV
−40°C. Targeted TimeQuest queries find no setup paths from ALU operand
registers A/B to field `last_index`; registered owner-state paths remain.
Primary fit reports and constraints are unchanged by the queries. Evidence:
`artifacts/registered-owner-fit-001/{review-v2.json,source-context.json}` and
`plans/registered-owner-four-fit-review.md`. The immutable snapshot manifest
SHA256 is `a6564b60f209fa3c3cc215d0e31e50ea0171255dd0e71ff72681db978f16ab2d`.
This source change is distinct from the currently programmed cce1555 image;
no physical qualification of the cleanup is claimed.

A separate FPGA memory baseline retains four failing load/store cases in each
profile and a passing NOP after them. With BASE timing, aligned 16-bit load is
40 rather than 24 clocks; offset-15 load is 96 rather than 40. Aligned and
offset-15 stores take 48/128 clocks rather than the required eight-clock CPU
interval; external writes have not been posted. All checked data/status/memory
values agree. Driver commands exit one for these timing/bus failures, with
transport DONE, no timeout/overflow and healthy image checks. This is failed
scope, not additional compliance. Raw traces are under
`artifacts/first-data-physical-baseline-001/execution-001/`.

## Demonstrated scope

The independent short integrated Verilator fixture warms the real cache by
execution, then checks two eight-instruction streams. All 14 adjacent scalar
intervals are eight INCLK, registers/status agree, twelve RF writes happen once,
and physical memory/IAQ traffic remains absent from the resident stream. The
frozen #141 baseline fails the same interval at thirteen clocks.

Six source-qualified runs check the stream, all sixteen CEN pause combinations
(positions 0..7, lengths 1 and 7), resident reserved-opcode TRAP30 and RETI,
held/transient HLT, isolated CF invalidation, NMI and separately enabled INTIN
IRQ. Sol independently reviewed the source and directed assertions. The
[permanent fixtures](../ver/restart/README.md) record commands and scope.

The shift/LMO fixture checks 18 independent TI-derived cases: four shift kinds
at counts 0/1/31, two same-register count/data aliases, the literal printed SLA
example, and LMO top/bottom/zero. All architectural/full-status checks and exact
8-/24-INCLK intervals pass with no warm external requests. The corrected NOP
lead-in and unconditional setup loop remain part of the test. The frozen scalar
source passes architecture but fails all 18 timing checks. A wrong-carry
mutation fails five status checks; removing one YAML SLA idle word fails only
its 22-versus-24-clock interval. Eight architecture modes and existing CEN,
held-HLT and enabled-IRQ restart checks also pass on the frozen candidate.

One-state shifts and LMO use four explicit YAML words. SLA uses twelve, with
eight explicit empty words. RTL replaces serial loops with bounded shared
shift/leading-zero operations; it has no instruction timer. The short fixture's
directed cases do not establish all status/register conditions. See
[the fixture and baseline](../ver/restart/stageb.md).

The historical e088 FPGA cached-positive matrix passed 657 scalar and 1,853
shift/LMO cases in each of BASE, W1P7 and W3, for 7,530 total expected-positive
executions. The combined inventory has 15 unique coverage IDs across 10
mnemonics; NOP is present in both inventories, so each profile has 2,510 case
executions and 2,509 distinct case names. All six driver commands exited zero;
237 batches completed with no transport errors or timeouts, and health checks
passed before and after every matrix. The same healthy loaded image was used
throughout, with no reprogram or reset. This matrix is not full instruction-
family signoff. Its separate exact-Verilator comparison had 90 positives and
three failing `nop_off` diagnostics. The current cce1555 image fixes those
diagnostics and has its own 99 positive comparisons, as described above.

| FPGA profile | Scalar cached cases | Shift/LMO cached cases | Total |
| --- | ---: | ---: | ---: |
| BASE | 657 | 1,853 | 2,510 |
| W1P7 | 657 | 1,853 | 2,510 |
| W3 | 657 | 1,853 | 2,510 |
| **Total** | **1,971** | **5,559** | **7,530** |

The execution summary is
`/nobackup/tasks/jtcores-149/artifacts/fpga-seed-002/scalar-shift-matrix/execution-003/terminal-summary.json`
(SHA256 `4ef87476b0dd52475a5635834e7e92ce6e3193939095ca957d0f2399cfcbbfea`).
The independent full-raw replay agrees with the reports and has no failures;
see `execution-003/root-review.json` (SHA256
`b8c82674dfbbbb5947216a3d53971b2964c12596596aa40790f46c4cfb8fff0e`).

Observed completion times were 27.038834 s summed driver wall time, 26.446898 s
inside the driver, 8.825586 s transferring data, and 10.219973 s for SSH
execution including transport. Driver time includes preflight, transfer,
execution and checking; transfer and execution run sequentially. Target-side
stage/run/drain times (0.343 / 2.217 / 4.625 s at millisecond resolution) are
nested within SSH execution. These phase totals are not independent end-to-end
durations; no speedup ratio is inferred from them. The checker took 1.589132 s.

The protocol-v5 DataStorm adapter separates a pinned frozen TI expectation tree
from the current hardware/runner/image receipts. Nine root/identity tests and
13 build-helper tests passed during adapter development, including real
CPU/YAML/generated-ROM changes. The first image used a new SOURCE/SOURCE
partition seed. Its receipt initially failed because the build helper hashed
the last diagnostic output instead of the frozen input manifest. The
host-only correction is committed as `8f1a668c`; a seed-specific, hash-bound
recovery validates the complete source/input/diagnostic inventory. The CPU and
YAML source did not change. The current host suite passes 34 tests with no
skips, including real saved-seed receipt generation, exact ten-payload schema
and negative certificate cases. The new cce1555 seed receipt needs no legacy
snapshot recovery. Later guarded CPU/YAML updates can request stable Top reuse, which the
build reports must prove. ROM-update receipts remain unsupported. See
[FPGA setup](../ver/fpga/README.md).

The field-path diagnostic uses the candidate `jttms10_system` in Verilator and
reports physical events independently of any TI instruction-total expectation.
An offset-0 resident one-pair RMW is the control; offset 8 adds eight serial
PREP clocks before the same one-pair transaction; offset 9 spans two words and
requires two pairs. The measured passes preserve adjacent bits and produce one
field response and one retirement. The CEN case holds CEN low through the final
write ACK, field response/CPU capture and a sampling edge, then resumes with a
single completion and no duplicate physical write. Exact traces and expected
merges are in
`/nobackup/tasks/jtcores-149/artifacts/field-feasibility/resident-short-e0883caa-qualified/REPORT.md`.
These four resident cases do not qualify CD execution, the full field matrix,
posted writes, HOLD restart or total TI timing.

Broader flag/alias conditions and same-edge CF/CD combinations remain open.
The historical e088 image failed cache-disabled `nop_off`: 22 vs 32 INCLK at
BASE, 37 vs 48 at W1P7, and 46 vs 56 at W3. Those failures are corrected on
the current cce1555 image. General CD memory-instruction totals remain
unqualified because field preparation and throughput are still unresolved.
ACK capture is demonstrated through one resident CEN pause case, while broader
pause/HOLD conditions remain unqualified. The selected unchanged architectural vectors
pass the Verilator adapter; the later local experiment's full 180-program
regression is recorded separately above.
Current strict lint still reports the original pixel helper's UNOPTFLAT warnings
under the installed Verilator; the frozen #141 source produces the same warning
types/counts. The new candidate adds eleven raw -Wall warnings for intentionally unused
compatibility ports and intermediate bits; independent review found no new
WIDTH, LATCH or combinational-loop category. `lint-one.sh narc` skips the core,
so it is not a pass. Raw strict lint fails on warnings; clean lint/CI remains
open.

## Reproducing the cost measurement

Use a fresh output directory for each seed, set its generated QSF `SEED` to
1, 2, 3 or 4 before compilation, and retain the same source commit:

```sh
source setprj.sh
python3 modules/jttms10/ver/area/run.py --narc --snapshot-only \
  --source-ref HEAD --quartus-bin /opt/quartus_free /tmp/jttms10-149-seed1
cd /tmp/jttms10-149-seed1
/opt/quartus_free/quartus_map narc --read_settings_files=on --write_settings_files=off
/opt/quartus_free/quartus_fit narc --read_settings_files=on --write_settings_files=off
/opt/quartus_free/quartus_sta narc
```

These measurements use Quartus Lite 20.1.1 Build 720, Cyclone V
5CSEBA6U23I7, high-performance effort, the same 158 virtual pins and 20 ns
clock as #141. The recorded shift/LMO checkpoint used 3,127 /3,127 /3,134 /3,124 ALMs; reported worst-corner
Fmax is 52.36 /53.71 /53.54 /53.30 MHz. Internal constrained timing is checked;
virtual external I/O is unconstrained. Source/ROM hashes, exact commands and
reports are retained in `/nobackup/tasks/jtcores-149/artifacts/stageb-fit-001/`.
Its `review.json` verifies all 35 inputs/payloads, four command exit statuses,
158 expanded pins, identical constraints and all twelve STA groups per seed.
The original scalar measurement remains separately in `scalar-fit-001/`.
The existing snapshot command was independently rerun: all 35 source/payload
hashes and normalized QSF/SDC match the retained shift/LMO fit.

The detailed first-seed slow-100 C path report has control-ROM output to PC as
its ten worst setup paths, with +1.057 ns slack. This is a queried fitted
path, not a claim that the new shifter is the overall limiting cone. Querying
TimeQuest appended only LAST_QUARTUS_VERSION metadata to seed1 QSF; the exact
pre-query QSF hash remains verified. Internal clock constraints are unchanged.

## Findings and design rule

Astra's independent audit and Sol's review find that most added combinational
logic is in the main CPU's scheduling and operand selection, while the shared
ALU's atom count is almost unchanged. The four stopped-source worst slow-corner
paths run from IR into MD. Compiler atom counts locate growth; they do not
predict removable fitted ALMs.

**Instruction sequencing, delays and timing adjustments belong in YAML
microcode.** Do not add instruction-duration counters, opcode-specific timing
schedulers or family-specific timing bypasses in RTL. RTL changes must implement a
justified shared resource or generic sequencer/protocol capability. Preserve
synchronous control ROMs and register RAM, one ALU and shared scratch storage.

The existing two-clock ROM prime/execute cadence and synchronous RF latency
must be included in the microcode schedule. One TI state is eight INCLK edges;
NARC supplies the CPU with its 48 MHz clock. Cache/RF responses and physical bus
events must be measured independently of retirement pulses.

## Next decisions

1. Keep the 7,530-case result bound to its recorded image/oracle evidence, and
   extend exact-Verilator comparison only with explicit case-by-case reports.
   Do not count these selected positive matrices as full-family signoff.
2. Continue field validation from segment events: extend alignment, pair
   inventory, payload/preservation, response capture, posted-write and HOLD
   cases while keeping the offset-0 control. Keep CD totals diagnostic until
   `nop_off` fetch timing is corrected.
3. Reassess shared resources against the 3,250 mean-ALM Stage B planning gate
   before broad condition expansion. Timing adjustments remain in YAML; any
   RTL work must add a justified generic functional/protocol capability.
4. Preserve original functionality and the final CI/NARC/MiSTer acceptance
   gates, including full architectural, lint and fitted timing checks.

Long supported matrices run on DataStorm through its dedicated operator.
Short diagnostics use Verilator. Use `/opt/quartus_free` and retain stable
HPS/test infrastructure for incremental compilation. The loaded `e0883caa`
image qualifies the recorded representative comparisons and selected cached
matrices; complete family timing and the final acceptance gates remain open.

Every milestone reports demonstrated timing scope, remaining conditions,
original/previous/current area and speed, structural cost and next decision
before detailed implementation notes. Passing examples and fully compliant
instruction forms are distinct counts.
