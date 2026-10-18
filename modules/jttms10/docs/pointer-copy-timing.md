# Pointer memory-copy timing (#144, in progress)

MOVE `*Rs+,*Rd+` and `-*Rs,-*Rd` share the plain-copy field/DSP path.
Their entries are TI SPVU001A printed pp.12-141/142 and 12-145/146;
Tables13-3/4, pp.13-6/7, supply the thirteen alignment indices. These two
forms add 8,936 permanent programs, bringing the inventory to 100/133 forms.
The six extended copy forms remain unvalidated, along with the other
remaining instruction/condition/bus/interrupt/hardware requirements.

The independent oracle uses the same field classifications as plain copies.
Pointer copies add one visible CPU state. Postincrement overlaps one more
hidden state: its first destination transfer starts at CPU-2; predecrement
starts its first source read after one intrinsic state, then begins the
destination at CPU-1. Postincrement therefore has the plain-copy CD count;
predecrement adds one. The aligned 16-bit cases are respectively
`4,7` and `4+(1),8`, as the entries and summary agree.

Three printed alternatives are retained under the owner's instruction to
implement the simpler interpretation when reliable clarification is absent:

| Condition | Printed CPU/CD | Selected CPU/CD |
| --- | --- | --- |
| Postincrement index12 | 6/17 | 8/17 |
| Predecrement index12 | 6/18 | 8/18 |
| Predecrement index8 | 6/15 | 6/16 |

The index12 source spans three physical reads. Its printed CD/hidden counts
also imply the selected CPU budget. Predecrement index8's printed CD15
conflicts with its CPU6/H7 and the three-state following-fetch cost. The
project selects the shared read/hidden-write equation; this is not an
official TI erratum. Exact signatures in `source_policy.py` record 642
additional project-choice probe instances. The normal full inventory has
4,262 choices and 448 unresolved MOVB instances, including 45 agreed
published-target gaps. The strict source-only audit retains all 4,710
discrepancies. Choices and probe presence do not establish full compliance.

Both pointers update through the existing shared ALU. Postincrement reads
the original source, increments Rs, writes through the then-current Rd and
increments Rd. For aliases this writes to the once-incremented address and
leaves a twice-incremented pointer, as p.12-141 explicitly describes.
Predecrement updates Rs and captures its EA, then decrements Rd while
retaining that source EA until the read completes. Aliases decrement twice;
the earlier source capture agrees with the prior architectural implementation.
The p.12-145 pseudocode is not explicit about the alias read address, so
that ordering remains an architectural interpretation; it is not a new
timing golden from the old RTL. The separate source/destination example
results agree with the primary guide.

The source field's span comes from the captured EA. Reading the already
updated Rs can otherwise lose the two additional G-to-G CPU states.
The full source is captured before any destination write, including
overlapping fields. Flags are preserved; FE does not add a copy state.
Postincrement's final destination update shares the write microinstruction.
The word wrapper retains copy slot eligibility across the required low
request clock only after accepting the source read. A one-bit transfer tag
is cleared on each opcode response and set on the actual copy-read
acceptance. It prevents a short CEN pause during predecrement address
preparation from inheriting bus credit. Without it the one-clock pause
can make the read and retirement one state early. A permanent mutation
removes that qualification and must fail with correct state/memory.
No arithmetic unit, storage bank or DSP is added.

Coverage includes all widths1..32, both fields/FE/cache/banks, all thirteen
indices, A/B/shared-SP aliases, overlap and wrap, every initial flag pattern,
sixteen pause probes, 200 real following loads and 104 literal TI programs.
The memory model walks bits independently of the DSP alignment and computes
warm-up and measured images separately. Hand-transcribed postincrement
After-pointer columns anchor the generic pointer model. Following loads
retain the written address in A1 while the copy updates A0; their exact
intervals include source waits and any residual posted-write work.

On unchanged `b4dfd3a8d`, all 8,936 programs fail timing/bus checks with zero
register/ST, following-state or memory failures. The committed
[historical baseline](../ver/timing/baseline-pointer-copy-b4dfd3a8.json)
contains 154 representatives and 22 verified old HDL/YAML hashes. It is
historical evidence, never an oracle or expected-failure list.

The expanded normal runner contains three 60,982-case matrices, two DIV
pauses and six 94-case phase unions: 183,512 exact timing programs. It
contains 90 checker/model tests, 44 mutation positive controls and 52
rejection checks (49 timing/stimulus and three separate event contracts).
New RTL mutations reject stale initial-read bus credit, shorten the postincrement CPU work, delay predecrement's
source issue or calculate source span from the updated pointer. Each must
fail timing with correct registers/ST and drained memory. The normal
runner and CI retain the independent architecture and event suites. The
CI job limit is 120 minutes because the complete matrices and mutation
builds outgrew the former 15-minute limit. Remote CI has not run.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --case copy_move_post_ --case copy_move_pre_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/test_checker.py
JTTMS10_TIMING_SIMULATOR=verilator bash modules/jttms10/ver/run.sh
```

Development validation remains in progress. On the initial pointer source,
all 8,936 W=1/CEN=7 probes,
180 architectural programs, 90 models, strict lint and the initial three
mutation controls/rejections passed before the bus-credit correction.
Corrected-source validation is in progress; its short-pause positive
control and dedicated mutation are part of the permanent runner. The initial representative 624-program Icarus/
Verilator comparison covers all aliases, literal vectors, following loads,
phase probes and index12 boundaries; it is not all 8,936 cases. Complete
normal/clean-checkout and current map results will be reported separately.
Final fitted area ≤3,500 ALMs, positive STA and NARC simulation/MiSTer
validation remain required. Cold-copy fills, broader dependencies, CPU
HOLD/IRQ/resumption and other outstanding-response CEN cases remain open.
