# Data-load timing (#144)

The independent oracle uses TI's June 1988 SPVU001A, Table 13-1 on printed
p.13-5 and the instruction entries below in the
[primary guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
These probes cover all eight memory-to-register MOVE/MOVB addressing forms.
Stores and memory-to-memory forms retain separate timing requirements.

Let `W = ceil(((address & 15) + field_size)/16)` be the physical words read.
The published counts are:

| Load | Cache hit | Cache disabled |
|---|---:|---:|
| MOVE, zero extension | `1+2*W` | `4+2*W` |
| MOVE, sign extension with FS < 32 | `2+2*W` | `5+2*W` |
| MOVE, FS=32, either FE | `1+2*W` | `4+2*W` |
| MOVB, always sign extended, FS=8 | `1+2*W` | `4+2*W` |

The table above describes plain indirect loads. For the other modes, use
`CPU + 2*W + sign_extra + 3*I*CD`, in machine states, with `CD` zero or one:

| Addressing form | CPU | Instruction words I | TI printed entry pages |
|---|---:|---:|---|
| MOVE indirect | 1 | 1 | 12-135/136 |
| MOVE postincrement | 1 | 1 | 12-139/140 |
| MOVE predecrement | 2 | 1 | 12-143/144 |
| MOVE offset | 3 | 2 | 12-147/148 |
| MOVE absolute | 3 | 3 | 12-153/154; discrepancy below |
| MOVB indirect | 1 | 1 | 12-118 |
| MOVB offset | 3 | 2 | 12-120 |
| MOVB absolute | 3 | 3 | 12-123 |

`sign_extra` is one only for MOVE with FE=1 and FS<32. The per-instruction-word
CD increment follows §5.4.7; Table 13-1 gives the mode-specific totals.
The scanned absolute MOVE entry p.12-153 conflicts with that summary: its
aligned 16-bit hit/CD pair is **5/15**, and its aligned 32-bit pair **7/13**.
Table 13-1 p.13-5 gives **5/14** and **7/16**, consistent with three instruction
words and the nine-state CD increment. The oracle follows the summary and
§5.4.7. Treating the entry as a typographical error is an explicit inference,
not an official TI erratum. MOVB absolute's 5/14 pair is consistent. Reports
retain this source conflict in each absolute MOVE fixture.

Table 13-1 note 1 adds a state for MOVE sign extension. The 32-bit example
on p.12-136 marks FE irrelevant; no extension is performed at full width.
MOVB's mandatory sign extension is already included in its own 3/6-state
entry on p.12-118 and is not charged again. The fixtures independently
check these distinctions, including FS=32 with both FE values.

Data reads bypass the instruction cache and have IAQ low (§11.5 p.11-24).
They read aligned ascending words beginning at the field's word base.
Each physical transfer adds its own requested external waits. The warm
instruction-cache case still reads all data externally; CD additionally
reads the following opcode with IAQ high. No hidden write states occur in
these loads (p.13-5). The oracle checks physical word count, address, data,
IAQ, ordering, logical two-state duration and actual raw target readiness.

The logical pipeline allocates plain/postincrement data cycles at the start
of the instruction, predecrement after one state, and offset/absolute after
two intrinsic states, followed by the remaining CPU state(s). External
extension fetches add their processing/wait time before data. Registered address,
field, cache and arbiter handoffs occupy the first state's row phase; the
raw response must still meet the Q1 sample. `word_early` qualifies that slot
for these eight load forms. A reset-relative phase counter prevents
an early CEN pause from backdating the data cycle before its resumed state
boundary. The normal runner checks pauses 1..6 separately, in addition to
the full seven-clock profile. The phase profiles include all six new forms
and a cold second-address-word fill, as well as the original indirect load.
These are exposed logical-cycle/transport
contracts; original LAD/control pins and internal silicon microinstructions
are not generated.

The register RAM primes the next source from the fetched opcode before
IR commits. The indirect-load request can then start in its first state.
The field adapter uses one shared 48×17 DSP product with a one-hot factor
for write alignment and final read alignment. It combines the incoming last
word with the buffered words before capturing the aligned result. A combined
read/extend microinstruction and the following ALU writeback finish within
the published CPU work budget. The scheduler preserves that work after the
last read response, so external waits cannot consume the extra sign-extension
state. The existing RMW masks, locks and HOLD reread rules remain checked.

`ver/timing/load_cases.py` adds **4,424 fixtures**: all 32 widths and 16
bit offsets, both fields/FE and cache modes, register aliases, zero/dense/
alternating/mixed data, initial carry preservation, seventeen TI example vectors
(including both FE settings for the printed full-width case) with both carry/cache settings, and full 32-bit transport-address
cases. The mathematical extractor reads individual input bits rather than
copying the DSP alignment algorithm. Each probe compares full ST and A0..A3.
Sparse initial memory words are simulator stimulus; expected results and
counts stay exclusively in Python and never enter the simulator manifest.

The historical [baseline](../ver/timing/baseline-load-22e6010.json) records
all 4,352 original matrix cases on unchanged `22e601063`: every timing check
failed while architectural values passed. A zero-extended aligned 16-bit
load took 43/72 INCLK rather than 24/48. Sixteen representative byte/field,
word-span, FE and cache combinations retain verified RTL/YAML hashes. Later
literal/high-address fixtures are not included in that original capture.
The baseline is evidence, never an oracle or allowlist.

Five new actual RTL mutations must fail with correct final registers/ST:
late first-cycle allocation, consuming sign work during a wait, charging FE
at FS=32, absorbing a sub-state CEN pause, and caching data reads. Checker
unit tests independently anchor the TI bit/flag examples and state counts,
per-word wait addition, uncached data traffic and IAQ/order.

## Additional modes, physical register identities and cold extensions

`ver/timing/load_mode_cases.py` adds **3,200 fixtures**, including the six
remaining memory-to-register forms, plus plain-load physical-register and
MOVB ignored-field checks. Post/preincrement cover every FS=1..32; the other
modes use selected width boundaries. Both fields/FE/cache modes, offsets
0/1/7/15, signed displacement endpoints, A/B destinations, shared SP, aliases
and pointer/address wrap are exercised. MOVB forces eight-bit sign extension
even when the ignored field definition requests another width or FE=0.
Sparse word addresses wrap at 32 bits. Thirty cold-extension cases check
first/second missing address words, four ordered IAQ-high fill reads and the
nine-state miss penalty; data reads still bypass the cache with IAQ low.
Every initialized A0..A3, B0..B3, SP and the full ST are compared. Extra
register initialization uses real instructions, and the manifest contains
stimulus plus observation selection, never golden results/counts.

Predecrement alias writeback is explicit on p.12-143: loaded data wins.
The postincrement entry p.12-139 does not explicitly resolve the alias.
The fixtures use the same data-wins interpretation, corroborated by the
read/increment/destination-write order in the pinned primary
[MAME MOVE_NI_R implementation](https://github.com/mamedev/mame/blob/e5a5a102889d6c62f12e39a4db3e950e4f5d6822/src/devices/cpu/tms34010/34010ops.hxx#L1166).
This is a documented interpretation; MAME supplies no timing goldens.

The [mode baseline](../ver/timing/baseline-loadmodes-06843c7.json) captures
unchanged `06843c78c`: 2,800 of the first 3,164 fixtures fail timing, with
zero architectural failures. All six newly covered forms fail; the 364
additional plain-load cases pass. Sixteen form/cache representatives and
verified source hashes are retained as historical evidence. Cold-extension
and directed phase fixtures were added after that capture.

The shared ALU computes pointer updates and effective addresses without
changing flags. Early postincrement reads retain the original address while
the source register changes; aliases finish with loaded data. Offset and
absolute extensions combine bus/operand capture, with explicit first/second
word request guards. These guards preserve the intrinsic state grid around
cold fills and short CEN pauses. Four more RTL timing mutations independently
reject incorrect predecrement/offset leads and premature first/second address
words, while keeping architectural results correct.

## Response captured while the CPU is paused

`ver/load_pause/check.py`, run by the standard runner, pauses CEN for exactly
32 input clocks after a postincrement data request. The bus completes during
the pause. Three A/B/shared-SP cases assert CPU/sequencer/work-state hold,
response capture during the pause, one ordered data read, independent logical
and raw bus durations, correct registers/ST and bounded completion after
resume. A real regression lost that completed response when the following
non-bus pointer helper advanced; it issued a duplicate read despite correct
final registers/ST. Retaining the response until its bus-consuming
microinstruction fixes it. A fourth run restores the bug and must reject
the duplicate read with correct architecture.

These are separate **functional response-retention event tests**, not exact
TI instruction-count proofs for an overlapping CEN pause: CEN is a wrapper
extension, and the bus continues while CPU work stops. Exact base counts
remain mandatory in the normal timing matrices. No base assertion is relaxed
to accommodate the event bench's conservative completion bound.

```sh
python3 modules/jttms10/ver/timing/run.py --case load_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case load_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case load_move_f0_w32_o15_s1_off --wait-states 1 --pause-clocks 1
python3 modules/jttms10/ver/timing/run.py --case loadmode --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case loadmode --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py
```

Full CPU HOLD/interrupt/other response-during-CEN cases,
writes/hidden writes, graphics, contention and cache
replacement/prefetch still require their own timing/event audits. Final
fitted area/STA/NARC validation is also pending under #144. Passing these
loads does not establish complete memory or ISA timing compliance.
