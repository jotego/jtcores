# Cache-disabled byte-store instruction dependencies

Run `python3 modules/jttms10/ver/store_dependency/check.py` from the checkout.
The normal `modules/jttms10/ver/run.sh` also runs this short Verilator check.
Use `--report result.json --traces traces/` to retain observations, and
`--rtl-dir /path/to/hdl` to test a candidate CPU independently of its oracle.

The 16 independent programs use absolute and indirect-to-indirect MOVB,
offsets 0/8/9/15, and destinations in the following or preceding instruction
word. Five wait/CEN profiles give 80 executions. Every case runs on its first
pass with CD set, drains accepted physical work without executing a CPU tail,
and checks all initialized registers, full ST, sparse memory and next opcode.
The bitwise Python insertion oracle preserves bits outside the byte.

The checker requires exactly the expected operand, source, RMW and instruction
transactions; read data, write payloads and IAQ; physical cycle durations and
target dispatch bounds; contiguous read/write pairs; word insertion order;
and the modifying write before a dependent opcode fetch. A final correct memory
image cannot hide an instruction fetched before its modifying write. Duplicate
opcode reads fail, even if they return the same value.

TI SPVU001A §§5.4.6 (printed 5-24), 6.2 (6-4), 11.3 (11-4) and the MOVB
entries (12-117/119) supply these architectural/bus rules. This test checks
cache-disabled operation. It makes no promise about cached self-modifying code,
which §5.4.4 warns can be unpredictable. It does not assign a new TI duration
to the dependency cases: published nominal duration targets remain mandatory
in the separate timing suite. The FPGA transport is not part of the oracle.
The protocol-v5 host adapter prepares this family explicitly:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare --store-dependency --protocol-version 5 --wait-states N --pause-clocks P --output manifest.json
```

It keeps `dependency_conditions` in each fixture, checks both logical BUS and
physical TARGET traces, and does not apply a total instruction-duration target
to this family. Published duration fixtures remain strict. The pause profiles
use `pause_after_clocks=0`, matching the timing bench's default `PAUSE_AFTER=0`;
the target continues independently while CPU CEN is low.

The timing bench accepts a retirement pulse from the last enabled edge at the
first paused edge, then clears that allowance. PC, ST, GPR and working-state
hold assertions remain active, and a new pulse during a pause still fails.

## Native CD MOVB image qualification

Source `54ab1116` / RBF `8b3d79b7` now passes all 16 cases each
BASE/W1/W3/W1P1/W1P7, with 80 exact Verilator comparisons and every raw
verdict independently replayed. The same image also passes 80 following-load,
40 HOLD and 492 published-target observations. The 27 preceding nominal CD
failures per profile are resolved under the unchanged published counts.
See [current image and source-bound evidence](../fpga/README.md#native-cd-movb-source-qualified-image).
The original first 16 BASE observations have no recorded outer exit/time
after a wrapper error; they remain preserved separately. A fresh 16-case
confirmation supplies the recorded BASE result in these 80 qualified checks.
This does not assign total duration to instruction-word dependencies or
qualify broader HOLD/IRQ behavior. Full #144 acceptance remains open.

## Preceding image qualification

Host source `c8e4dbc6b0269453f0b23115966481a381927674` and hardware source
`744acd3e9cac22127a9cb2673a494f0c82d4f53b` qualify all 16 cases each BASE,
W1, W3, W1/P1 and W1/P7: 80 physical executions and 80 profile-specific
Verilator comparisons. The unchanged image is RBF `5d071fc8`, overlay
`jtcores-144-arithmetic-5d071fc8`; the complete image and receipt identities
are in the [FPGA runner documentation](../fpga/README.md). Every original raw
verdict independently replays. These results establish the tested instruction
word initialization, write visibility, RMW and observation paths; this family
still assigns no TI total instruction-duration target.

BASE used parent host `a57918c1`. Its checker verified raw result word 5 but
omitted `observed_next_opcodes` from the report, causing 16 reference-comparer
errors. The original capture/report and errors remain intact. The committed
`c8e4dbc6` fix exposes the actual raw opcode, with rejection tests for wrong
values. Offline replay of that same capture differs only by the added field
and passes all 16 normal comparisons; BASE was not rerun. The other four
profiles used `c8e4dbc6` directly and have exact saved-report/raw replay and
normal reference comparisons.

Full host walls in BASE/W1/W3/W1P1/W1P7 order were
3.164707733/2.809657260/2.793721601/2.762628856/2.993547024 seconds. No FPGA
compile or programming was needed. Final health confirms the same boot, image,
SYSID, enabled bridges, taint zero, seven clients unbound and no runner process.
Evidence is under `/nobackup/tasks/jtcores-144/artifacts/movb-cd-native-1/`:
`fpga-host-adaptation-1/root-physical-complete-review.json` binds all five raw
reviews, references, timings and final health. These are development timings,
not a matched simulation speedup benchmark.

This source `744acd3e` checkpoint predates the native CD MOVB image above. Its 27
nominal CD timing failures remain archived as the earlier failing baseline.

## Native byte-store following loads and HOLD

`check_byte_events.py` adds permanent, first-pass data dependencies alongside
the instruction-word tests above. It runs 80 following-load executions across
BASE/W1/W3/W1P1/W1P7 and 40 HOLD executions across W0/W1 and request phases
0/8/24/40/52. `--kind following` or `--kind hold` selects either subset.
Use `--report result.json --traces traces/` to retain the complete observations.

The following cases keep both the primary nominal count and a separately
derived dependent-load count. They check all initialized registers, full ST,
sign extension, preserved memory and complete physical transaction ordering.
HOLD cases check grant ownership and the fresh RMW read required after an
interruption; total HOLD-adjusted instruction duration remains unqualified.
See the [CD byte-store timing contract](../../docs/movb-cd-timing.md) for
citations, exact equations and the explicit hidden-write observation policy.
Both families reuse the existing Python insertion/extraction expectations.

The normal runner includes these checks and `check_byte_event_mutations.py`.
The latter runs positive controls and actual lost-HOLD-restart and delayed-
byte-load RTL mutations in temporary copies. It requires rejection with
architectural state and memory still correct; compile errors or missing
results cannot count as successful detection. These new native event checks
have local Verilator evidence only until a new image is built and validated.
