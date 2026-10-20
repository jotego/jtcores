# Instruction timing compliance (issue #144, in progress)

The CPU is **not fully instruction timing compliant**. Timing probes are
present for all 133 instruction forms. Hardware `a59e15b08` passes all 141,972
ordinary fixtures in each base/W1-P7/W3 profile: 425,916 physical executions,
independently checked from raw captures. The W3 saved report contains one
trace-label discrepancy (`BUS_ACCERT` versus raw-derived `BUS_ACCEPT`);
the original is retained and the full raw audit finds no other field differences.
All 1,020 focused executions pass, with 702 declared independent reference
comparisons across overlapping subsets. These include stacked/no-stack NMI
and CPU-visible I/O preservation/clear checks. NMIM=1 total context duration
remains observed only. See the [current FPGA checkpoint](../ver/fpga/README.md#physical-nmi-checkpoint).
Probe presence and a passing matrix do not establish complete condition coverage.
PIXT register-to-linear covers replace and Boolean PPOP0..15 with PMASK0/T0;
arithmetic,masking,transparency and other conditions remain unvalidated.
Linear memory-to-memory PIXT covers replace/PMASK0/T0; register-to-XY
PIXT and DRAV cover replace/PMASK0/T0/W0. Other conditions remain unvalidated.
Aligned opaque W0 FILL L/XY and bounded replace-only LINE have independent
timing probes; their supported conditions and remaining exclusions are in
[FILL timing](fill-timing.md) and [LINE timing](line-timing.md).
Some printed counts conflict. The owner authorizes the simpler implementation
where reliable clarification cannot be found; explicit project choices keep
all alternatives visible. See [source-policy.md](source-policy.md).
Cached single-word absolute MOVB uses the one-state intrinsic count on which
both TI tables agree, including resident operands across cache subsegment
and segment boundaries. Its CD7 target remains a gap against the shared
CD15 schedule. Plain byte-copy index2 also has a CD7 versus current CD9 gap.
The standard coverage/source gate still fails on unresolved MOVB
source/policy differences, with the recorded project choices
applied explicitly. Passing the present probe matrix is
not full-ISA acceptance.
Architectural regression, FPGA setup/hold closure and instruction timing are
separate checks.

The historical native binary [DataStorm checkpoint](../ver/fpga/README.md) uses RTL
`2a5e4a6d95909c758d3041e0603fc6a8276fed60`. Full command walls are 305.33/311.54/323.21 seconds;
compilation/programming/preparation and transport phases are separately
recorded. The separate published-target command retains 27 CD duration failures.
Timeout and 512-record overflow preserve following cases and clean rearm. Native binary
IRQ/NMI continuation now passes the separate timed-word Verilator sweep;
this loaded image predates that change. FPGA HOLD/IRQ scheduling remains open.
Twenty added wide-row fixtures bring the inventory to 141,972; all
preceding contracts are unchanged. Their FPGA validation is included in the
current checkpoint above. Earlier
image results below retain their original identities.

The historical native-LINE [DataStorm image](../ver/fpga/README.md) passes all 141,236
existing fixtures in each of base, W1/P7-after0 and W3 profiles: 423,708 FPGA
executions on one image, including all 2,240 FILL and 626 LINE cases per
profile. Every raw capture was replayed with the unchanged independent Python
oracle. Twenty-nine focused physical observations match the original
Verilator bench, including architectural state, memory, instruction clocks
and checked bus events. These results supersede the pre-native-LINE broad
matrix's 606 duration failures for this scope. They do not complete the normal
runner, clean-checkout/CI, missing-form/condition audit or final physical/game
acceptance. That image predates the cached absolute-byte change. That preceding
inventory contains 141,428 cases, including 192 additional cached byte boundaries.
Its coverage/source gate then failed on six missing PIXBLT forms and 401
unresolved MOVB probes, including 27 agreed published-target gaps.

The newly fitted cached-MOVB image passes all 141,428 cases in each of the same
three profiles (424,284 physical executions), with 5,157 batches per profile.
Root independently replayed every raw result with the original Python checker.
All 69 focused positive observations match short original Verilator runs.
The separate 164-case published-target run returns exit 1: 137 pass and 27 CD
cases fail solely on duration. Full architectural/memory/bus observations and
error lists agree with Verilator even for those failures. Timeout and explicit
512-record overflow preserve the next independent case and clean rearm.
External full-command walls are 286.508/289.787/301.359 seconds. The single
retained-IP full Quartus flow takes 853.19 seconds (859.14 s outer helper);
all final constrained summaries and calibrated DDR margins pass. This is an
FPGA test appliance, not the CPU-only area or final NARC/MiSTer acceptance.
See [FPGA reproduction and measurements](../ver/fpga/README.md).

The new PIXBLT baseline uses the same physical CPU image with host-only fixtures
and checker additions. All 84 focused diagnostic observations match original
Verilator; all commands remain failing. The complete new 464-case base run
produces 311 individual timing failures plus 153 cases in nine overflow-rejected
batches. Final memory is actively checked for every individual verdict; 40 raw
cases explicitly hit the 512-record limit. All predecessor fixture/program
contracts remain unchanged. See [PIXBLT scope and evidence](blit-timing.md).

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

Verilator plus a C++ compiler is the command-line default. Icarus is
available through an explicit `--simulator iverilog` selection. The normal
timing runner and CI use Verilator unless `JTTMS10_TIMING_SIMULATOR`
explicitly overrides it. The same 1,148-case
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
policy is reported separately from conflicting TI sources. The historical
106,610-case inventory has 13,073 discrepancy instances before project choices:
242 stores, six aligned absolute MOVE load CD cases, 1,996 untaken JR,
1,376 CMPXY, 16 CVXYL result differences, 100 copy index12 CPU cases and
332 byte-copy CD cases, 642 pointer-copy alternatives and 1,882 source-extension and 4,331 two-address-copy alternatives and 296 EMU alternatives and 1,854 register-list hidden/applicability alternatives. The normal gate records 12,625 explicit project
choices and retained 448 unresolved MOVB cases. Forty-five instances had
matching entry/summary targets, distinguished from source conflicts.
The cached absolute-byte change resolves 47 of these source-policy instances;
the current normal gate retains 401 unresolved instances, including 27 agreed
CD targets. The JSON preserves every affected name, condition-specific value and
citation. Numeric metadata must match the actual selected expectation;
status relabeling cannot waive a gap. The stricter source-only audit remains
available. These are counts of probe instances, not distinct rules.
There are 165 checker/model tests. Probe presence and resolved or explicitly
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
| Register lists MMFM/MMTM | pp.12-109..112; §13.1.1 |3,572 full-GPR/state/memory probes,120 following loads,342 short phases |Literal CPU/CD equations; explicit hidden-state/empty-list project choices. See[list-timing.md](list-timing.md). |
| TRAP | SPVU001A8.6 p8-9;12-253/254 |1,800 full-state/memory/vector programs,16 following loads,150 short-phase programs |16/19 aligned,30/33 otherwise; literal timing-table applicability chosen for TRAP0. See[trap-timing.md](trap-timing.md). |
| CALL/CALLA/CALLR | SPVU001A12-48/49/50; stack order12-253 |1,306 programs,84 following A/B loads, ordered posted writes and short pauses |Entry counts pass targeted probes; cold/cache/IRQ conditions remain open. See[call-timing.md](call-timing.md). |
| Six PIXBLT forms | SPVU001A12-174..212; Tables13-8..13 pp.13-18..35 | 544 aligned opaque W0/PBH0/PBV0 fixtures, all pixel sizes and both cache modes; regular N1..4/L1..2, binary DX<=32 including N8/16/32 | Preceding 524 pass FPGA base/W1-P7/W3; 102 physical observations match Verilator. Binary IRQ source has 162 focused/geometry/wide Verilator passes. Regular IRQ source has 132 unchanged-oracle timing observations and timed-word sweeps of 3,280 regular /1,640 binary modes. Physical injection, long/partial rows and broader conditions remain open. See [blit-timing.md](blit-timing.md). |
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
| PIXT linear memory to register | SPVU001A pp.4-6,12-218/219; §7.3 | 4,159 full-GPR/state/read-only-memory programs,20 following loads, legal size/lane/plane-mask boundaries and cold next fills | 4/7 states; NCZ preservation and multibit V interpretation explicit in [pixel-read-timing.md](pixel-read-timing.md). Other pixel forms remain open |
| PIXT XY memory to register | SPVU001A pp.4-12/13,12-222/223; §7.3 | 3,917 full-GPR/state/read-only-memory programs,source pitches/planes/aliases and20 following loads | 6/9 states; targeted three-profile/clean/cross-simulator proof in [pixel-xy-read-timing.md](pixel-xy-read-timing.md). Full acceptance remains open |
| PIXT register to linear memory:replace/PMASK0/T0 | SPVU001A pp.12-213/214; §13.1.1 | 2,824 full-GPR/state/drained-memory programs,70 following loads and posted-response events | CPU2,H3/CD8 small;H1/CD6 at16 bits. Other PPOP/mask/transparency/SRT conditions remain unvalidated. See[pixel-store-timing.md](pixel-store-timing.md). |
| Pixel/LINE/FILL/PIXBLT timing, windows, word boundaries | §12 entries and §13.3–13.5 | Two scalar reads and the replace-write subset above have probes | Other graphics timing unvalidated |
| Sequential subsegment miss | §5.4.7 p.5-24 | First-pass NOP probes, four ordered two-state reads plus processing; 80 INCLK without waits | Current directed probes pass |
| Cache replacement/prefetch and other overlap | §5.4; §13.1 | Functional cache tests; full timing conditions still incomplete | Unvalidated |
| CEN pauses during CPU work | Wrapper clock-enable contract described above | Seven paused clocks before work and 32 clocks into a division loop; architectural/working state, duration and read-start checks | Current directed probes pass |
| Timed arbiter HOLD/RMW/host interference | §11.3 p.11-4 | Pre-dispatch HOLD, stale-write cancellation, reread, reserved write and queued two-state host I/O | Directed word-client contract passes |
| CPU HOLD/restart, interrupts/resumption and contention; ACK during CEN pause | §8; §11; §13.1.2 | Full CPU timing conditions still incomplete | Unvalidated |
| Standard-runner/CI timing gate | #144 acceptance criteria | `ver/run.sh` and GitHub Unit Simulations job run the strict suite | Gate added; currently red |
| Checker regression detection | #144 acceptance criteria | 165 checker/model tests; actual RTL/stimulus/event mutations integrated in the runner | Current demonstrations pass |
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
six new mutants,1024 field vectors and the unchanged MSW-first regression.
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
19 missing/448 unresolved sources. That report predates the115-form TRAP
captured phases and current117-form list implementation described below.
Final full clean/CI, ISA/conditions and hardware/game acceptance remain required.


MMFM/MMTM add3,572 programs, for95,710 per matrix and117/133 forms
(16 missing). [list-timing.md](list-timing.md) records the literal count
ledger, read-only MMFM/empty-list project choices, examples and selected
bus allocation. All3,572 Verilator stress programs,144 models,342 short
Icarus phases, six new mutants and response17/1 events pass. All588
representative Icarus case objects and48 source/seven generated hashes
match Verilator. A detached clean checkout repeats144 models, all3,572
stress cases and17/1 response events. Stressed case objects and48 source/
seven generated hashes match development; the clean event report's hashes
match the implementation. Its scope is targeted, not a complete standard runner. The matched map
estimates3,824 ALMs/1,722 registers/five DSPs; all36 snapshot hashes and29
inputs verify. No current fit/STA is claimed. The117-form initial full runner passed its architecture/unit/model/bus/event
prefix, then failed a stale mutation anchor before matrices. The branch and
copy helper anchors are corrected with all48 runtime inputs/ROMs unchanged;
fresh complete validation remains pending. The failed invocation is excluded
from completed-runner acceptance.
All31 distinct GPRs, full ST, sparse memory and120 following loads are
checked. No known MOVB target is waived; final fitted area/board STA/NARC
and remaining ISA/condition acceptance remain required.

All115-form runner phases at766ca98fa are captured and verified:
278,516 exact programs,138 models180 architecture699 bus scenarios,
72 controls80 rejections. All47 source/seven generated hashes match its
implementation/map. The wrapper session ended143 without a supervisor
final child-status record. This is captured-phase evidence, not a cleanly
completed-invocation claim; the latest verified invocation remains114-form
CALL. The cause of that termination is not inferred. Source/coverage
still reports18 missing forms448 unresolved probes for that older tree.


The117-form stressed proof at27b0d4e44/e633074cc did not cover the later
unpaused first-slot failure:1,778 cached list probes were one state late with
correct architecture/memory. The e633 full invocation was cancelled for that
demonstrated RTL bug before its matrices, not for an observation timeout.
The first-field phase1/phase2 correction now passes three separate3,572-case
base/wait/stress matrices (10,716 programs),342 short Icarus phases, seven
mutants,180 architecture, the original38-request MSW assertion, strict lint
and17/1 response events. All48 runtime-source/seven ROM hashes match those
profiles. New representative Icarus/clean validation and a fresh full runner
remain pending. The corrected map estimates3,824 ALMs/5,495 ALUTs/1,722
registers/five DSPs, without current fitting/STA. No source targets are waived.


Corrected299d97666 validation is verified: a clean checkout repeats144 models,
all10,716 targeted programs across separate base/wait/stress profiles and17/1
response events, with exact development case objects,48 source/seven ROM
hashes and event records. All588 representative Icarus stress cases and four
fresh-process base/stress comparisons match batching. All342 short phases
and seven correct-state/memory mutants pass. Corrected matched map3824ALM/
5495ALUT/1722registers/fiveDSPs has all36 snapshot hashes/29 inputs verified.
This is targeted clean evidence, not a full standard runner. A fresh full
invocation runs on frozen299d97666; no completed117-form claim is made.
No HDL/runtime/test expectation changes are made for this evidence update.


## Linear pixel-read milestone

PIXT *Rs,Rd adds4,159 fixtures for99,869 cases and118/133 forms (15 missing).
Implementation2d260be9f passes all three new profiles (12,477 programs),
151 models,180 architecture,102 short Icarus phases,three mutation controls/
rejections,21 response controls/one mutant and strict lint. A detached clean
checkout matches all three profiles,source/ROM provenance and response data
exactly. Two fresh-process stressed Icarus comparisons match Verilator;
full4,159-case Icarus comparison remains pending. Clean scope is targeted,
not a complete standard runner. [pixel-read-timing.md](pixel-read-timing.md)
records primary citations,undefined/ambiguous behavior,baseline and limits.

The corrected parent95,710 fixture/program/golden contracts are unchanged.
Matched map estimates3,825 ALMs,5,507 ALUTs,1,722 registers,538,624 RAM bits,
five DSPs,zero MLAB bits; all36 hashes/29 committed inputs verify. No fit/STA
acceptance is claimed. Fresh118-form standard runner is running frozen2d260be9f;
older117-form runner remains separate. No completed118 invocation is claimed.
The same12,625 project choices/448 unresolved MOVB instances,including45 agreed
targets,remain; no waiver is introduced. All final acceptance gates stay open.


## XY pixel-read milestone

PIXT *Rs.XY,Rd adds3,917 fixtures for103,786 cases and119/133 forms
(14 missing). Implementationadac0fbbd reuses the shared scalar DSP and ALU
for source-pitch conversion,then the scalar pixel path at6/9 states. All
11,751 programs in three separate profiles,158 models,180 architecture,
102 short Icarus phases,two new timing mutants/three affected linear mutants,
25 response controls/one mutant and strict lint pass. A detached clean
checkout repeats all three profiles,models and events with exact case
objects,50 source/seven generated hashes and response objects. All519
representative Icarus stress cases match Verilator except case ID; this is
not all3,917. Two fresh-process comparisons pass. Clean scope is targeted,
not a full normal runner. See[pixel-xy-read-timing.md](pixel-xy-read-timing.md).

The99,869 preceding fixture/program/golden contracts are unchanged.
All3,917 old probes fail timing/bus checks with correct architecture/memory;
85 representatives and22 old HDL/YAML hashes are committed. Matched map
estimates3,798 ALMs,5,504 ALUTs,1,722 registers,538,624 RAM bits,five DSPs,
zero MLAB bits; all36 snapshot hashes/29 committed inputs verify. No fit/STA
acceptance is claimed. Fresh119-form runner is running frozenadac0fbbd;
older117/118 runs remain separate. No completed119 invocation is claimed.
The same12,625 project choices/448 unresolved MOVB instances,including45
agreed targets,remain without a waiver. All final acceptance gates stay open.


## Completed corrected list runner and full linear-read crosscheck

The uninterrupted117-form standard runner at299d97666 is complete: all
289,568 exact timing programs pass (three95,710-case matrices,two DIV pauses,
six406-case phase unions). All144 models,180 architecture programs,699 bus
scenarios,79 mutation controls and87 rejections pass,alongside response17/1,
EMU8/1 and the original MSW-first stack assertion. All48 timing-source and
seven generated hashes match the committed implementation/synthesis snapshot;
the private whole tree remains identical to299d97666. Final supervisor status
is exit1 solely16 missing forms/448 unresolved source probes,including45
agreed targets. This supersedes114-form CALL as the latest accepted complete
development invocation; it does not establish full timing compliance.
Clean scope remains targeted144 models/10,716 new programs/response17/1,
not a full289,568-program clean checkout. The earlier117 base bug and its
cancelled runner remain excluded; the115 capture retains its wrapper143
limitation. No runtime was repeated for this documentation-only update.

The full4,159-case linear-pixel-read Icarus comparison also completed at
2d260be9f. Every stressed case object,49 timing-source hashes and seven
generated hashes matches Verilator exactly. This extends the earlier two
fresh-process comparison claim to the entire new linear-read matrix. Its
three-profile clean proof remains12,477 exact programs,151 models and
response21/1. The current branch has119 forms; its118/119 full runners remain
running frozen2d260be9f/adac0fbbd. All remaining ISA/conditions,known MOVB,
full clean/CI,final fitted area/board STA/NARC/MiSTer requirements remain open.


## Pixel replace-write subset milestone

PIXT Rs,*Rd adds2,824 fixtures for106,610 cases and120/133 forms (13 missing).
This covers **replace,PMASK0,T0 only**; other processing/masking/transparency/
SRT conditions remain unvalidated. Implementation187edd8df shares the scalar
posted field engine atCPU2,H3/CD8 for small pixels,H1/CD6 at16 bits. All8,472
programs in three profiles,165 models,180 architecture,102 short Icarus phases,
three new timing mutants/three affected linear mutants,29 response controls/
one mutant and strict lint pass. A detached clean checkout repeats all three
profiles,models and events with every case object,51 timing-source/seven
generated hashes and response object exact. All522 representative Icarus
stress cases match Verilator except case ID; this is not all2,824. Two fresh
process comparisons pass. Clean scope is targeted,not a complete normal runner.
See[pixel-store-timing.md](pixel-store-timing.md).

The posted event observes a real memory response during96 disabled CPU
clocks; CPU acceptance is acknowledged immediately. The original normal
timing bench remains unchanged. Failed pre-acceptance/logical-ACK probes
are excluded. All103,786 preceding fixture/program/golden contracts are
unchanged. All2,824 old probes fail timing/bus with correct architecture/
following state/memory;130 representatives and22 old HDL/YAML hashes are
committed. Map3817ALM5517ALUT1722registers538624RAM5DSP0MLAB,36hashes/
29inputs verify. No current fit/STA acceptance is claimed. New120-form
runner is running frozen187edd8df;118/119 remain separate. Latest accepted
complete invocation remains117-form lists289,568 programs. The same12,625
project choices/448 unresolved MOVB instances,including45 agreed targets,
remain without waivers. All final acceptance gates stay open.

### Completed linear and XY pixel-read standard runners

The uninterrupted118-form runner frozen2d260be9f passes302,525 exact timing
programs (3×99,869, two DIV pauses, six486-case phase unions),151 models,
180 architecture programs,699 bus scenarios,82 mutation controls/90
rejections,response21/1,EMU8/1 and the original MSW-first assertion. All49
source/seven generated hashes match the implementation/map. Exit1 is solely
15 missing forms/448 unresolved source probes,including45 agreed targets.

The uninterrupted119-form runner frozenadac0fbbd passes314,756 exact timing
programs (3×103,786, two DIV pauses, six566-case phase unions),158 models,
180 architecture programs,699 bus scenarios,84 controls/92 rejections,
response25/1,EMU8/1 and the original MSW-first assertion. All50 source/seven
generated hashes match. Exit1 is solely14 missing forms/the same448 source
probes. Its private whole Git tree remains identical toadac0fbbd.

The119-form invocation supersedes117-form lists as the latest accepted
complete development runner. The current120-form runner remains running
frozen187edd8df. Clean scope stays targeted12,477/11,751 programs in three
profiles,151/158 models and21/1 or25/1 events; neither is a full clean normal
runner. These results do not close remaining conditions,known targets,
full clean/remote CI,final fitted area/board STA or NARC/MiSTer acceptance.

### Boolean register-to-linear pixel writes

PIXT Rs,*Rd now also covers PPOP1..15 with PMASK0/T0. The6,264 additional
probes bring the inventory to112,874 cases,still120/133 forms with13 missing.
The native path reads the destination,processes through the existing pixel
network,then posts the result. No DSP/register bank/arithmetic unit is added.
[Pixel Boolean timing](pixel-boolean-timing.md) records the independent truth
model,literal TI examples,non-idempotent prefill measurement,exact bus/following
contracts,representative condition axes and remaining exclusions. All106,610
preceding fixture contracts remain unchanged. All154 historical representative
probes fail timing/bus with correct architecture/memory on187edd8df.

Boolean verification is complete: three6,264-case profiles (18,792 programs)
W0/P0,W1/P0,W1/P7 pass. Detached clean5a74e596e repeats all18,792,173 models
and33 response controls/one mutant. Every case object,52 timing-source/seven
generated hashes and response object matches development exactly. All586
representative Icarus stress cases match Verilator except batch-local ID;
102 short Icarus phases,two fresh-process cases,180 architecture programs,
strict lint and the original38-request MSW-first assertion pass. Three new
actual timing mutations and eight affected pixel controls/rejections retain
correct architecture/memory. All10,900 preceding pixel programs pass all
three profiles (32,700 checks). All106,610 preceding fixture contracts remain
unchanged. The initial586-case capture has wrapper143/no supervisor status;
it is excluded from completed-invocation claims. The detached rerun completes
with status0 and reproduces every case object exactly.

Matched map estimates3,868 ALMs,5,585 ALUTs,1,722 registers,538,624 RAM bits,
five DSPs and zero MLAB bits. All36 snapshot/29 committed physical inputs,
normalized QSF,SDC and49 warning classifications verify. Original live-capture
source_commit:null metadata is retained. This is synthesis only; no new
fit/STA acceptance is claimed. The final fitted ceiling remains3,500 ALMs.
Boolean full runner is running frozen5a74e596e; replace-only120 full runner
remains separate at187edd8df. Latest accepted complete invocation stays119
forms/adac0fbbd/314,756 programs. Clean proof is targeted,not a full normal
runner. The12,625 choices/448 unresolved MOVB probes/45 agreed targets and
all final acceptance gates remain open,without waivers.

### Linear memory-to-memory pixel replace

PIXT *Rs,*Rd adds5,856 fixtures for118,730 cases and121/133 forms (12 missing).
The source-read/scalar-posted path shares existing MD/EA/field/pixel machinery
and retains all31 GPR/full ST/memory checks. No DSP,register bank or ALU is
added. [Pixel copy timing](pixel-copy-timing.md) records TI's4/10 or4/8 counts,
all aligned literal examples,source/destination overlap,first-execution
measurement,bus/following contracts and remaining conditions. The inconsistent
PS16/20508 example is explicitly excluded under the owner's alignment-rule
interpretation. All136 historical representative probes fail timing/bus with
correct architecture/memory on3cdbdd220. No known MOVB target is waived.

Linear-copy targeted verification is complete: three5,856-case profiles
(17,568 programs) W0/P0,W1/P0,W1/P7 pass. Detached clean cabaf7c8b repeats
all17,568,179 models and37 response controls/one mutant. Every case object,
53 source/seven generated hashes and response result matches exactly.
All394 representative Icarus stress cases match Verilator except batch-local
ID,alongside102 short phases,two fresh-process cases,180 architecture programs,
strict lint and the original38-request MSW-first assertion. Three new actual
timing mutants and11 affected pixel controls/rejections retain correct full
architecture/memory. All112,874 preceding fixture contracts remain unchanged.
All136 old-core representative probes fail timing/bus with correct state/
memory;22 old HDL/YAML hashes verify. The wrong-dispatch-family prototype
failed its first batch program and is excluded; its repeated transcript is
not1364 independent failures.

Matched map estimates3,909 ALMs,5,643 ALUTs,1,722 registers,538,624 RAM bits,
five DSPs and zero MLAB bits. All36 snapshot/29 committed physical inputs,
normalized QSF,SDC and49 warning classifications verify. Original live-capture
source_commit:null metadata remains. This is synthesis only; final≤3,500
fitted ALMs/positive board STA remain required. Fresh121-form full runner is
running frozen cabaf7c8b; Boolean120 at5a74e596e remains separate. Clean scope
is targeted,not a full normal runner. No source target or final gate is waived.

### Completed120-form replace-write standard runner

The uninterrupted runner frozen187edd8df passes323,708 exact timing programs:
three106,610-case matrices,two DIV pauses and six646-case phase unions.
All165 models,180 architecture programs,699 bus scenarios,87 mutation controls/
95 rejections,response29/1,EMU8/1 and the original MSW-first assertion pass.
All51 timing-source/seven generated hashes match the committed implementation/
map,and its private whole Git tree remains identical to187edd8df. Final
supervisor exit1 is solely13 missing forms and448 unresolved source probes,
including45 agreed published-target gaps. This supersedes119/adac314,756 as
the latest accepted complete development invocation.

Its clean scope remains targeted8,472 programs in three profiles,165 models
and29/1 response events,not a full323,708-program clean normal runner. Its
historical map is3,817 ALMs/five DSPs; current121-form code is newer at3,909
map ALMs/five DSPs. Boolean120 and121-copy full invocations remain running;
no completed result for either is claimed. Full ISA/conditions/known targets/
cleanCI/final fitted area/board STA/NARC/MiSTer gates stay open.

### Register-to-XY pixel replace

PIXT Rs,*Rd.XY adds4,636 fixtures for123,366 cases and122/133 forms (11 missing).
Only replace/PMASK0/T0/W0 is timed. Shared CVXYL DSP products/ALU compute the
signed-Y destination-pitch conversion,then the scalar field engine posts the
color; no DSP/register bank/arithmetic unit is added. All31 GPRs,full ST and
memory checks remain active. [XY pixel-store timing](pixel-xy-store-timing.md)
records the literal TI counts/examples,independent equation,port sequencing,
alias/extent/exclusion rules,first-execution measurement and bus/following
contracts. All118,730 preceding fixture contracts remain unchanged. All136
representative old-core probes fail timing/bus with correct state/memory and
22 verified old HDL/YAML hashes. No known MOVB target or final gate is waived.

XY-store targeted verification passes all13,908 programs in three4,636-case
profiles W0/P0,W1/P0,W1/P7. Detached clean f99e1baa6 repeats all13,908,
187 models and41 response controls/one mutant; every case object,54 source/
seven generated hashes and response object matches development exactly.
All606 representative Icarus stress cases match Verilator except batch-local
ID,alongside102 short phases,two fresh processes,180 architecture programs,
strict lint and the original38-request MSW-first assertion. Three new timing
mutants and14 affected pixel controls/rejections retain correct architecture/
memory. All118,730 preceding fixture contracts remain unchanged. All136
historical old-core probes fail timing/bus with correct state/memory and22
verified old HDL/YAML hashes. The color/coordinate-port prototype and a
cancelled malformed mutation helper remain excluded; runtime simulations
were preserved when that helper was corrected.

Matched map estimates3,944 ALMs,5,677 ALUTs,1,722 registers,538,624 RAM bits,
five DSPs and zero MLAB bits. All36 snapshot/29 committed physical inputs,
normalized QSF,SDC and49 warning classifications verify. Original live-capture
source_commit:null metadata is retained. This is synthesis only; final≤3,500
fitted ALMs/positive board STA remain required. Fresh122-form full runner is
running frozen f99e1baa6;121-copy cabaf7c8b and Boolean1205a74e596e remain
separate. Latest accepted complete invocation stays120/187/323,708 programs.
Clean scope is targeted,not a full normal runner. All known source targets,
remaining ISA/conditions/fullcleanCI/finalhardware/game gates remain open.

### Draw-and-advance replace

DRAV adds6,126 fixtures for129,492 cases and123/133 forms (10 missing),only
replace/PMASK0/T0/W0. Shared scalar DSP products/ALU and existing registers/
field engine convert the old destination,select COLOR1's physical pixel,
post it and add X/Y halves separately for Rd. No DSP/register bank/ALU is
added. [Draw timing](draw-timing.md) records TI's4/10 or4/8 counts,all five
literal W0 replace examples,independent pointer/pattern model,aliases,
first-execution measurement,bus/following contracts and remaining exclusions.
The unsigned-multiply surcharge now requires a real multiply opcode; an
actual DRAV regression mutant restores the old one-state failure with correct
state/memory. All768 existing multiply timing programs pass three profiles.
All123,366 preceding fixture contracts remain unchanged;134 old-core probes
fail timing/bus with correct state/memory and22 verified old HDL/YAML hashes.
No known source target or final acceptance gate is waived.

DRAV targeted verification is complete: three6,126-case profiles (18,378
programs) pass W0/P0,W1/P0,W1/P7. Detached clean c5eb365d8 repeats all18,378,
197 models and45 response controls/one mutant. Every case object,55 source/
seven generated hashes and response object matches exactly. All724
representative Icarus stress cases match Verilator except batch-local ID;
102 short phases,two fresh processes,180 architecture programs,strict lint
and the original38-request MSW-first assertion pass. Four new actual timing
mutants and17 affected pixel controls/rejections retain correct state/memory.
All768 preceding multiply timing programs pass three profiles with the same
55 source/seven generated hashes. All123,366 preceding fixture contracts
remain unchanged. All134 representative old-core probes fail timing/bus with
correct state/memory;22 old HDL/YAML hashes verify. Initial24 timing-only
failures,failed Icarus elaboration and pre-portability Verilator captures
remain excluded from final-input acceptance.

Matched map estimates3,963 ALMs,5,747 ALUTs,1,722 registers,538,624 RAM bits,
five DSPs and zero MLAB bits. All36 snapshot/29 committed physical inputs,
normalized QSF,SDC and49 warning classifications verify. Original live-capture
source_commit:null metadata remains. No current fit/STA is claimed; final
≤3,500 fitted ALMs/positive board STA remain required. Fresh123-form full
runner is running frozen c5eb365d8;122 f99e1baa6 and121 cabaf7c8b remain
separate. Clean scope is targeted,not a full normal runner. No known target
or final acceptance requirement is waived.

### Completed120-form Boolean standard runner

The uninterrupted full runner frozen5a74e596e passes343,940 exact timing
programs: three112,874-case matrices,two DIV pauses and six886-case phase
unions. All173 models,180 architecture programs,699 bus scenarios,90 mutation
controls/98 rejections,response33/1,EMU8/1 and the original MSW-first assertion
pass. All52 timing-source/seven generated hashes match the implementation/
map; the private whole Git tree remains identical to5a74e596e. Supervisor
exit1 is solely13 missing forms/448 unresolved source probes,including45
agreed published-target gaps. This supersedes replace120/187/323,708 as the
latest accepted complete development invocation.

Clean scope stays targeted18,792 programs in three profiles,173 models and
33/1 response events,not a full343,940-program clean normal runner. Its map
is historical3,868 ALMs/five DSPs; current123-form code is3,963 map ALMs/five
DSPs. The121-copy runner has subsequently completed; see below. Newer122/123 full runners remain running. Remaining ISA/conditions/
known targets/fullcleanCI/final fitted area/board STA/NARC/MiSTer gates stay open.

### Complete121-form linear pixel-copy runner

Frozen cabaf7c8b completes361,988 exact timing programs: three118,730-case
matrices,two DIV pauses and six966-case short-phase unions. All179 models,
180 architecture programs,699 bus scenarios,93 mutation controls/101
rejections,response37/1,EMU8/1 and the original MSW-first assertion pass.
All53 timing-source/seven generated hashes match the committed implementation
and map; the whole private Git tree remains identical. The final supervisor
returns1 solely for12 missing forms and448 unresolved MOVB probes,including45
agreed published-target gaps. No known target is waived.

This supersedes Boolean120/343,940 as the latest accepted complete development
invocation. Clean scope remains targeted17,568 programs/179 models/response37/1,
not a complete361,988-program clean normal runner. Its historical map is3909
ALMs/five DSPs; the newer123-form DRAV source maps3963/five. Newer122/123 full
runners remain running. Full clean/remote CI,remaining ISA/conditions/known
targets,fitted<=3500 ALMs,positive board STA,NARC simulation/MiSTer gameplay
remain required. All nine issue tasks remain unchecked.

### XY-to-XY replace implementation

Native `PIXT *Rs.XY,*Rd.XY` now selects entry154 for replace/PMASK0/T0/W0,
with independent source/destination conversion and scalar read/post reuse.
The inventory becomes124/133 forms,9 bulk graphics forms missing,138,370
cases and206 models. Probe presence does not imply full condition coverage.
See [pixel-xy-copy-timing.md](pixel-xy-copy-timing.md) for the primary table,
transport contract and excluded prototype failures. Corrected-source targeted verification passes 26,634 clean timing programs,
206 models, response49/1, 180 architecture programs, 632 cross-simulator
comparisons, 198 short pause cases, two fresh processes and 24 pixel mutation
controls/24 timing rejections. Source/generated hashes and full case objects
verify as detailed in that report. No completed 124-form runner or final
signoff is claimed.

### Remaining FILL timing audit

[fill-timing.md](fill-timing.md) transcribes the primary setup, per-word
processing, alignment and row-length rules and checks the three literal
483/1113/1293-state examples. It records the short-D mask-adjustment and
non-word-multiple-pitch ambiguities explicitly. The independent FILL oracle has eight passing model tests. Four additional
fixture/checker tests cover 120 CPU probes for full-word replace FILL L/XY,
all sizes, N=1/2/3, one/two rows and both cache modes. These probes fail all
three profiles (360 cases) on unchanged HDL while preserving all defined
state and memory. No FILL timing compliance is claimed. Inventory becomes
126/133 forms and 138,490 fixtures, with seven forms missing and both FILL
forms failing. The permanent standard runner includes the tests/probes.
The still-running full runner frozen at 4f3b7d9ac predates these additions;
it remains a separate 124-form invocation. See that audit for scope,
reproduction commands and excluded domains.


The next linear FILL schedule adds140 longer cases while preserving the
original120 fixtures. Current inventory is126/133 forms and138,630 fixtures.
The200 aligned replace-only FILL L cases cover all five pixel sizes,
N=1/2/3/4/8, one through four rows, hit/CD, base, W1/P7 and W3.
These linear cases pass; the60 XY cases still fail overall timing.
There are now14 FILL oracle/fixture/checker model tests. Repeated-row and
within-row bus cadence are explicit constraints from the Table13-6 row
coefficient and G=2; the first-write phase and exact IRQ acceptance are
not claimed. Five positive controls reject five actual timing mutants,
including a row-drain removal that hides external wait time while retaining
correct defined state and memory. Wider conditions, full normal/clean/CI,
other graphics forms and final physical/game acceptance remain open.

An additional60 FILL L histories expose stale transparency after a real
zero-source transparent PIXT and subsequent CONTROL change to T0. The
full-word path now ignores the pixel transparency latch, as word grouping
requires PPOP0/PMASK0/T0. All60 fail against5edc71ed9 HDL by omitting
writes despite correct defined registers/ST; the current260 linear cases
pass base, W1/P7 and W3. Icarus matches all60 stressed history case objects,
W1/P1 passes60 histories and two fresh processes match the batch. The
preceding138,630 fixture/program contracts are unchanged; current inventory
is138,690 across126/133 forms. The60 XY timing failures and all broader
conditions/events and final acceptance gates remain open. See
[the history audit](fill-timing.md#opaque-fill-after-transparent-pixt).


### Aligned XY FILL timing checkpoint

The shared scalar conversion path and fused graphics prologue now meet the
aligned PPOP0/PMASK0/T0/W0 XY FILL setup and transfer contracts. The 2,240
FILL fixtures (260 linear, 1,980 XY) pass Verilator base, W1/P7, W3 and W1/P1,
with exact resumed stressed-case equality, short-pause/isolation probes and
seven controls/seven timing-mutant rejections. The inventory is 140,610 cases
and 126/133 forms; the preceding 138,690 contracts are unchanged. Fifteen
FILL models pass. Native XY interrupt continuation covers all sizes through
the direct architectural interface, not posted-wrapper acceptance timing.
The cancelled Icarus run remains incomplete; resumed work uses Verilator.
See [the XY audit](fill-timing.md#aligned-opaque-xy-fill-conversion-and-timing).
Broader conditions/events, seven missing forms, 448 MOVB source/target gaps
(including 45 agreed targets), full clean/CI and final area/STA/game gates
remain open.


### Verilator defaults on resumed development

The architectural YAML runner, timing runner, timing mutations (through that
runner) and bus-timing checker now default to Verilator. The normal shell
runner selects Verilator for its timing matrices by default. Architectural
vectors retain the original generated assertions and configuration values;
one model is compiled per invocation and each case runs in a separate
process selected by `+VECTOR`, preserving independent initialization.
Reset deasserts on the falling clock edge to avoid initial-block scheduling
ambiguity. An explicit `--simulator iverilog` remains available in those
Python runners. At checkpoint `7adec50e5`, legacy unit and response/EMU event benches in
`ver/run.sh` still invoked Icarus; the migration below completes that work.

Fresh default-engine verification passes all 180 architectural programs,
699 bus scenarios and seven FILL positive controls/seven timing rejections.
A deliberately wrong expected PC in a copied YAML fixture returns nonzero
with the original case/step/PC diagnostic. Fixture definitions and independent
expectations are unchanged. Area snapshots now default to `/opt/quartus_free`.
No new full normal-runner, clean-checkout or remote-CI result is claimed.


### Complete Verilator regression runner

`ver/run.sh` now executes all unit, architectural, response, EMU and timing
checks with Verilator by default. `ver/sim.sh UNIT` builds and runs the
existing unit benches, including both cache-field timing modes, all eight
system-control modes and linear/XY FILL IRQ/NMI at all five pixel sizes.
Generate microcode with `ver/build.sh` before invoking that helper alone.
Decoder-table preparation also uses this helper with
`TMS10_DISPATCH_GENERATE`: the original controller function generates the
2,048-entry image, which must still match the checked-in ROM. A clean-run
guard caught the old Icarus dependency in that preparation step after the
initial unit-bench migration; that initial frozen invocation failed before
running regressions. The corrected bootstrap and targeted suites run with
Icarus/vvp guard commands that fail immediately if invoked. All seven
generated images remain byte-identical to the preceding checkpoint.

The shared `ver/verilator_build.py` preserves fatal compiler warnings;
`--quiet` is enabled only on versions that support it, retaining compatibility
with the older Verilator installed by CI. Test benches now explicitly size
arithmetic and unused connections; invalid target FSM states fail. No CPU
RTL, fixture definition or timing oracle changes in this migration.

The response suite caches three compiled models (normal, posted and mutant),
then uses a fresh process for each independent case. All 49 controls and
the deliberate duplicate-read rejection pass. Their 50 complete result
objects exactly match the saved Icarus clean response report. The EMU monitor
wraps the original bench under one top module; eight positive controls and
one missing-acknowledgement mutant pass with two compiled models. All 18
unit configurations pass, including 174,689 pixel cases, 1,024 field vectors,
646 RF cycles and the original 38-request MSW-first write assertion.
These are targeted results, not a completed full normal/clean/CI invocation.

When `JTTMS10_TIMING_REPORT` is set, its original filename holds the base
matrix. The runner now also retains full JSON observations for wait, stress,
DIV pause and six short-pause profiles, with suffixes `.wait.json`,
`.stress.json`, `.div-hit.json`, `.div-off.json` and `.phase-N.json`.
Bus, response, EMU, mutation and coverage reports use matching suffixes.
The CI artifact glob retains these reports. A failing check still stops the
runner and returns nonzero; the coverage/source gate still rejects the seven
missing instruction forms and unresolved MOVB targets.

```sh
bash modules/jttms10/ver/build.sh
bash modules/jttms10/ver/sim.sh word
bash modules/jttms10/ver/sim.sh arrayirq +FILL_PSIZE=16 +FILL_XY=1
python3 modules/jttms10/ver/load_pause/check.py --report response.json
python3 modules/jttms10/ver/emu/check.py --report emu.json
JTTMS10_TIMING_REPORT=/path/to/timing.json bash modules/jttms10/ver/run.sh
```


## Deterministic control-ROM sampling

The CPU and graphics YAML opt in to JTFRAME's `latch_nonblocking: true`
with `latch_ucode: true`. This emits a synchronous nonblocking ROM read:
clocked consumers see the previous control word on the prime edge and the
primed word on the execute edge. The old blocking read could make a data ACK
appear to overlap an extension microinstruction differently between simulators.
Verilator consequently missed the original `data_ack_as_extension` mutant.
The permanent nonblocking build preserves the cold-fill positive control
(136 INCLK with W1/P1) and rejects that same mutant at 144 INCLK with correct
architecture. An ineffectual mutation is never counted as a passing rejection. Other modules retain the generator's blocking default.
Generated HDL uses a text template so the `<=` operator is emitted literally.

The latest [LINE audit](line-timing.md) adds 626 independent probes to the
normal runner. Their failing baseline establishes 127/133 forms and 141,236
fixtures, without claiming that LINE timing is compliant.

### Partial-word FILL edge baseline

The permanent `fill_partial_` subset adds 140 one-row B/C/D probes across
PS1/2/4/8, N1/2/3, L/XY and both cache modes. Inventory grows to 142,112 cases;
form presence remains 133/133. The preceding 2,240 aligned FILL fixture/program
contracts are unchanged. Ten short CPU77 Verilator representatives fail TI
duration targets with correct checked architecture and memory; eight also
reject extra per-pixel word transactions. All140 also fail duration in each BASE/W1P7/W3 FPGA profile, with108/profile
additionally failing word-transaction counts. Six surrounding NOP executions
pass, all420 failing raw verdicts replay exactly, and30 representative
diagnostic observations agree with Verilator. These failures remain required
fixes. See the [partial-word audit](fill-timing.md#partial-word-edge-timing-baseline).
The [multirow partial baseline](fill-timing.md#multirow-partial-word-timing-baseline)
appends 280 two/four-row constant-alignment probes without changing the
preceding 2,380 FILL fixture/program contracts. Inventory is now 142,392 cases
across the same 133 forms. Seven directed multirow cases fail duration on the
native one-row implementation while an aligned control passes; architecture,
memory and checked transactions remain correct. Expanded FPGA runs remain
required; these probes do not establish multirow timing compliance.
Known MOVB targets, these FILL gaps and the remaining conditions prevent
unqualified timing compliance. No task or acceptance gate is waived.
