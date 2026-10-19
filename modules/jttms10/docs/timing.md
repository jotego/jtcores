# Instruction timing compliance (issue #144, in progress)

The CPU is **not fully instruction timing compliant**. The current timing
probes cover 115 of 133 instruction forms; the other 18 remain unvalidated.
Some printed counts conflict. The owner authorizes the simpler implementation
where reliable clarification cannot be found; explicit project choices keep
all alternatives visible. See [source-policy.md](source-policy.md).
Single-word absolute MOVB also has a known gap against counts on which
both TI tables agree: cached CPU 1 state/CD 7 versus the present policy's
3/15. Plain byte-copy index2 also has a CD7 versus current CD9 gap.
The standard runner's acceptance gate fails on missing forms and
unresolved source/policy differences, with the recorded project choices
applied explicitly. Passing the present probe matrix is
not full-ISA acceptance.
Architectural regression, FPGA setup/hold closure and instruction timing are
separate checks.

The primary specification is TI's June 1988 *TMS34010 User's Guide*,
SPVU001A, including its device data sheet in Appendix A. Citations below
refer to printed pages. The guide is available from
[Bitsavers](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
The pinned `modules/tms34010` can provide secondary comparisons; its
behavior cannot override the published rules.

## Measurement contract

One machine state is one LCLK1 period (§1.3.1.5, p.1-7). The data sheet
specifies INCLK divided by eight to generate LCLK1/LCLK2 (Appendix A,
p.A-41). Thus one machine state is eight INCLK periods. At 50 MHz it is
160 ns (§13.1, p.13-2). NARC runs the CPU from its 48 MHz input clock with
`CLKS_PER_STATE=8`. Microinstructions and `cen` pulses are implementation
details; their number is not a TI timing oracle.

The paired instruction counts mean **cache hit, cache disabled** (§12.10,
p.12-34; §13.1, p.13-2). A hit assumes the instruction and its extensions
are already resident. A cold miss includes a four-word subsegment fill
(§5.4.3, pp.5-22–23). Fetches can overlap preceding execution. Cache
disabled timing includes physical instruction/extension fetches.

The current probes measure the interval from accepting the opcode into IR
to accepting the following opcode. Initial scalar warm programs run twice, using only
two cache segments, and measure the second pass. Later control-flow fixtures
also warm their targets and check their segment-capacity assumptions. Twelve NOPs separate
setup from the measured instruction and follow it. These first probes are
register-only instructions with no hidden data writes. The suite asserts
that a warm hit causes zero external cycles and that the cache-disabled
interval contains exactly one following-opcode read, with IAQ asserted.
Two sequential-miss NOP probes measure the first pass instead: the current
word is at the end of a resident subsegment and the next four words have
not been fetched. They check the nine-state miss penalty and four ordered
read cycles. Their initial opcode is resident, so its acquisition stays
outside the interval.
It checks A0–A3 and the entire ST before the following
instruction executes. Reset, cold fills and initial register setup are
outside the interval. No architectural register is forced by the bench.
REV checks only its TI-defined result bits 15..3 (p.12-233); bits 31..16
and 2..0 are explicitly undefined. Other observed register bits and all ST
bits retain their comparisons. These scalar fixtures use register file A;
timed coverage of file B and shared-SP aliases remains required outside
the data-load fixtures, which initialize and check B0..B3 and SP as well.

The bench instantiates `jttms10_system`, including the real field adapter,
cache, arbiter and TI bus timer. Its raw target supplies readiness/data after
`4 + 8*N` INCLK. The fabric supplies the two-state cycle and samples ready
at the end of Q1, adding whole wait states. Thus warm hits gain no external
delay, CD gains `8*N`, and the four-word miss gains `4*8*N`.
`BUS_BEGIN/ACCEPT/END` record logical TI allocation/completion and actual
bridge acceptance; `TARGET_BEGIN/END` separately record raw transport.
Kind/address/IAQ/data/order, both durations and the target's ready window
remain asserted. Original electrical pin edges and separate LRDY/data
availability are outside this abstract port. The standalone timer oracle
covers all first-state dispatch phases and raw ready delays 0..40; the full
CPU matrices currently use readiness at four clocks plus whole-state delays.
See [bus-timing.md](bus-timing.md) for the source-backed contract and limits.
Refresh, video, host traffic and HOLD are disabled for these intrinsic
measurements. Their timing tests remain required work.

`--pause-clocks N` pauses CEN early in the measured CPU work. Registers,
PC and ST must stay stable, retirement and new cycles must stop, and the
cached duration increases by exactly N INCLK. The next external read also
waits for its bus-state boundary: the current seven-clock pause adds one
alignment clock, giving eight added clocks before CD/miss traffic. Base TI
counts are unchanged. Cache/fabric clocks continue during that pause.
Pauses overlapping an outstanding bus read or
its ACK need separate expectations and are not covered by this early-pause
rule.
`--pause-after-clocks N` moves the pause into CPU work; the selected
instruction must still be executing without an outstanding bus cycle.
The normal runner includes pauses 32 INCLK into a signed division's
restoring loop with cache hit and CD+wait. A/B/MD/TMP and the iteration count must also hold during
these CPU-work pauses. This option does not establish ACK-during-pause
behavior, which needs a separate bus-aware fixture.
The separate `ver/load_pause/check.py` event bench now covers a response
arriving during a postincrement load's pause for three A/B/SP identities.
It checks response retention, CPU hold and one ordered read, with a deliberate
duplicate-read regression. Its conservative completion bound is not an exact
TI instruction timing proof for an overlapping CPU-only CEN pause. The normal
matrix retains exact base counts; other outstanding-response cases remain open.
The instruction sequencer's address and prime/execute phase must also hold;
interrupt acceptance is gated by the CPU enable. This closes an earlier
prime-phase advance that final writeback padding could otherwise conceal.

Hidden states (§13.1.1, pp.13-2–3) are trailing memory writes that can
overlap subsequent execution. Future memory/graphics tests must measure
both the CPU boundary and the lifetime/order of those writes, including
subsequent bus dependencies. Delaying retirement alone cannot establish
that contract. Interrupt recognition and resumable graphics checkpoints
also need event-level assertions.

## Independent expectations and reproduction

`ver/timing/oracle.py` contains handwritten TI counts/equations. It does not
read HDL, YAML microcode, generated ROMs, or previous measurements.
`ignore_cycles: true` in the microcode YAML skips JTFRAME's `fix_cycles`
and `report_cycles` generator bookkeeping (`ucode.go`); it does not gate or
alter these independent simulator checks.

```sh
python3 modules/jttms10/ver/timing/run.py --report timing.json
python3 modules/jttms10/ver/timing/run.py --wait-states 1 --report timing-wait.json
python3 modules/jttms10/ver/timing/run.py --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --simulator verilator --report timing-verilator.json
python3 modules/jttms10/ver/timing/run.py --case mpys_fs2_positive_even_hit --traces timing-traces
python3 modules/jttms10/ver/timing/run.py --case divs_even_boundary_26_hit --pause-clocks 7 --pause-after-clocks 32
python3 modules/jttms10/ver/timing/mutations.py
python3 modules/jttms10/ver/timing/coverage.py --report timing-coverage.json
```

The runner generates ROMs in its own temporary build directory, compiles
the committed bench with Icarus, and runs committed program constructors.
It needs Python 3, PyYAML, Icarus/vvp and the repository's JTFRAME tool.
No development `/tmp` paths or external captured programs are inputs.
`--report` and `--traces` retain reviewable evidence. Any mismatch returns
nonzero, including when a report is requested. Reports contain conditions,
expected states, observed INCLK count, architectural values and measured
bus events. Functional success does not waive timing failures.
It runs programs in one simulation, resetting the full system and test
memory between cases; no expected counts enter the HDL. Case identities,
ordering and the final batch marker are checked so a missing or duplicated
case cannot borrow another result. `--separate-processes` provides a fresh
simulator per case for isolation cross-checks. The 1,148-case matrix before
adding the literal SLA examples matched exactly between both modes,
including every measured bus trace.

Icarus remains the command-line default. Verilator plus a C++ compiler is
optional locally and is used for the large matrices in CI; the normal runner
selects it with `JTTMS10_TIMING_SIMULATOR=verilator`. The same 1,148-case
matrix matched exactly between Icarus and Verilator. The latter reduced
compile-and-run time from 91 seconds to about two seconds in this workspace.
These runtime measurements are harness performance, not emulated CPU timing.
`--trace-core` adds microaddress and controller/cache/bus handshake clocks
to retained logs. Reports include source and generated-ROM hashes.

The mutation test first runs positive controls, then modifies fresh temporary
copies. A fixed FS1=32 timing bug and a counter that continues through CEN
pauses must both fail timing while retaining correct architectural state.
A separate stimulus mutation omits the requested external wait; both its
wrong bus duration and instruction timing must be rejected. Compilation or
functional failures do not count as successful timing-mutation detection.
A fourth mutation restores that old prime-phase advance and must fail the
explicit sequencer-hold assertion. It is an event-contract check, separate
from the three demonstrations that finish with correct architectural results.
A fifth mutation removes SETF's F=1 extra state and must fail timing while
returning the correct field definition and architectural state.
Two further RTL mutations reproduce a one-state-short odd DIVS minimum
candidate and failure to shorten a divide-by-zero path. Both must fail
timing while finishing with the correct registers and ST.
Two bus-timer RTL mutations remove the two-state minimum or sample ready
at cycle end instead of Q1. Correct architectural results must still fail
the independent instruction and bus checks.
A further RTL mutation omits cache-miss processing. The next bus phase and
state-grid checks must reject it even if instruction duration coincidentally
matches; architectural values remain checked.
Four immediate RTL mutations remove a short-form state, omit extension
processing, lose intrinsic states after an extension fill or assert IAQ
for a CD extension. All must fail with correct registers/ST.
Five load mutations delay the first bus slot, consume sign work during a wait,
charge full-width FE, absorb a sub-state pause or cache data reads. They also
must fail with correct registers/ST.
Four further load-mode mutations reject incorrect predecrement/offset lead
states and premature first/second address words. The current suite runs 62
positive controls and 70 rejection checks. Three rejection checks target
sequencer/pending-field/late-program-data event contracts; the others retain correct
architectural results (and drained memory for store mutations). The response-retention
event bench separately runs nine controls and one duplicate-read mutation.

## Coverage ledger

This ledger records the present scope explicitly. A rule with no committed
probe remains unvalidated. `ver/timing/coverage.py` lists all 133 instruction
forms with individual TI entry-page citations. It fails on absent probes;
it also fails on unresolved source overrides, even if every form has
probes. The normal gate applies the explicit owner-selected interpretations
in [source-policy.md](source-policy.md), preserving every alternative. Numeric source alternatives are audited independently of their
status labels. An agreed published target differing from the selected
policy is reported separately from conflicting TI sources. The current
92,138-case inventory has 11,219 discrepancy instances before project choices:
242 stores, six aligned absolute MOVE load CD cases, 1,996 untaken JR,
1,376 CMPXY, 16 CVXYL result differences, 100 copy index12 CPU cases and
332 byte-copy CD cases, 642 pointer-copy alternatives and 1,882 source-extension and 4,331 two-address-copy alternatives and 296 EMU alternatives. The normal gate records 10,771 explicit project
choices and retains 448 unresolved MOVB cases. Forty-five instances have
matching entry/summary targets, distinguished from source conflicts.
The JSON preserves every affected name, condition-specific value and
citation. Numeric metadata must match the actual selected expectation;
status relabeling cannot waive a gap. The stricter source-only audit remains
available. These are counts of probe instances, not distinct rules.
There are 138 checker/model tests. Probe presence and resolved or explicitly
selected source interpretations remain necessary gates; neither completes
the condition/bus/interrupt audit.
The full #144 checklist remains open.

| Rule | TI source | Present coverage | Compliance |
|---|---|---|---|
| Eight INCLK per machine state | §1.3.1.5 p.1-7; data sheet p.A-41 | Explicit unit conversion in oracle and system bench | Contract established |
| MPYS: `5+FS1/2`, `8+FS1/2` | pp.12-164–165 | All 16 defined even widths, both source-field signs, even/odd destinations, cache hit/off; arithmetic/full-ST checks | Current probes pass |
| MPYU: MPYS counts plus one state when source field is negative | pp.12-166–167 | Same widths/signs/parities/cache modes; ignored high bits distinguish field sign from bit31 | Current probes pass |
| NOP: 1,4 | p.12-170 | Warm hit/cache disabled, full ST/register preservation | Current probes pass |
| ADD: 1,4 | p.12-36 | Warm hit/cache disabled, arithmetic/flags | Current probes pass |
| MOVK: 1,4 | p.12-161 | Warm hit/cache disabled, value/flags | Current probes pass |
| SLA: 3,6; SLL/SRA/SRL/RL: 1,4 | pp.12-234–235, 12-239–246 | 850 programs: both encodings/cache modes, all counts, sign/zero/minimum boundaries, aliases, ignored count bits, flags and literal TI SLA examples | Current probes pass |
| LMO: 1,4 | p.12-108 | 76 programs: every leading-bit position, zero/dense sources, aliases and source-zero Z | Current probes pass |
| ADD/ADDC/SUB/SUBB/CMP: 1,4 | pp.12-36–37, 12-53, 12-247–248 | Signed/unsigned boundaries, carry/borrow, equal operands, aliases, both cache modes and unchanged destination for CMP | Current probes pass |
| ADDK/SUBK/MOVK; INC/DEC: 1,4 | pp.12-40, 12-61, 12-91, 12-161, 12-251 | All encoded constants 1..32; zero, signed maximum and unsigned maximum; explicit alias entries | Current probes pass |
| AND/ANDN/OR/XOR; NOT/CLR: 1,4 | pp.12-42, 12-44, 12-51, 12-171–172, 12-255 | Zero/dense/complement operands, aliases, Z and preservation of other flags | Current probes pass |
| ABS/NEG/NEGB: 1,4 | pp.12-35, 12-168–169 | Zero, signed endpoints and TI ABS examples; both initial carry values; ABS N from 0-Rd | Current probes pass |
| MOVE/MOVX/MOVY: 1,4 | pp.12-126, 12-162–163 | Full/half register results, aliases and specified flag masks | Current probes pass |
| BTST K: 1,4; BTST RR: 2,5 | pp.12-46–47 | Every bit both set/clear; ignored high bits of register count; no destination modification | Current probes pass |
| SEXT: 3,6; ZEXT: 1,4 | pp.12-238, 12-257 | Both fields, every width 1..32, zero/minimum/dense/mixed values, FE opposite to operation | Current probes pass |
| SETF F=0: 1,4; F=1: 2,5 | p.12-237 | Both fields, every size encoding and FE; preservation of unrelated ST bits | Current probes pass |
| EXGF: 1,4 | Summary p.12-17; operation p.12-78 | Both fields, six field definitions, discarded upper register bits and preserved flags | Current probes pass; instruction entry omits timing, summary supplies it |
| GETPC/GETST/REV; CLRC/SETC: 1,4 | pp.12-52, 12-89–90, 12-233, 12-236 | All 16 initial NCZV patterns; post-opcode bit address; revision defined-bit mask | Current probes pass |
| DINT/EINT/PUTST: 3,6 | pp.12-62, 12-76, 12-229 | Full ST effects and preserved registers; both initial IE values | Current intrinsic probes pass; interrupt acceptance remains unvalidated |
| DIVS/DIVU/MODS/MODU normal/special/exception counts | pp.12-63–66, 12-113–114 | 902 programs: parities, zero/early/late overflow, minimum quotient, sign/remainder boundaries, aliases and 24 literal TI examples in each cache mode | Current probes pass; MOD wording interpretations documented in [divide.md](divide.md) |
| Bus minimum and ready sampling | pp.11-8, 11-16; Appendix A p.A-21 | 699 independent timer scenarios: all first-state dispatch phases, ready delays 0..40, held ACK, new/queued requests and data retention | Logical bus/transport contract passes; original pins/separate LRDY/data not generated |
| I/O fixed duration and ignored ready | p.11-14 | Timer tests with ACK permanently low/high; timed queued-host I/O and system register/IRQ regression | Two-state/ACK-independent contract passes; exact internal I/O latch edge excluded as undocumented |
| External wait addition | §13.1.2 p.13-3; §11.4.10 p.11-16 | Full CPU raw ready at 4/12 INCLK, logical bus duration 16/24; exact added delay and independent target/start/order checks | Current probes pass |
| Immediate forms: IW 2,8; IL 3,12 | ADDI pp.12-38–39, CMPI 12-54–55, MOVI 12-159–160, SUBI 12-249–250; ANDI/ANDNI 12-43/45, ORI 12-173, XORI 12-256 | 2,828 programs: source-level encoding/sign/flags, warm word alignments and first/second-extension misses; per-word waits and IAQ | Current probes pass; [immediate-timing.md](immediate-timing.md) records the contract and exclusions |
| ADDXY/SUBXY/CMPXY | SPVU001A pp.12-41/56/252, summary12-12; SPVS002C June1991 p.11 | 4,156 programs: independent signed halves/flags, literal examples, A/B/SP, aliases, ignored field widths/FE and CEN phases | ADDXY/SUBXY hit/CD1/4; CMPXY summary3/6 conflicts with entry1/4 and remains blocked; see [xy-timing.md](xy-timing.md) |
| CPW/CVXYL:1/4 and3/6 | SPVU001A pp.4-12,6-15,12-57..60; SPVS002C June1991 p.11 | 5,116 programs: signed/window boundaries, all pitch/pixel sizes, implicit B registers, aliases, OR/offset wrap, flags/fields, CEN and immediate branch targets | Count probes pass; four printed CVXYL result examples conflict with the formula. See [coordinate-timing.md](coordinate-timing.md) and the documented project choice |
| JUMP/EXGPC, DSJ/EQ/NE/S and conditional JR/JAcc | SPVU001A pp.12-70..79,92..98; SPVS002C June1991 p.14 | 15,542 programs: both paths, all conditions/flags, A/B/SP, target alignment, displacement endpoints, literal PCs, CEN phases and immediate target fields | Current selected-count probes; untaken JR source discrepancies and the inferred long-JR CD5 remain explicit in [control-timing.md](control-timing.md) |
| Register lists MMFM/MMTM | §12 entries; §13.1.1 | Not yet covered by timing probes | Unvalidated |
| TRAP | SPVU001A8.6 p8-9;12-253/254 |1,800 full-state/memory/vector programs,16 following loads,150 short-phase programs |16/19 aligned,30/33 otherwise; literal timing-table applicability chosen for TRAP0. See[trap-timing.md](trap-timing.md). |
| CALL/CALLA/CALLR | SPVU001A12-48/49/50; stack order12-253 |1,306 programs,84 following A/B loads, ordered posted writes and short pauses |Entry counts pass targeted probes; cold/cache/IRQ conditions remain open. See[call-timing.md](call-timing.md). |
| Plain memory-to-memory MOVE/MOVB | Tables13-3/4 pp.13-6/7; entries12-119/137/138 | 6,860 programs: widths/alignments, fields/FE, A/B/SP, overlap/wrap, literal memory, following consumers and CEN phases | Field index12 selects CPU7 rather than printed 5; byte index2 CD9 versus printed7 remains a target gap. See [copy-timing.md](copy-timing.md) |
| Pointer memory-to-memory MOVE | Tables13-3/4 pp.13-6/7; entries12-141/142/145/146 | 8,936 programs: both pointer modes, widths/alignments, fields/FE, A/B/SP, sequential aliases, literal data/pointers, following loads and CEN | Three alternatives follow the recorded owner choice. Complete validation is in progress; see [pointer-copy-timing.md](pointer-copy-timing.md). |
| POPST | SPVU001A3-6/12-227; summary12-17; SPVS002C June1991p14 | 806 full-state/read-only-memory programs, including24 real following loads; aligned/unaligned response pauses |8/11 aligned,10/13 otherwise; remaining stack/call forms and full IRQ/HOLD audits stay open. See[stack-timing.md](stack-timing.md). |
| RETS | SPVU001A3-6/12-232; summary12-17; SPVS002C June1991p14 |1488 PC/SP/full-ST/read-only probes,48 real A/B target loads, aligned/unaligned response pauses |7/10 aligned,9/12 otherwise. Five-bit N0..31/default0; prose32 excluded. See[return-timing.md](return-timing.md). |
| RETI | SPVU001A3-6/12-230/231; summary12-17; SPVS002C June1991p14 |1412 PBX=0/no-pending-IRQ probes,48 A/B target loads; two separate32-bit fields |11/14 aligned,15/18 otherwise. Exact PBX resumption and last-state IRQ acceptance stay open. See[interrupt-return-timing.md](interrupt-return-timing.md). |
| PUSHST | SPVU001A3-6/12-228; SPVS002C June1991p14 |1522 full-state/drained-memory probes,224 real following loads |CPU2; H3/CD8 aligned,H8/CD13 otherwise. Printed example address labels excluded from numeric-semantic probes. See[push-timing.md](push-timing.md). |
| EMU with RUN asserted | SPVS002C June1991 p14; SPVU001A12-17/77 | 296 full-state/field/position cases, plus eight separate pulse controls and one missing-strobe mutation | Project6/9 follows summary/data sheet; entry8/11 retained. RUN-low hold/resume remains open. See [emu-timing.md](emu-timing.md). |
| Two-address MOVE/MOVB | Tables13-3/4 pp.13-6/7; entries12-121/124/151/157 | 13,714 programs: both offsets/absolutes, all widths/byte alignments, signed endpoints, cold operands, double fills and following loads | Entry/summary alternatives remain explicit. See [copy-pair-timing.md](copy-pair-timing.md). |
| Extended-source postincrement MOVE | Tables13-3/4 pp.13-6/7; entries12-149/150/155/156 | 8,812 programs: offset/absolute source, all widths/indices, aliases, cold operands, following loads and CEN | Entry/summary alternatives remain explicit; full validation is in progress. See [source-copy-timing.md](source-copy-timing.md). |
| Indirect MOVE/MOVB loads | Table13-1 p.13-5; pp.12-118,12-135–136 | 4,424 fixtures: all widths/offsets, both fields/FE/cache, aliases, literal TI examples, ordered uncached data/IAQ, per-word waits and early CEN phases | Current probes pass; [load-timing.md](load-timing.md) records scope/exclusions |
| MOVE post/pre/offset/absolute and MOVB offset/absolute; load B/SP conditions | Table13-1 p.13-5; pp.12-120,123,139–154; §5.4.7 | 3,200 additional fixtures, A/B/SP aliases/wrap, displacement/ignored-byte-field boundaries, cold address-word fills and six early CEN phases | Current probes pass; absolute MOVE entry conflicts with summary, with explicit oracle policy in [load-timing.md](load-timing.md) |
| MOVE register to indirect/post/pre and MOVB register to indirect | Table13-2 p.13-6; pp.12-115,127–131; hidden states pp.13-2/3 | 3,344 store cases plus 70 following-load dependency probes, preserved memory, ordered RMW/writes beyond the next decode, file B/SP/aliases and waits/CEN | Current probes pass; [store-timing.md](store-timing.md) records the contract and source conflicts for other modes |
| MOVE/MOVB register to offset/absolute | Table13-2 p.13-6; pp.12-116/117,132–134; §5.4.7 | 1,054 additional probes: literals, high/wrapped addresses, first/second-extension misses, both FE values and dependent loads | Probes pass under the documented policy; 242 explicitly inferred conflict-resolution cases are excluded from unqualified TI-count signoff |
| ACK while CPU CEN is paused | Wrapper extension; TI bus counts still apply | Nine A/B/SP and aligned/unaligned stack-response controls plus duplicate-read mutation | Functional response retention only; overlapping-pause exact instruction timing not claimed |
| Remaining memory/hidden-write conditions | §13.2 Tables13-1–13-4 | Form probes exist; consecutive writes and full cache/dependency/contention audits remain | Incomplete condition audit |
| Pixel/LINE/FILL/PIXBLT timing, windows, word boundaries | §12 entries and §13.3–13.5 | Not yet covered by timing probes | Unvalidated |
| Sequential subsegment miss | §5.4.7 p.5-24 | First-pass NOP probes, four ordered two-state reads plus processing; 80 INCLK without waits | Current directed probes pass |
| Cache replacement/prefetch and other overlap | §5.4; §13.1 | Functional cache tests; full timing conditions still incomplete | Unvalidated |
| CEN pauses during CPU work | Wrapper clock-enable contract described above | Seven paused clocks before work and 32 clocks into a division loop; architectural/working state, duration and read-start checks | Current directed probes pass |
| Timed arbiter HOLD/RMW/host interference | §11.3 p.11-4 | Pre-dispatch HOLD, stale-write cancellation, reread, reserved write and queued two-state host I/O | Directed word-client contract passes |
| CPU HOLD/restart, interrupts/resumption and contention; ACK during CEN pause | §8; §11; §13.1.2 | Full CPU timing conditions still incomplete | Unvalidated |
| Standard-runner/CI timing gate | #144 acceptance criteria | `ver/run.sh` and GitHub Unit Simulations job run the strict suite | Gate added; currently red |
| Checker regression detection | #144 acceptance criteria | 138 checker/model tests; actual RTL/stimulus/event mutations integrated in the runner | Current demonstrations pass |
| Post-change area/STA/NARC checks | #144 acceptance criteria | Pending implementation fixes | Pending |

Odd or out-of-range multiplication field sizes are not defined by TI's
multiply description (pp.12-164/166). The oracle rejects those requests;
this does not exclude any of the 16 defined even widths.

Initial measurements on unmodified CPU commit
`740709abbf72cb8af0f5e5e7668753979f5fd28f`: 262 programs, all architectural
checks passed, **254 timing failures**. Every multiply took 87 INCLK on a
warm hit and 104 with the cache disabled, irrespective of width or sign.
NOP took 11/28 INCLK, ADD and MOVK 13/30. The eight passing multiplication
cases are coincidences with individual published counts, not compliance
across the timing rule. Machine-state alignment, cache/fetch overlap and
the FS1/sign-dependent schedule require implementation changes.
The [baseline observations and CPU source hashes](../ver/timing/baseline-740709a.json)
are retained as historical evidence and are never read by the oracle.
The standard runner and CI deliberately fail on this baseline. No expected
failure list masks the 254 mismatches while implementation work continues.

The scalar expansion adds 3,360 fixtures to the previous 1,188, for 4,548
programs per wait/pause profile. Before its RTL changes, 1,556 of the first
3,168 new scalar probes failed timing on `421774c3d`, while all architectural
checks passed. The nine failing forms were ABS, BTST RR, SEXT, ZEXT, SETF,
EXGF, DINT, EINT and PUTST. Representative hit/off failures and source hashes
are retained in [baseline-421774c.json](../ver/timing/baseline-421774c.json).
This historical file is never read by the oracle or runner. The subsequent
MOVK constant expansion adds 192 cases and is not included in that baseline.

The subsequent divide/modulus expansion adds 902 fixtures, giving 5,450
programs per matrix. All 902 failed timing on scalar-stage `21cf1d6f2` while
retaining correct registers/ST. Representative failures by count/cache rule
are retained in [baseline-21cf1d6.json](../ver/timing/baseline-21cf1d6.json),
again historical evidence only. The standard runner runs three full matrices
and one mid-loop CEN probe, totaling 16,351 timing programs.

The bus-timed stage adds two sequential-miss fixtures. Its normal runner
uses three 5,452-case matrices and two mid-loop CEN probes, totaling 16,358
instruction timing programs, alongside 699 timer scenarios and the timed
arbiter interference bench. The [fast-target baseline](../ver/timing/baseline-bus-e146386.json)
shows the missing cycle floor at `e14638639`: 8/20/35 INCLK for NOP
hit/CD/miss versus TI 8/32/80, with correct architecture. Earlier slow-target
measurements supplied that missing delay in the target and did not prove
NARC's actual fast-response timing. Historical reports are not allowlists.

The immediate expansion adds 2,828 programs, for **8,280 cases per matrix**
and **24,842 instruction programs** across three matrices and two mid-loop
CEN probes. Twelve more forms have probes (66/133; 67 remain missing).
The [immediate timing report](immediate-timing.md) records the primary rules,
2,341 historical timing failures with correct architecture, per-word wait
and IAQ checks, all word alignments and first/second-extension misses.


The indirect-load expansion adds 4,424 programs for **12,704 cases per
matrix** and **38,120 instruction programs** across three matrices, two
mid-loop DIV probes and six sub-state load-pause probes. Coverage is 68/133
forms, with 65 missing. All 4,352 original matrix cases failed timing with
correct architecture on `22e601063`; the [load report](load-timing.md)
records the baseline, DSP/early-dispatch changes and independent read oracle.

The remaining load-mode expansion adds 3,200 programs, giving **15,904
cases per matrix** and **47,762 exact instruction timing programs** across
three matrices, two mid-loop DIV probes and six eight-case CEN-phase unions.
Coverage is **74/133 forms**, with 59 missing. Thirty-four checker/model tests,
20 positive controls and 23 rejection checks accompany those exact counts.
The separate response-retention event bench adds three controls and one
duplicate-read mutation; these are not included in the exact program total.
On unchanged `06843c78c`, 2,800 of the first 3,164 new cases fail timing with
correct architecture. The [load report](load-timing.md) records the source
conflict, alias interpretation, historical baseline and separate event scope.


The hidden-write expansion adds **3,414 programs**, giving **19,318 cases
per matrix** and **58,004 exact timing programs** across three matrices,
two DIV pauses and six eight-case phase unions. Four more forms have probes
(78/133; 55 remain missing). Thirty-eight checker/model tests, 21 positive controls and 26 rejection
checks accompany those probes, including store posting, cached write
overlap and the separate pending-field event assertion.
The [store report](store-timing.md) records the 3,344 historical timing
failures with correct architecture/memory and the new trailing-write observer.


The extension-store expansion adds **1,054 programs**, giving **20,372
cases per matrix** and **61,202 exact timing programs** across three matrices,
two DIV pauses and six fourteen-case phase unions. Coverage is **82/133 forms**,
with 51 missing. Forty-one checker/model tests, 23 positive controls and
28 rejection checks accompany the probes. Printed-count conflicts remain
explicit in the [store ledger](store-timing.md); passing an inferred-policy
case is not unqualified TI-count signoff. The standard presence gate remains
necessary only; all remaining condition/bus/interrupt and final hardware
requirements stay open.

The control-flow expansion adds **15,542 programs**, giving **35,914 cases
per matrix** and **108,020 timing programs** across three matrices, two DIV
pauses and six 46-case phase unions. Nine additional forms have probes
(91/133; 42 remain missing). Fifty-two checker/model tests, 32 mutation
positive controls and 39 rejection checks accompany the probes. The latter
comprise 36 timing/stimulus demonstrations and three event contracts.
[control-timing.md](control-timing.md) records the newer data-sheet minimum
for untaken long JR, the conflicting older counts, direct timed program
reads, trace boundaries and post-branch register/field dependencies.


## Current implementation boundary

The cache returns its synchronous RAM output during HIT, without an extra
response register clock. Fetch and dispatch share a microinstruction; the
response latch gives the synchronous dispatch ROM a full clock to select
the family before IR/PC commit. This brings a register ADD's work and cached
fetch within one eight-clock machine state.

A scheduling counter currently applies to the scalar/immediate forms
listed above, all memory-to-register MOVE/MOVB modes, all register-to-memory MOVE/MOVB modes (with explicit source policies), DIV/MOD and defined
even-width MPYS/MPYU. It holds the final architectural writeback until four
clocks remain for overlapping the next cached fetch. MPYU adds a state from
the captured source-field sign. A cache hit response is identified explicitly;
external opcode and extension reads, including fills, complete the additional
processing state after the timed bus transfer. Immediate cache misses preserve
the remaining intrinsic word states before final writeback and next fetch. The counter freezes
with CEN, while ACK capture remains independent of CEN. The checks assert
both instruction duration and logical/target fetch events; there is no waiver for
late or early bus activity hidden by an otherwise correct total.
DIV/MOD begin at their normal budgets, subtract the omitted states at an
early operand-check exit, and add the specified signed minimum-candidate
states after division. [divide.md](divide.md) lists the counts, primary
versus secondary discrepancy and explicit MOD wording interpretations.
ABS computes its result and specified N/Z/V in one final microinstruction,
preserving C. SEXT/ZEXT extend the synchronous destination-register data
directly into the shared field-extension network, eliminating the extra
capture step that exceeded ZEXT's one-state budget. Register BTST, SETF F=1,
SEXT and status-writing instructions receive their distinct published
state counts. Interrupt acceptance after an IE change still needs directed
event tests before its timing contract can be signed off.

Other instruction families retain their earlier schedule. They need a full
timing audit and, where required, faster datapaths and memory/graphics
overlap. The coverage gate keeps the normal runner/CI failing on those
missing forms even after all current scalar probes pass. Final fitted area,
FPGA setup/hold and NARC validation have not been repeated for this state.

The XY arithmetic expansion adds **4,156 programs**, giving **40,070 cases
per matrix** and **120,560 timing programs** across three matrices, two DIV
pauses and six 58-case phase unions. ADDXY/SUBXY/CMPXY add three forms
(94/133; 39 missing). Fifty-six checker/model tests, 34 mutation positive
controls and 41 rejection checks accompany this inventory (38 timing/
stimulus, three event contracts). [xy-timing.md](xy-timing.md) records
the shared packed-half adder, literal flags, independent coordinates and
CMPXY entry1/4 versus summary3/6/data-sheet minimum3 conflict. Its 1,376
source-policy instances increase unresolved acceptance probes to 3,620.
These are documented test contracts; full issue acceptance remains open.

The coordinate expansion adds **5,116 programs**, giving45,186 per matrix
and135,956 exact timing programs across three matrices, two DIV pauses
and six66-case unions. CPW/CVXYL add two forms (96/133;37 missing).
The scalar shared ALU/DSP replaces their graphics-engine dispatch without
adding DSPs or storage. All5,116 historical programs fail timing with
correct architecture on70acbfee2;73 representatives are committed.
[coordinate-timing.md](coordinate-timing.md) records the independent
window/conversion models, literal examples, synchronous read priming and
source discrepancies. The owner authorizes the simpler implementation
when reliable source clarification cannot be found; printed alternatives
and agreed published-target gaps remain explicit. This choice is not an
official TI erratum or full issue acceptance.

The owner's ambiguity fallback is recorded in [source-policy.md](source-policy.md).
It selects the current simple schedules/formula for 3,520 conflicting-source
probe instances. The gate retains 116 unresolved absolute-MOVB probes,
including 27 with matching published targets; all 37 missing forms also
remain blockers. No HDL, microcode, timing golden, result expectation or
encoded program changes in this source-policy step. The source-only audit
remains available and reports all 3,636 discrepancies. These are explicit
project interpretations, not official TI errata or full compliance signoff.

The plain-copy expansion adds **6,860 programs** for **52,046 per matrix**
and **156,608 exact timing programs**, including twelve additional early-CEN
probes and 120 dependent loads. It covers 98/133 forms (35 missing).
Eighty-five checker/model tests and 40 mutation controls/48 rejection checks
accompany the inventory. [copy-timing.md](copy-timing.md) records the shared
field/DSP path, literal memory, handoff, read waits and hidden-write rules.
The stricter audit has 4,068 discrepancies; the normal gate records 3,620
project choices and 448 unresolved MOVB probes, including 45 agreed targets.
The pre-response-tag-fix map (`e98c970fc`) estimates 3,517 ALMs/five DSPs. Final fitted-area ≤3,500 ALMs,
STA and NARC acceptance remain open, along with all remaining issue scope.


The pointer-copy expansion adds **8,936 programs** for **60,982 per matrix**
and **183,512 exact timing programs**, including sixteen additional phase
probes and 200 following loads. It covers 100/133 forms (33 missing).
Ninety checker/model tests and 44 mutation controls/52 rejection checks
accompany the inventory. [pointer-copy-timing.md](pointer-copy-timing.md)
records the pointer-update order, overlap and primary-source alternatives.
The normal gate retains 448 unresolved MOVB probes and records 4,262
project-choice instances; the strict audit retains all 4,710 discrepancies.
Full normal/clean-checkout and new resource validation are in progress;
final fitted-area/STA/NARC and all remaining issue requirements stay open.

The extended-source expansion adds **8,812 programs** for **69,794 per matrix**
and **210,188 exact timing programs**, including 24 cold operands, 16 warm
phase probes and 200 following loads. It covers 102/133 forms (31 missing).
Ninety-six checker/model tests and 47 controls/55 rejection checks accompany
the inventory. [source-copy-timing.md](source-copy-timing.md) records the
operand/data timeline, primary alternatives and example-label limitations.
The normal gate records 6,144 explicit choices and retains 448 unresolved
MOVB probes; the strict audit retains all 6,592 discrepancies. Complete
normal/clean-checkout/resource validation and all final issue gates remain
open.

The two-address expansion adds **13,714 programs** for **83,508 per matrix**,
with 106/133 forms present (27 missing). Its 96 cold cases include a
five-word absolute instruction whose following opcode needs a second fill
behind the posted writes. There are 32 new warm phase probes, 240 following
loads and 154 literal programs. All 69,794 previous fixture/program/golden
hashes are unchanged. Full validation for this stage is in progress; see
[copy-pair-timing.md](copy-pair-timing.md).

The EMU RUN-high expansion adds296 programs for83,804 per matrix and
107/133 forms (26 missing). It keeps full ST under the later data-sheet
requirement, retains the earlier8/11 versus chosen6/9 count alternatives,
and separately checks the actual acknowledgement pulse in eight controls
and one missing-strobe mutant. The shared normal bench is unchanged.
All83,508 preceding fixture/program/golden hashes remain unchanged.
Full normal-runner, clean-checkout and hardware validation for this stage
remain pending; see[emu-timing.md](emu-timing.md).

POPST adds806 programs for84,610 per matrix and108/133 forms (25 missing).
Its782 direct cases and24 real following loads retain full state, read-only
memory and independent bus checks.112 models pass; mutation classification
now rejects bad following state/memory before calling a failure timing-only.
The separate response bench has five controls, including aligned/unaligned
POPST captures during96-clock CPU pauses, and the original duplicate-read
mutation. Full normal-runner, clean-checkout and final hardware gates remain
pending; see[stack-timing.md](stack-timing.md).

RETS adds1488 programs for86,098 per matrix and109/133 forms (24 missing).
All32 argument encodings, stack alignments, full return addresses and48 real
A/B following loads remain checked. The two new timing mutations retain
correct main/following state and read-only memory. The response-retention
bench now has seven controls and one duplicate-read mutant. No new timing
source choice or known-target waiver is added. Full standard-runner and
clean-checkout acceptance remain pending; see[return-timing.md](return-timing.md).

The isolated RETS fit at dc661d409 uses3,649 ALMs,149 above the3,500 limit,
with68 RAM blocks and five DSPs. Internal four-corner STA at20ns has
minimum setup+1.567ns/hold+0.163ns. External virtual I/O remains unconstrained;
full NARC board timing closure and the final implementation's area remain
required. This result does not pass the area acceptance gate.

RETI adds1412 programs for87,510 per matrix and110/133 forms (23 missing).
The base contract has PBX clear and no pending IRQ. Two independent32-bit
pops charge every transfer, including the repeated unaligned boundary word.
The following-load and response-pause checks retain full state/memory.
Exact PBX resumption and enabled last-state interrupt acceptance remain
open; see[interrupt-return-timing.md](interrupt-return-timing.md).

The combined EMU+POPST108-form stage at3840d02f4 completes an uninterrupted
standard runner:255,500 exact timing programs,112 models,180 architectural
programs,699 bus scenarios,53 mutation controls and61 rejection checks.
Exit1 is solely the25-missing/448-unresolved source/coverage gate. Its clean
validation is targeted296+806 new programs/models/events; full clean-runner
acceptance remains open. Its two parameter-header date comments differ
across midnight; all functional generated contents match exactly, with raw
hashes and a same-day rebuild retained. Newer RETS109-form full validation
is running; RETI110-form validation is targeted. These scope distinctions
remain necessary, and no full ISA signoff is claimed.

PUSHST adds1522 programs for89,032 per matrix and111/133 forms (22 missing).
It uses the existing full-width field path and a shared-ALU SP decrement,
with two CPU states and overlapped writes. A corrected slot permission
prevents one-clock CEN pauses from being absorbed by aligned writes. The
224 following loads retain exact residual stalls and full initialized
register/memory checks. The permanent mutation suite has62 controls and70
rejections, including the new short-pause regression. Full Icarus/clean and
standard-runner validation remains pending; see[push-timing.md](push-timing.md).

PUSHST's initial full runner exposed a real MSW-order regression despite
passing timing/state probes. Descending full-field writes now preserve the
unchanged legacy stack-order assertion (SPVU001A12-253). A fifth PUSHST
mutant restores ascending order with correct duration/state/memory and must
fail bus sequencing. The field unit checks1024 forward/descending vectors
and both HOLD restarts. The corrected source requires a fresh full runner;
the initial failed111-form run is not accepted.

The109-form RETS stage atdc661d409 also completes an uninterrupted standard
runner:260,012 exact programs,117 models,180 architecture,699 bus scenarios,
55 mutation controls and63 rejection checks. Exit1 is solely24 missing forms
and448 unresolved source probes. All43 source and seven generated hashes
match. Clean validation remains targeted. CurrentPUSHST111-form targeted
validation passes1522 exact I/V/clean cases,128 models,66 short phases,
five new mutants,1024 field vectors and the unchanged MSW-first regression.
Its fresh corrected full runner completes268,910 exact programs,128 models,
180 architecture,699 bus scenarios,62 controls and70 rejections, with exit1
solely at22 missing/448 unresolved sources. The earlier failed111-form run
is not accepted. Final full clean/remote CI and hardware acceptance remain
open.


CALL/CALLA/CALLR add1,306 programs for90,338 per matrix and114/133 forms
(19 missing), using the existing ALU/TMP/MD and descending posted field
writes. The independent counts are3+(3)/9 or3+(9)/15 for CALL,
4+(2)/15 or4+(8)/21 for CALLA, and3+(2)/11 or3+(8)/17 for CALLR
(aligned/unaligned). All133 models, strict lint, the original MSW-first
word regression and all1,306 W=1/CEN=7 Verilator programs pass. Five new
actual RTL mutants fail with correct main/following state and memory,
including the two short-pause guards and ordered writes. Six short Icarus
profiles pass28 programs each (168); their source hashes match the final
inputs. All1,306 case objects and46 source/generated provenance hashes match
Icarus/Verilator and a detached clean checkout exactly. The clean scope is
133 models,1,306 stressed programs and response9/1 events, not a full standard
runner. Four fresh-process probes match batching except local identifiers. The matched map estimates3,689 ALMs,5,258 ALUTs,1,725
registers,538,624 RAM bits,five DSPs and zero MLAB bits. All36 snapshot hashes
and29 committed physical inputs verify; the same46 warning classifications
remain. These are synthesis estimates, without a current fit/STA claim. The full114-form standard
runner has not completed. All89,032 prior fixture/program/golden hashes
remain unchanged. All1,306 baseline programs on1a771f905 fail timing/bus
checks with correct main/following state and drained memory;20 verified
representatives are committed. See[call-timing.md](call-timing.md) for
primary counts, explicit example-label exclusions, fixture guards and
remaining conditions. No source exception or known MOVB waiver is added.


The uninterrupted corrected111-form PUSHST runner is verified at1cd86d712
(isolatedf25d09e05):268,910 exact programs,128 models,180 architecture,
699 bus scenarios,62 mutation controls/70 rejections, response9/1 and EMU8/1.
All45 timing-source and seven generated hashes match the implementation/map.
Exit1 is solely22 missing/448 unresolved sources. This is a development
standard runner; clean scope remains targeted. The current114-form CALL
full runner remains pending, and all final issue gates stay open.


TRAP adds1,800 programs for92,138 per matrix and115/133 forms (18 missing).
All138 models, strict lint, unchanged MSW-first regression,150 short Icarus
phase programs and1,800 W=1/CEN=7 Verilator programs pass. Five new timing/bus
mutants are rejected with correct state/memory, including the actual TRAP0
short-pause prototype. The separate response bench passes13 controls/one
mutation, including TRAP vector-read and stack-write responses during CPU
pauses. All1,800 historical probes on2b4fb7683 fail timing/bus checks with
correct full architectural/following state and memory; ten representatives
retain verified old HDL/YAML hashes. See[trap-timing.md](trap-timing.md) for
source interpretation, event scope and current exclusions. All1,800 Icarus/Verilator case objects and47 timing-source/generated hashes
match exactly;90,338 previous fixture/program/golden hashes remain unchanged.
A detached clean checkout repeats138 models, all1,800 stressed cases and
response13/1 events with exact source/generated hashes and observations.
Four fresh-process probes match batching except local identifiers. Clean
scope is targeted; the115-form full runner remains pending. The current map estimates
3,719 ALMs/five DSPs; final fitted area and hardware acceptance remain open.


The initial115-form standard runner passes the architecture/unit/model,
bus and response/event prefix, then stops before the large matrices at an
outdated XY/coordinate mutation injection anchor. The TRAP scheduler added
a prefix before decode_control. The helper now inserts each deliberate
regression at the unique decode_states assignment, preserving the new
TRAP branch. All47 runtime timing inputs and generated ROMs are unchanged;
no targeted runtime is repeated for this helper/documentation-only fix.
A fresh uninterrupted standard runner is required; the failed invocation
is not accepted as a completed full-runner milestone.


The uninterrupted114-form CALL development runner is verified at7b7b40ffc:
272,972 exact programs,133 models,180 architecture,699 bus scenarios,
67 mutation controls/75 rejections,response9/1 and EMU8/1. All46 timing-source
and seven generated hashes match its implementation/map; exit1 is solely
19 missing/448 unresolved sources. The branch is newer with115 forms.
Its initial full runner failed a stale mutation anchor before matrices;
the helper-only correction's fresh full runner remains running. Final full
clean/CI, ISA/conditions and hardware/game acceptance remain required.
