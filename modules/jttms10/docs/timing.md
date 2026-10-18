# Instruction timing compliance (issue #144, in progress)

The CPU is **not fully instruction timing compliant**. The current timing
probes cover five of 133 instruction forms; the other 128 remain unvalidated.
The standard runner's coverage gate deliberately fails until that gap is
closed. Passing the present probe matrix is not full-ISA acceptance.
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
to accepting the following opcode. Each program runs twice, using only
two cache segments, and measures the second pass. Twelve NOPs separate
setup from the measured instruction and follow it. These first probes are
register-only instructions with no hidden data writes. The suite asserts
that a warm hit causes zero external cycles and that the cache-disabled
interval contains exactly one following-opcode read, with IAQ asserted.
It checks architectural registers and the entire ST before the following
instruction executes. Reset, cold fills and initial register setup are
outside the interval. No architectural register is forced by the bench.

The bench instantiates `jttms10_system`, including the real field adapter,
cache and bus arbiter. The physical target consumes ACK exactly 16 INCLK
periods after first observing a request. `--wait-states N` adds `8*N`
periods to every physical cycle. Thus cached register-only timings must
remain unchanged, while cache-disabled timings gain `8*N` for their one
physical read. Payload stability and request/ACK pairing remain asserted.
For these register-only cases, §5.4.7's extra three-state fetch cost is
modelled as the next physical read starting after the intrinsic CPU states,
followed by two read states and one processing state. The bench checks the
read's start independently of the final instruction count. This establishes
the model's cycle-interface ordering; original pin-edge phase is not proven
by this abstract interface. Non-state-aligned delayed ACKs, early ACKs and
contention still require further timing tests.
Refresh, video, host traffic and HOLD are disabled for these intrinsic
measurements. Their timing tests remain required work.

`--pause-clocks N` pauses CEN early in the measured CPU work. Registers,
PC and ST must stay stable, retirement and new cycles must stop, and the
duration/read-start must increase by exactly N INCLK. Cache/fabric clocks
continue during that pause. Pauses overlapping an outstanding bus read or
its ACK need separate expectations and are not covered by this early-pause
rule.

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
python3 modules/jttms10/ver/timing/run.py --case mpys_fs2_positive_even_hit --traces timing-traces
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
`--trace-core` adds microaddress and controller/cache/bus handshake clocks
to retained logs. Reports include source and generated-ROM hashes.

The mutation test first runs positive controls, then modifies fresh temporary
copies. A fixed FS1=32 timing bug and a counter that continues through CEN
pauses must both fail timing while retaining correct architectural state.
A separate stimulus mutation omits the requested external wait; both its
wrong bus duration and instruction timing must be rejected. Compilation or
functional failures do not count as successful timing-mutation detection.

## Coverage ledger

This ledger records the present scope explicitly. A rule with no committed
probe remains unvalidated. `ver/timing/coverage.py` lists all 133 instruction
forms with individual TI entry-page citations. It fails on absent probes;
probe presence alone does not complete the condition/bus/interrupt audit.
The full #144 checklist remains open.

| Rule | TI source | Present coverage | Compliance |
|---|---|---|---|
| Eight INCLK per machine state | §1.3.1.5 p.1-7; data sheet p.A-41 | Explicit unit conversion in oracle and system bench | Contract established |
| MPYS: `5+FS1/2`, `8+FS1/2` | pp.12-164–165 | All 16 defined even widths, both source-field signs, even/odd destinations, cache hit/off; arithmetic/full-ST checks | Current probes pass |
| MPYU: MPYS counts plus one state when source field is negative | pp.12-166–167 | Same widths/signs/parities/cache modes; ignored high bits distinguish field sign from bit31 | Current probes pass |
| NOP: 1,4 | p.12-170 | Warm hit/cache disabled, full ST/register preservation | Current probes pass |
| ADD: 1,4 | p.12-36 | Warm hit/cache disabled, arithmetic/flags | Current probes pass |
| MOVK: 1,4 | p.12-161 | Warm hit/cache disabled, value/flags | Current probes pass |
| External wait addition | §13.1.2 p.13-3; LRDY p.2-8 | Target latencies of 16 and 24 INCLK, exact added delay and bus/start/order checks | Current probes pass; other ACK phases unvalidated |
| Other scalar instructions, immediates, shifts/counts, LMO, divide/modulus exceptions | §12 instruction entries | Not yet covered by timing probes | Unvalidated |
| Branches, calls/returns/traps, register lists and hidden writes | §12 entries; §13.1.1 | Not yet covered by timing probes | Unvalidated |
| Memory fields/bytes and address/alignment modes | §13.2 Tables 13-1–13-5 | Not yet covered by timing probes | Unvalidated |
| Pixel/LINE/FILL/PIXBLT timing, windows, word boundaries | §12 entries and §13.3–13.5 | Not yet covered by timing probes | Unvalidated |
| Cache misses/fills, prefetch and bus overlap | §5.4; §13.1 | Hit/off bus checks only; no miss timing oracle yet | Unvalidated |
| Early CEN pauses | Wrapper clock-enable contract described above | Seven paused clocks before final writeback; full duration/state/read-start checks | Current directed probes pass |
| HOLD/restart, interrupts/resumption, host/peripheral contention; ACK during CEN pause | §8; §11; §13.1.2 | Existing functional tests do not prove instruction timing | Unvalidated |
| Standard-runner/CI timing gate | #144 acceptance criteria | `ver/run.sh` and GitHub Unit Simulations job run the strict suite | Gate added; currently red |
| Checker regression detection | #144 acceptance criteria | Eight checker tests, two RTL mutations and one stimulus mutation, each with positive controls | Current demonstrations pass |
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

## Current implementation boundary

The cache returns its synchronous RAM output during HIT, without an extra
response register clock. Fetch and dispatch share a microinstruction; the
response latch gives the synchronous dispatch ROM a full clock to select
the family before IR/PC commit. This brings a register ADD's work and cached
fetch within one eight-clock machine state.

A scheduling counter currently applies only to NOP, ADD, MOVK and defined
even-width MPYS/MPYU. It holds the final architectural writeback until four
clocks remain for overlapping the next cached fetch. MPYU adds a state from
the captured source-field sign. With CD, the fetch response completes the
additional processing state after the physical read. The counter freezes
with CEN, while ACK capture remains independent of CEN. The checks assert
both instruction duration and physical fetch start; there is no waiver for
late or early bus activity hidden by an otherwise correct total.

Other instruction families retain their earlier schedule. They need a full
timing audit and, where required, faster datapaths and memory/graphics
overlap. The coverage gate keeps the normal runner/CI failing on those
missing forms even after all current scalar probes pass. Final fitted area,
FPGA setup/hold and NARC validation have not been repeated for this state.
