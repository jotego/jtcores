# Control-flow timing (issue #144, partial)

`ver/timing/control_cases.py` supplies independent timing and architectural
expectations for JUMP, EXGPC, DSJ/DSJEQ/DSJNE/DSJS, short/long JRcc and JAcc.
There are **15,502 programs**, taking the total matrix to **35,874** and form
presence to **91/133**. Forty-two forms still lack probes. Source overrides
remain separate acceptance blockers; probe presence is not full signoff.

The [historical baseline](../ver/timing/baseline-control-8488555.json) uses
unchanged `8488555fb` RTL/YAML. **12,955 of 15,502 programs fail** their
timing/bus checks, with zero register/ST/target-opcode or following-field
memory failures. Forty-four path/cache/literal/following-field cases and
22 verified historical HDL/YAML hashes are retained as evidence, never
loaded as an oracle or failure allowlist. Every form has baseline failures;
some untaken short-JR/DSJ cases already happened to match.

## Primary counts and discrepancies

Sources are TI's June 1988 User's Guide SPVU001A and the June 1991 revision
of [data sheet SPVS002C](https://www.farnell.com/datasheets/84292.pdf), p.14.
The latter's minimum counts distinguish taken/untaken paths, **not** hit/CD.
The guide's paired numbers distinguish hit/CD (p.12-34). Counts below use
the guide entries except the newer data-sheet minimum for untaken long JR.

| Form/path | Selected hit/CD states | Guide entry |
|---|---:|---|
| JUMP, EXGPC | 2/5 | 12-98, 12-79 |
| DSJ/DSJEQ/DSJNE taken | 3/9 | 12-70..74 |
| DSJ/DSJEQ/DSJNE untaken, including inhibited decrement | 2/8 | 12-70..74 |
| DSJS taken | 2/5 | 12-75 |
| DSJS untaken | 3/6 | 12-75 |
| Short JR taken | 2/5 | 12-94/95 |
| Short JR untaken | 1/4 | 12-94/95 |
| Long JR taken | 3/6 | 12-96/97 |
| Long JR untaken | 2/5, with CD inferred | SPVS002C p.14 minimum; see below |
| JAcc taken | 3/6 | 12-92/93 |
| JAcc untaken | 4/7 | 12-92/93 |

The scanned pages contain real discrepancies, not OCR errors:

| Untaken form | SPVS002C p.14 minimum | SPVU001A entry hit/CD | SPVU001A summary p.12-18 hit/CD | Selected hit/CD |
|---|---:|---:|---:|---:|
| Short JR | 1 | 1/4 | 2/5 | 1/4 |
| Long JR | 2 | 4/7 | 1/4 | 2/5 |

The long-JR minimum is also 2 in the guide's older embedded device table
(Appendix A, p.A-16). The implementation follows the newer data sheet's
cached minimum. Its selected CD5 is an explicit inference: minimum2 plus
the normal three-state following-opcode fetch, with the unused offset
skipped. It is not a CD count printed in either older table. No official
erratum is claimed. Each affected row retains `datasheet_cpu`, entry,
summary and selected counts in `source_values`; the acceptance gate keeps
both forms' untaken discrepancies open. The cached long-JR target itself
comes from the data sheet, not a measured RTL latency.

Taken JAcc's CD6 covers three two-state transfers. Applying a blanket
three-extra-states-per-word equation would silently replace its printed
count. The implementation instead overlaps operand capture and direct
dispatch with the timed word cycles. The source ledger retains the actual
instruction-specific counts and does not use the generic equation as an
override.

## Programs and checks

The matrix covers every condition code and all sixteen NCZV patterns for
conditional jumps, both outcomes, positive/negative displacements and
signed 16-bit endpoints. Decrement tests include 0/1/2/9, signed minimum
and all ones; the **original Z** gates both decrement and jump for DSJEQ/NE.
Both register banks, shared SP, all sixteen ignored low target-PC bits,
opcode word offsets and zero/nearby/self targets are exercised. Full ST,
A0..A3, B0..B3 and SP are compared before the target instruction executes.

Targets normally contain NOP and return through A12 to initialization, so
both first-pass outcomes restore the original operands before measurement.
Sparse full-address target words exercise displacement wrap without
aliasing the transport's address. Nearby targets use the first pass only;
their opcode fill already contains the target. Their actual following
opcode is checked, including self jumps and targets inside instruction
words. The observer receives program/address selections, not golden counts
or register results.

Four EXGPC probes use TI's literal PCs/targets on p.12-79: PC2080, targets
1C10/1C50, saved return2090, in both cache modes. Eight additional CD
programs execute a real load or store immediately at JR-long/JAcc targets.
They check the following instruction's exact time, registers/ST and drained
memory, catching a correct branch followed by a stale register-port read.
The independent field models are separately anchored to literal expected
data (`4B2D` for the load and preserved words `9B6D/CDB6/35C6` for the store).

CD reads check every required extension in order with IAQ low, followed by
the target opcode with IAQ high. Untaken JR-long/JAcc skip unused address
words; DSJ retains its offset fetch even when Z inhibits decrement. This
fetch policy follows the conditional operation descriptions and fetch-on-
request rule (§5.4.7 p.5-25); exact original internal microinstruction edges
are not specified by those descriptions. Extended-branch bus checks assert
order, addresses/data, non-overlap, the state grid, interval containment,
two-state duration, per-transfer waits and raw target dispatch/ACK. They do
not invent an exact internal first-read slot. Single-word forms retain the
fixed following-fetch slot. Cached probes require zero external traffic.

The direct following decode may coincide with the preceding opcode's bus
completion. Trace selection therefore uses opening-inclusive/closing-
exclusive allocations and opening-exclusive/closing-inclusive completions.
It neither counts the prior opcode ACK nor a following load's allocation
as part of the measured branch. Store drain observation remains separate.

## Implementation and regressions

Control-flow budgets select their path after the synchronous destination
read and original flags are valid. DSJ preserves remaining CPU work after
an external offset response and paces its first request so an early CEN
pause cannot disappear inside fetch latency. The existing issue counter
and PC adder are shared; no new arithmetic unit or DSP is added.

Untaken extended jumps redirect during ROM priming to PC-increment-only
helpers. JAcc combines address-word capture with its two reads and final
PC write. Taken extended CD jumps bypass cache transport registration,
using the real timed fabric's retained read data. `TIMED_PROGRAM` is enabled
by the system wrapper; generic/raw clients leave it off. The timed port
captures readiness/data by Q1 and holds it through Q4, giving the dispatch
ROM a settled clock before direct opcode acceptance. A permanent assertion
and deliberate late-data mutation enforce that prerequisite. No original
LAD/RAS/CAS electrical pins are generated by this interface.

Fast following fetches also prime the actual source/destination register
ports before ACK. A full-matrix failure exposed B/SP counters selecting
the wrong timing path despite correct final arithmetic; the ordinary
post-decode microcode had eventually read the right register. Both that
timing regression and the immediate target load/store checks remain.

The suite has **52 checker/model tests**, **31 mutation positive controls**
and **38 rejection checks** (35 timing/stimulus, three separately identified
event contracts). New RTL mutations shorten JUMP/DSJS, lose DSJ post-fetch
work, absorb its pause, fail to prime the counter, restore long-JR's older
four-state untaken path, serialize branch words or read unused extensions.
A further mutation preserves JR-long's correct 48-INCLK total while its
target read takes 24 instead of 16 clocks; independent bus assertions must
reject it. Late program data is an event-contract violation, not a
correct-architecture timing-only demonstration.

The standard runner contains three complete matrices, two DIV pauses and
six 46-case short-CEN unions: **107,900 timing programs**. The new 32
control-path phase cases cover both cache modes under every early pause
length 1..6; the full stress matrix uses seven paused clocks and one wait
state per transfer. A cached duration gains exactly the pause; CD gains
its alignment plus each requested transfer's wait. Outstanding-response
pauses need separate event expectations and remain outside this early rule.

## Remaining scope

This stage does not complete source resolution, cold branch/target misses,
replacement/prefetch, preceding hidden-write dependencies, CPU HOLD/IRQ
acceptance, graphics resumption or the other missing forms/conditions.
The eight post-branch field probes cover ordinary RAM and do not establish
internal-I/O or implicit-peripheral dependency timing. All final fitted-area
≤3,500 ALMs, positive STA and NARC simulation/MiSTer gates remain required.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator --case control_
python3 modules/jttms10/ver/timing/run.py --case control_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case control_jr_long_phase_ --wait-states 1 --pause-clocks 1
python3 modules/jttms10/ver/timing/mutations.py
python3 modules/jttms10/ver/timing/coverage.py --report timing-coverage.json
```
