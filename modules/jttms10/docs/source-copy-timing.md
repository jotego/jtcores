# Extended-source copy timing (#144, in progress)

MOVE `*Rs(offset),*Rd+` and `@SAddress,*Rd+` reuse the existing copy engine.
TI SPVU001A printed pp.12-149/150 and 12-155/156 describe their semantics;
Tables13-3/4, pp.13-6/7, supply alignment classes and timing alternatives.
These two forms add 8,812 permanent programs. The complete probe inventory
is 102/133 forms, leaving 31 forms unvalidated. The two remaining field-copy
and two byte-copy forms with two explicit addresses retain their old timing.

The independent equation adds two intrinsic address states to a plain
copy, retains its hidden-write count H, and adds three CD states per
instruction word. Thus CPU=plain CPU+2 and CD=CPU+H+3*(1+N), where N is
one offset word or two absolute-address words. Aligned 16-bit copies are
`5+(1),12` and `5+(1),15`; aligned 32-bit copies are `7+(3),16` and
`7+(3),19`. Both instruction entries support those typical counts.

Table13-4 disagrees in several columns. For example, its aligned 32-bit
CD counts are 13/16 instead of the entries' 16/19. Other discrepancies
affect indices7/8/9; index12 prints CPU7 where its three source reads and
CD/hidden counts imply CPU9. The fixtures retain every numeric alternative
and both typical entry values where applicable. Following the owner's
direction, the shared address/read/hidden-write equation is the explicit
project choice. No official TI erratum is claimed. Exact signatures add
1,882 project-choice instances, for 6,144 in the full inventory. The same
448 MOVB instances remain unresolved, including 45 agreed published-target
gaps. The strict source-only audit retains all 6,592 discrepancies.

The shared ALU adds the signed 16-bit offset to Rs; absolute words combine
through the existing operand capture. No extra address register, arithmetic
unit or DSP is added. The source request waits for EA and two intrinsic
states. After each external operand response, the existing counter retains
the remaining address work. Register reads, source field capture and the
final destination increment/write use the shared datapath. A source/destination
alias uses the old register plus the offset for its read, then increments
the destination once. Absolute forms encode no source register; unused
registers remain checked and unchanged. Full ST is preserved and FE adds
no copy state.

With CD, extension reads begin at state1 and then every `4+W` states. The
source begins at state `2+N*(3+W)`, where W is the per-transfer wait count.
Destination writes begin at CPU-1, plus the prefix penalty and source-read
waits. Cold operand misses add four ordered IAQ-high fill reads, the
nine-state miss penalty and all four waits. The first/second missing word
and exact following instruction address remain asserted. Cached physical
data reads and all writes retain IAQ low. The oracle checks logical and raw
transfer starts, durations, payloads, order and the final architectural
state; padding retirement cannot conceal an incorrect operand/data cycle.

Coverage includes widths1..32, both fields/FE/cache/banks, all thirteen
alignment indices, signed displacement endpoints, A/B/shared-SP aliases,
overlap and address wrap, all initial flags, 24 cold-operand cases, 16
additional warm phase probes, 200 real following loads and 52 numeric
absolute-copy memory examples. The independent bit model computes both
warm-up and measured images. Cold cases instead use the initial image and
freeze the CPU after the measured result while accepted writes drain.

The p.12-156 example has conflicting labels: Before A0/A1 and After A1
columns disagree with its `@source,*A1+` syntax, and output address headers
name 15500h/15510h/15520h while the destination block starts at15530h.
The fixtures use the explicit instruction semantics, the destination
addresses implied by the initial memory block/left pointer column, and
the thirteen printed numeric output triples. They do not validate the
printed pointer columns or inconsistent address headers. Their source
notes and citations preserve that limitation. Offset examples are covered
by the mathematical model, not claimed as additional literal vectors.

On unchanged public `0ce81d6e1`, all 8,812 programs fail timing/bus checks
with zero register/ST, following-state or memory failures. The captured
tree `1b18d5c31` has exactly the same complete Git tree as that public
commit; all 22 historical HDL/YAML hashes verify against both. The committed
[historical baseline](../ver/timing/baseline-sourceext-copy-0ce81d6e.json)
contains 159 representatives. It is evidence, never an oracle or an
expected-failure list.

The normal runner contains three 69,794-case matrices, two DIV pauses and
six 134-case phase unions: 210,188 exact timing programs. It contains
96 checker/model tests, 47 mutation controls and 55 rejection checks
(52 timing/stimulus and three separate event contracts). New RTL mutations
shorten address work, issue the last absolute operand early or omit the
new forms' word-slot eligibility. Each must fail timing with correct
registers/ST and drained memory. Mutation checks now precede the larger
matrices, so a changed injection site fails before those expensive runs.

All 8,812 W=1/CEN=7 probes, 180 architectural programs, 96 model tests,
strict lint and the three new mutation controls/rejections pass. All six
short Icarus pause profiles pass 41 cases each, including the earlier
cold-store control. All 516 representative W=1/CEN=6 case objects match
Icarus and Verilator exactly, including their source/ROM hashes. This is
a representative comparison, not all 8,812 cases. Full normal-runner,
clean-checkout and current map validation remain in progress.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --case copy_move_offset_post_ --case copy_move_absolute_post_ \
    --wait-states 1 --pause-clocks 7
JTTMS10_TIMING_SIMULATOR=verilator bash modules/jttms10/ver/run.sh
```

Broader cache/posted-write/peripheral dependencies, CPU HOLD/IRQ/resumption,
all remaining ISA conditions and the known MOVB targets remain required.
Final fitted area ≤3,500 ALMs, positive STA, NARC simulation and MiSTer
gameplay are separate open gates. Probes and project source choices do
not establish full timing compliance.
