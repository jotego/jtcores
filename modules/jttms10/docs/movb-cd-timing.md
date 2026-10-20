# Cache-disabled byte stores

The native CD byte-store candidate uses the explicit MOVB rows of TI
SPVU001A (1988), Table 13-2 (printed 13-6) and Table 13-4 (13-7).
Absolute register-to-memory bytes take CD7 when the byte fits one word,
and CD13 when it straddles two words. Plain indirect-to-indirect bytes
whose source and destination each fit one word use index 2, CD7.
Other forms retain their existing contracts.

These entries take precedence over applying the general field-move equation
and §5.4.7's three-state instruction-fetch increment to every byte operand.
The earlier generic policies gave CD15/19 for absolute bytes and CD9 for
plain B/B copies. The printed byte counts remain unchanged. The independent
Python oracle selects them without inspecting RTL or measured latency;
source alternatives for other forms remain in their fixture records.

Section 6.2 permits one queued field write. Section 13.1.1 describes hidden
writes that can overlap subsequent CPU execution, with unfinished work
charged to subsequent instructions using the local bus. Section 11.3 requires
each physical read/modify/write pair to remain indivisible except for HOLD.
Section 5.4.6 requires CD to fetch each requested instruction word without a
four-word subsegment fill.

The project observation policy reserves the next unrelated opcode before
the final whole RMW pair. A straddled absolute byte completes its first whole
pair before that opcode. This is an explicit implementation policy, not an
assertion that TI specifies these exact internal arbitration phases. The
checker requires every operand/source read, opcode, destination read and
write with the correct data, IAQ and order, complete pairs, no duplicate or
missing transfers, physical cycle lengths, target dispatch bounds and the
machine-state grid. It also bounds the final pair's remaining work by H3
plus its two inserted waits. A total duration alone cannot satisfy it.

The nominal instruction interval includes waits on three blocking words for
an absolute single-word byte, five for an absolute straddled byte and two for
a B/B copy. Waits on the final queued pair extend its drain. The early CEN
pause contract retains its explicit pause and bus-grid alignment. Separate
response-pause tests exercise CPU pauses overlapping an accepted transfer;
they do not assign TI instruction timings to that wrapper behavior.

Nominal CD fixtures use `drain_instructions=-2`: freeze CPU execution at the
following decode and drain all accepted physical work. This is the existing
contract in both the Verilator bench and FPGA runner. Immediate result
snapshot/reset (`-1`) cannot establish posted-write correctness.

A CD byte store modifying the following opcode is a dependency. Its write
must complete before that opcode is fetched; it is outside the nominal
unrelated-opcode timing rule. The separate permanent
[dependency suite](../ver/store_dependency/README.md) checks this ordering,
first-pass initialization, preserved memory, architectural state and opcode
contents. Cached self-modifying code remains outside that suite (§5.4.4).

The instruction-word dependency checker uses the same independent bus oracle
on both backends. It checks the complete transaction inventory, operand and
source order, indivisible RMW pairs, word-write order, physical cycle lengths,
machine-state allocation grid, target readiness and modifying-write-before-
opcode order. It does not impose the unrelated-opcode arbitration phases on
a code-write dependency, or assign a total duration to that separate family.

## Following loads and HOLD

The permanent `ver/store_dependency/check_byte_events.py` runs 16 first-pass
following-load programs in five profiles, and four HOLD programs at five
request phases each with zero/one wait state. Absolute stores and plain copies
cover destination bit offsets 0/8/9/15. Dependent byte loads run immediately
or after three CD NOPs. The same existing bit insertion/extraction oracle
checks every initialized register, full status, sparse memory and bus payload;
the following load additionally checks sign extension and N/Z/V with the
remaining status bits preserved. The physical inventory includes every
operand, source, RMW, dependent read and instruction fetch.
Primary decode cannot precede its opcode response. The dependent data reads
must follow the load opcode and precede the next opcode; the following
snapshot cannot precede completion of physical work.

The independent following-load count uses Table 13-1 (printed 13-5),
Table 13-2 (13-6), Table 13-4 (13-7), and §13.1.1 (13-2/3). Let `W` be
inserted wait states per physical cycle, `K` the intervening NOP count, and
`D` the dependent load's one or two data words. Its intrinsic CD count is
`L=6` for one word or `L=8` for two. The preceding primary interval `S` is
`7+3W` for an absolute B byte, `13+5W` for an absolute F byte, `7+2W` for
a B/B copy, or `13+6W` for the B/F copy control. A CD NOP takes `4+W`.

The existing native observation policy leaves `H=3+2W` of one whole queued
RMW after primary decode; the B/F copy control is already drained (`H=0`).
An immediate dependent load requests the local bus at state zero and consumes
all `H`. With `K>0`, the first NOP requests its next opcode at state one,
overlapping one state and consuming `max(0,H-1)`. This internal placement is
the explicit project policy above, rather than an additional TI waveform
claim. The checked total, relative to the primary store's start, is:

```
8 * (S + K*(4+W) + L + (D+1)*W + residual)
  + pause_clocks + (-pause_clocks)%8
residual = H if K==0 else max(0,H-1)
```

The primary nominal duration is checked separately. Correct final state with
an incorrect primary or following count fails. These equations describe the
early CEN pause at relative zero; arbitrary late response pauses retain their
separate diagnostic scope.

HOLD requests occur at relative clocks 0/8/24/40/52. The deterministic
FPGA/reference event table releases after three acknowledged HOLD clocks.
The oracle checks a single completed grant/release, no transfer launch or
active transfer across grant, exact cycle durations, transaction inventory
and write order. If HOLD separates an RMW read from its write, §11.3 (11-4)
requires the entire pair to restart: the write must use a fresh read after
release. Only that justified extra read is permitted. A missing restart fails
even if the final memory value happens to be correct. The four HOLD programs
have no total HOLD-adjusted instruction-duration assertion; grant overlap
with CPU work and hidden writes requires a separate timing derivation. This
does not relax nominal or published duration tests.

Run the pure oracle checks with:

```sh
python3 modules/jttms10/ver/timing/test_byte_store_oracle.py
python3 modules/jttms10/ver/timing/test_store_dependency_oracle.py
python3 modules/jttms10/ver/timing/test_byte_store_event_oracle.py
python3 modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/timing/test_published_targets.py
```

Use `timing/run.py --published-targets --simulator verilator` for the directed
RTL target inventory. Add `--wait-states 1 --pause-clocks 7` or
`--wait-states 3` for deterministic stall profiles. The normal module runner
includes the pure checks and the broader independent timing inventory.
It also runs the short event suite and real lost-HOLD-restart and delayed-
dependent-load RTL mutations:

```sh
python3 modules/jttms10/ver/store_dependency/check_byte_events.py --report events.json --traces event-traces
python3 modules/jttms10/ver/store_dependency/check_byte_event_mutations.py --report mutations.json
```

This candidate remains under development. Local directed results do not
establish current-image FPGA agreement, complete HOLD/IRQ behavior, other
following-instruction timings, full ISA compliance, CPU area, board STA or
NARC gameplay acceptance. A new source-bound build and physical validation
are required before claiming a qualified implementation.
