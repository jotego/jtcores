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
shift/leading-zero operations; it has no instruction timer. This directed set
does not establish the complete shift matrix or all status/register conditions.
See [the fixture and baseline](../ver/restart/stageb.md).

The protocol-v5 DataStorm adapter separates a pinned frozen TI expectation tree
from the current hardware/runner/image receipts. Nine root/identity tests and
13 build-helper tests pass, including real CPU/YAML/generated-ROM changes.
The new source has not yet run on the FPGA. The first image needs a new
SOURCE/SOURCE partition seed; later guarded CPU/YAML updates can request stable
Top reuse, which actual reports must prove. ROM-update receipts remain
unsupported. See [FPGA setup](../ver/fpga/README.md).

General flag and A15/B15 alias matrices, CD and same-edge CF/CD changes,
memory ACK under CEN pause, nonresident fetch timing and all wider instruction
conditions remain unqualified. The selected unchanged architectural vectors
pass the Verilator adapter; the full 180-program regression remains pending.
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
clock as #141. Current ALMs by seed are 3,127 /3,127 /3,134 /3,124; reported worst-corner
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

## First decisions

1. Prove a real resident-cache NOP/ADD/MOVE/MOVK stream with eight input clocks
   between instruction boundaries, using explicit YAML microsteps and a bounded,
   side-effect-free cached-word lookahead. No speculative external miss traffic.
2. Check dependent registers, both files/SP aliases, pauses and invalidation.
   Run short Verilator diagnostics and measure the fitted complete CPU before
   migrating more instructions. An initial planning budget is 3,000 mean ALMs;
   exceeding it requires another architecture decision.
3. Immediately prove maximum-count shifts/LMO, unaligned fields and posted
   writes. The original serial operations cannot meet all published short
   instruction counts just by changing delays. Any shared hardware replacement
   needs its own measured area/STA comparison and microcoded schedule.
4. Prove representative graphics and interrupted/resumed work before broad
   condition expansion. Preserve all original functionality and the final
   CI/NARC/MiSTer acceptance gates.

Long supported matrices run on DataStorm through its dedicated operator.
Short diagnostics use Verilator. Use `/opt/quartus_free` and retain stable
HPS/test infrastructure for incremental compilation. The old loaded #144 image
and its passing scope do not qualify the new CPU.

Every milestone reports demonstrated timing scope, remaining conditions,
original/previous/current area and speed, structural cost and next decision
before detailed implementation notes. Passing examples and fully compliant
instruction forms are distinct counts.
