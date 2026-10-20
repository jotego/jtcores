# FILL timing audit and failing CPU baseline

Primary authority: TI *TMS34010 User's Guide*, June 1988, SPVU001A,
printed pp.12-80..88 and13-10..17. The pinned reference documentation is
`modules/tms34010/third_party/TMS34010_Info` at
`0f5094bf8d177d753ea7e18012827d26a5013371`, file
`docs/ti-official/1988_TI_TMS34010_Users_Guide.pdf`, SHA-256
`e5f9f50c609ce44deb9dbe4ac79c591e03ff2d0ee2d71d571d0d7f150753ed64`.
The tables and Figure13-5 were inspected directly; OCR is not the authority
for alignment labels or inequalities.

This audit supplies requirements for the next implementation. The permanent
CPU suite now includes 120 failing baseline probes for FILL L and FILL XY:
1/2/4/8/16-bit pixels, one/two/three full words per row, one/two rows and both
cache modes. All use replace/PPOP0/PMASK0/T0/W0 and aligned, nonempty rows.
Architectural FILL tests and the scalar PIXT timing paths do not establish
these word-oriented transfer timings.

`ver/timing/fill_oracle.py` independently implements the positive,
already-clipped,constant-alignment table domain. It reads no RTL or measured
counts. `test_fill_oracle.py` checks all alignment/length columns, every PPOP
class, setup/CD costs, reused edge reads, maximum dimensions and the three
literal examples. The standard runner executes these model tests alongside
the existing checker tests. Run them alone with:

```sh
python3 -B modules/jttms10/ver/timing/test_fill_oracle.py
```

The oracle raises `UnresolvedFillTiming` for empty dimensions, varying row
alignment, hit/miss setup and the masked/transparency single-word D case.
The latter preserves both numeric alternatives on the exception object.
The model tests themselves establish no CPU timing compliance. The separate
`fill_cases.py` fixtures use the equations as CPU timing goldens and verify
all defined registers/full ST, destination words and untouched neighboring
words. B10..B14 are reserved scratch registers marked changed on pp.12-80/84;
no undefined final values are asserted. Final B2 is the linear address just
after the last pixel, including for XY (pp.12-81/85).

The bus checker asserts ordered full-word writes, data/address/IAQ, transfer
counts, logical/transport durations, nonoverlap and completion within the
instruction interval. Cache-disabled execution also checks the following
opcode fetch. No exact first-write, row-boundary or interrupt-checkpoint
position is claimed by these probes. Deterministic target waits add one
state per word transfer and uncached opcode fetch under the existing isolated
bus contract; the early CEN pause retains its bus-grid alignment cost.

On unchanged b6bb7e6ed HDL, all three 120-case Verilator profiles fail timing
with correct defined architecture and memory: baseline, W=1 and W=1/P=7.
The single-word/one-row PS16 FILL L hit expects nine TI states (72 INCLK)
but observes 132 INCLK. Smaller pixels also expose the current per-pixel
read/modify/write traffic instead of one full-word replacement. Reports have
58 source/seven generated hashes verified against the baseline inputs.
All 120 Icarus W=1/P=7 case objects match Verilator exactly after removing
only simulator-local case IDs, including the timing failures, state, memory
and bus traces. All 58 source/seven generated hashes match across simulators.
The preceding 138,370 fixture/program/golden contracts have identical SHA-256
before and after adding FILL. The existing 206 checker tests, eight FILL
oracle tests and four new fixture/checker tests pass separately.
These are intentional failing regressions, not a timing-compliant FILL path.
Fixture inventory becomes 126/133 forms and 138,490 cases; seven forms still
have no probes, and both newly probed FILL forms remain failing.

Run the fixture/checker tests and CPU baseline separately with:

```sh
python3 -B modules/jttms10/ver/timing/test_fill_cases.py
python3 modules/jttms10/ver/timing/run.py --case fill_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case fill_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case fill_ --simulator verilator --wait-states 1 --pause-clocks 7
```

The CPU commands currently return nonzero for the documented timing gaps.
The standard runner includes both the independent oracle tests and the FILL
fixture/checker tests. The separate frozen 124-form runner predates these
probes and must retain its original source/inventory labels.

## Total and setup

Section13.3 defines total machine states as setup plus transfer minus an
alignment/graphics adjustment. These are complete array-transfer counts;
they are not the scalar PIXT CPU/hidden-write split. Table13-5 adds three
states to setup for cache-disabled execution, once per instruction.

| Form | W=0 | Array fits | Start adjusted | Dimensions adjusted | Both adjusted |
|---|---:|---:|---:|---:|---:|
| FILL L | 4 | — | — | — | — |
| FILL XY | 6 | 9 | 16 | 12 | 20 |

Window hit and miss columns contain dashes, not zero-state results. Their
timing requires further source audit. FILL L ignores window controls.
Corner-direction controls add no setup cost; FILL proceeds in increasing X
and Y regardless of PBH/PBV (§13.3.2.4). No exact empty-array total is assigned
by this audit.

## Transfer and alignment

Let L be the positive number of rows after clipping and N the positive
number of physical 16-bit destination words touched by each row. For a
pixel-aligned linear row with starting lane `o`, width `DX`, and pixel size
`PS`, `N = ceil((o + DX*PS)/16)`. This is a bit-addressed span, not
`ceil(DX/PS)`. Aligned row boundaries can coexist with several pixels per
physical word.

Figure13-5 (p.13-12) distinguishes:

| Alignment | Leading edge | Trailing edge |
|---|---|---|
| A | Word boundary | Word boundary |
| B | Word boundary | Inside word |
| C | Inside word | Word boundary |
| D | Inside word | Inside word |

Table13-6 (p.13-11) gives the following transfer counts before adjustment:

| Row length | A | B | C | D |
|---|---|---|---|---|
| N=1 | `(1+G)L+2` | `(2+G)L+2` | `(2+G)L+1` | `(2+G)L+1` |
| N=2 | `(2+2G)L+2` | `(3+2G)L+2` | `(3+2G)L+2` | `(4+2G)L+1` |
| N>=3 | `(1+NG)L+2` | `(2+NG)L+5` | `(3+NG)L+2` | `(4+NG)L+1` |

The long-B tail is literally five states. The text on p.13-12 includes
N=3 in the long case. Neither value should be inferred from a smoother
equation or the current graphics microcode.

Table13-7 (p.13-13) gives G per destination word:

| Processing | No plane masking/transparency | With plane masking/transparency |
|---|---:|---:|
| Replace | 2 | 4 |
| Other Booleans or ADD | 4 | 6 |
| ADDS, SUB, MAX or MIN | 5 | 7 |
| SUBS | 6 | 8 |

Arithmetic PPOP is undefined for one- and two-bit pixels (p.12-81). The
memory controller handles insertion, masking and transparency; CPU pixel
processing contributes separately (§13.3.2.5). A future implementation must
check actual word transactions, edge preservation and processing results,
not merely delay retirement to match the table.

## Source qualifications still requiring resolution

Section13.3.2.6 says that, when masking or transparency is enabled, the
already-required edge reads remove two states per row for B/C and four
for D; A needs no adjustment. The rule does not qualify the short case.
For N=1,D, both partial edges share one physical word. Applying the printed
four-state subtraction literally makes masking/transparency *reduce* the
replace transfer from `4L+1` to `2L+1`, despite the text saying that the
existing RMW removes an additional read. For L=1 and FILL L these alternatives
are nine versus seven total states. The single-word adjustment needs a
traceable interpretation before exact goldens or a compliance claim are
assigned; this audit does not silently replace the printed rule.

Page12-81 describes the exceptional non-word-multiple pitch as a
single-pixel-width line but prints `DY=1`. Page13-12 instead describes an
array one pixel wide, with each row contained in one word. It says changing
alignment with a non-word-multiple DPTCH can be estimated using C on average
and D for worst case. Those estimates are not exact per-instruction goldens.
Initial exact probes must distinguish constant-alignment pitches from this
still-unresolved domain. Empty dimensions, clipped-away arrays, SRT, refresh,
peripheral contention and resumption timing also remain to audit.

## Literal examples and interrupt requirements

The example on pp.13-14..17 uses start-adjusted FILL XY, L=15,N=14,C:

| Example | G | Adjustment | Total states |
|---|---:|---:|---:|
| Replace, no mask/transparency | 2 | 0 | `16+(3+14*2)*15+2 = 483` |
| MAX, no mask/transparency | 5 | 0 | `16+(3+14*5)*15+2 = 1113` |
| XNOR, mask and transparency | 6 | 30 | `16+(3+14*6)*15+2-30 = 1293` |

Example13-3's setup enables masking and transparency although its copied
bullets say neither is enabled. Its G=6 and subtraction explicitly use the
enabled case; both printed descriptions must remain visible in the audit.

Section13.3.4 permits interrupts at destination-word and row boundaries,
with worst-case recognition latency of20 states plus the context switch.
PBX and the reserved context registers must retain a resumable word
boundary (pp.12-81,12-86). Matching only a completed array's total cannot
establish these requirements. Existing architectural interrupt tests must
remain active when the transfer engine changes.

## Word grouping checkpoint

The next implementation groups complete aligned replacement words. At the
FILL loop's address capture, the synchronous second read port supplies the
remaining pixel count from scratch register45. For PPOP0/PMASK0/T0, an aligned
address with enough remaining pixels selects a 16-bit transfer. XY uses this
path only with windowing disabled. COLOR1 supplies the complete word pattern;
the address advances16 bits and the remaining count decreases by the number
of pixels in that word. Partial leading/trailing fields and other processing
modes retain their existing pixel path.

The implementation uses the existing graphics ROM, field adapter, shared ALU
and scratch registers. Two graphics control values select eligibility and
pixel-count stride; the ROM remains4096x64. The mode clears on graphics entry
and RETI resumption and is recomputed from restored state, so nested graphics
do not inherit it. Reserved interrupt-context dimensions remain in pixels.

Both120-case base/stressed runs retain correct defined state and memory and
now pass every ordered bus/transport assertion. All120 still fail the
intrinsic duration target: this is word grouping, not compliant scheduling.
For PS1, one-word/one-row FILL L hit drops from1468 to132 INCLK; TI requires72.
Setup/conversion, word cadence, row overhead and cache-disabled scheduling
remain to be implemented without hiding bus/IRQ timing behind retirement
padding. Broader modes, SRT and exact IRQ-acceptance timing remain open.

Validation passes180 architecture programs, the unchanged160 array programs,
124 new bit-model FILL boundary programs, and strict lint. The new boundary
mode covers every pixel lane for all five sizes, short partial fields and
mixed leading/full/trailing words over two rows, in both address forms:

```sh
python3 modules/jttms10/ver/array/programs.py --fill-boundaries --out /tmp/fill-boundaries.yaml
python3 modules/jttms10/ver/run.py --vectors /tmp/fill-boundaries.yaml
```

The array interrupt bench additionally checks eight full-word writes across
two rows for each pixel size1/2/4/8/16, comparing uninterrupted, IRQ and NMI
runs, nested FILL, restored pointers/context, destination order/data and
neighboring memory. Its existing masked/Boolean, binary, window, no-stack NMI
and HLT variants still pass. On unchanged baseline HDL, its new PS1 contract
rejects the first one-bit write. This demonstrates detection of lost word
grouping, not an exact TI interrupt-latency proof. The standard runner now
includes the124 boundary programs and all five interrupt-bench pixel sizes.

Matched synthesis on committed837ac14d1 reports3903 estimated ALMs,5734
ALUTs,1723 registers,538624 RAM bits,five DSPs,zero MLAB and158 virtual pins.
All36 snapshot hashes,29 committed inputs,normalized QSF,SDC and49 warning
classifications verify against b6's matched configuration. Delta:+55 map
ALMs,+90 ALUTs,+one register,no DSP/RAM change. No fitter or board-STA result
is implied; the<=3500 fitted-ALM gate remains open. The preceding pixel/DRAV
timing sweep and Icarus FILL repeat are still running on immutable837 inputs.

## Posted word-loop checkpoint

A compact full-word loop now overlaps its remaining-pixel decrement and
next-address preparation with the physical write, using the same ALU and
register RAM. COLOR1 is loaded once per run of complete words. A short
remaining field returns to the existing edge path. Context is serialized
when an IRQ/NMI is pending, while the existing row path still handles row
changes. Ordinary consecutive words allocate two machine states each before
external waits; this does not establish complete-array timing.

The word wrapper now supplies `mem_busy` to the CPU while a field, posted
write or data-owner handoff remains pending. A graphics `sync_gbus` operation
waits for it before FILL retirement or a context checkpoint. Post acceptance
captures address/data; it is not physical completion. Direct scalar clients
with `TIMED_PROGRAM=0` retain their ordinary completion ACK contract and tie
this metadata input low. The existing direct CPU benches and scalar area
boundary were updated accordingly.

The120-case base and120-case W1/P7 profiles preserve all defined state,
memory and ordered bus/transport checks, but still fail overall timing.
Single-word FILL L cache hit is95 INCLK versus TI72; the three-word row issues
writes at offsets72/88/104. Setup, row handling, machine-state completion
alignment, cache-disabled timing and exact added-stall counts remain open.
No target is changed to match this intermediate schedule.

Strict lint,180 architecture programs,124 boundary programs and five-size
architectural IRQ/NMI resumption pass. The first prototype selected A0 instead
of COLOR1 through an unprimed synchronous read port; its failing captures
are excluded. The corrected conditional branch retains the COLOR1 read
selection through the handoff.

The corrected120-case Icarus W1/P7 observations match Verilator exactly,
removing only simulator-local case IDs. All58 source/seven generated hashes
match across the base, W1/P7, W3 and Icarus reports. The W3 profile also passes
all defined-state, memory and ordered bus checks with prolonged outstanding
writes; its overall timing remains failing. Existing160 array programs pass.


## Replacement-word row schedule

The word path preselects its row counter through the existing RF read port.
An eight-microinstruction row sequence decrements height, advances the row
start by B3, restores the pixel width and initializes the next row pointer.
These operations overlap the pending last-word transfer. A pending IRQ still
saves the existing PBX context and drains writes before its checkpoint;
completion retains the same drain fence. The scalar ALU and RF are reused.

The next row can start inside a physical word when pitch is not a multiple
of sixteen bits. The fast loop rechecks the pointer's word alignment before
issuing a full-word write, returning to the existing pixel path for edges.
`array/programs.py --fill-rows` adds56 independent three-row programs across
all five pixel sizes, one/two/three full words and mixed edges, changing
pixel lanes and overlapping rows. They check memory, neighboring words,
final B2 and preserved initialized registers. The normal runner includes
them alongside the124 existing boundary programs. Removing the alignment
guard fails a new PS1/pitch129 memory assertion; the passing control uses
identical fixtures. These functional cases do not establish exact timing
for the non-word-multiple-pitch domain excluded by the timing oracle.

The120-case base and120-case W1/P7 profiles retain correct defined state,
memory and ordered bus checks, with all overall TI duration checks failing.
For PS1 linear FILL, two rows of one word improve183 to119 INCLK (TI96),
and two rows of three words improve259 to191 (TI160). Setup, exact row
scheduling, machine-state completion alignment, added-stall compliance,
XY conversion and broader modes remain unfinished. No oracle is changed.


## Linear replacement timing checkpoint

The linear prologue overlaps the synchronous RF pointer and dimension
reads/writes in eight microinstructions, retaining zero-dimension exits.
The word-row schedule overlaps metadata preparation with the pending last
write, then drains that physical transfer before starting the next row's
processing. This prevents an external wait from disappearing inside the
row work. Two-word rows retain the additional processing state from
Table13-6 A/G2 before their first word. Completion drains writes and hands
off at the phase required by the existing four-clock cached fetch overlap.
These changes use the shared ALU, RF and field adapter; no new multiplier,
register bank or arithmetic unit is added.

The original120 fixtures are unchanged. Another140 linear fixtures extend
N to4/8 and row counts to3/4. All200 linear cases pass the base, W1/P7 and
W3 profiles, including defined GPRs/full ST, destination/neighbor words,
logical/raw transport and transaction ordering. The60 original XY cases
still fail overall timing. Inventory is126/133 forms and138,630 fixtures;
probe presence does not establish completion of either form's full audit.

The bus checker also constrains within-row writes to G=2 plus external
waits, and repeated identical rows to the Table13-6 linear row coefficient
plus their word waits. This is an explicit schedule constraint derived
from the table, not a printed TI first-write waveform. A checker model
rejects early next-row traffic even when the overall interval, data,
transaction order and bus durations remain correct. Exact first-write
placement and IRQ latency still need source-backed event audits.

Five actual timing mutations change the completion phase, omit the
two-word processing state or remove the row drain with/without waits.
Controls pass and all mutations fail with correct defined state/memory.
The wider row tests exposed both phase drift and hidden waits in earlier
prototypes; those captures are excluded from this checkpoint. Partial
words, other PPOP/masks/transparency, history/interference, window/SRT,
HOLD/IRQ timing, XY conversion and all final acceptance gates remain open.


Early CEN pauses retain the linear setup/transfer-prefix work in the existing
issue counter. The two-word path extends that budget by its extra state.
The first posted word waits for the retained work and a fresh physical
state boundary; later words retain their back-to-back slots. This prevents
a short pause from disappearing into setup's bus-alignment slack. A fifth
mutation removes this first-word guard and restores the absorbed-pause
failure. Its golden pause and alignment costs are unchanged.

## Opaque FILL after transparent PIXT

A transparent zero-source PIXT followed by a CONTROL change to T0 exposed
a functional history bug in the full-word path. That path deliberately
bypasses pixel processing, so its write-suppression decision could inherit
the preceding PIXT's transparency flag. B2 advanced correctly while every
destination write disappeared. Word replacement is eligible only with
PPOP0/PMASK0/T0; its writes now ignore the pixel transparency latch. Pixel
writes continue to use the latch. This adds no state or arithmetic resource.

Sixty permanent history fixtures execute real PIXT and CONTROL-write
instructions before register/status initialization and cache warm-up.
The zero-source transparent PIXT must preserve a separate sentinel word.
The following opaque FILL checks all destination/neighbor words, defined
GPRs/full ST and the existing timing/bus contracts. All five pixel sizes,
N=1/2/3, one/three rows and hit/CD are covered. These fixtures fail against
unchanged5edc71ed9 HDL: defined registers/ST and the transparent sentinel
remain correct, but all sixty cases omit the FILL writes. This is a
functional baseline rejection, not a timing-only mutation result.

The corrected source passes all260 linear cases in base, W1/P7 and W3;
the60 XY cases retain only their known overall-duration failure. All60
history case objects match Icarus W1/P7 after removing batch-local IDs.
W1/P1 passes60 histories, and two fresh processes match the stressed batch.
Each report records58 source/seven generated hashes. All preceding138,630
fixture/program contracts remain byte-identical; inventory is now138,690
fixtures across126/133 forms. Seven forms still lack probes. Other
transparency/mask/processing histories, XY timing, precise first-write/IRQ
events and all final issue acceptance remain open.


## Aligned opaque XY FILL conversion and timing

The scalar sequencer now converts the initial XY B2 through the existing
shared DSP/ALU and saves the linear address in scratch RF51. A fused graphics
prologue consumes it; architectural B2 changes at completion. Dispatch uses
the resolved instruction family because the exact 0FE0 opcode overrides the
decoder table family. Eligibility requires PPOP0/PMASK0/T0/W0; other modes
retain their existing conversion/window path. No arithmetic unit or register
bank is added. The existing first-word issue counter retains the six XY
setup states and two transfer-prefix states across CEN pauses. Subsequent
word and row cadence checks remain active.

There are 2,240 FILL fixtures: 260 linear and 1,980 XY, adding 1,920 fixtures
to the preceding inventory. They cover all five sizes, all 32 CONVDP shift
encodings and ignored upper bits, signed Y endpoints, nonnegative X,
OFFSET, overlapping pitches, N=1/2/3/4/8, multiple rows, hit/CD and transparent
PIXT history. Address arithmetic follows SPVU001A pp.4-12 and 6-15; broad
conversion probes independently anchor the destination at 0x6100. The oracle
initializes all canaries before applying the union of writes, including when
successive rows overlap. The preceding 138,690 fixture/program contracts are
unchanged (SHA-256 397d3a06b068d86d1574a36f0429f317d4047fb3210bc81e10a9e75f3cfe45b7).

All 2,240 cases pass Verilator in base, W1/P7, W3 and W1/P1 profiles.
Twenty selected P2..6 probes and two independent simulator processes pass.
A fresh resumed W1/P7 run passes all 2,240 in 29.914 seconds including build
and checking, with every complete case object identical to the saved stressed
run and all 58 source/seven generated hashes verified. Seven controls pass;
seven actual RTL timing mutants fail while retaining correct defined
architecture and memory, including disabled XY dispatch and shortened XY
setup. Fifteen independent oracle/fixture/checker model tests pass. The
cancelled Icarus run remains incomplete and was not resumed; no current-source
cross-simulator completion is claimed.

Run an exact mutation/control fixture without accidentally selecting its
conversion/history suffix variants with the permanent selector:

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
  --exact-case fill_xy_ps16_n1_rows1_hit --wait-states 1 --pause-clocks 7
```

Native XY IRQ/NMI continuation tests use nonzero Y and OFFSET at all five
pixel sizes, alongside the linear variants. These exercise the direct
architectural interface with TIMED_PROGRAM=0; they do not establish IRQ
acceptance timing through the real posted wrapper. The fixture scope remains
aligned full-word replacement. Partial edges, other processing/mask/window
rules, exact first-write/IRQ/HOLD timing and final physical/game acceptance
remain open. Inventory is 140,610 fixtures across 126/133 forms; seven forms
still have no timing probes.

## Partial-word edge timing baseline

`fill_partial_` adds 140 independent probes for one-row, replace-only FILL
L/XY with B/C/D alignment, one/two/three affected words, PS1/2/4/8 and
resident/disabled cache. PS8 cannot have a nonempty type-D span contained
inside one word, so that geometry is excluded. Every preceding 2,240 aligned
fixture and generated program remains unchanged, including order.

Counts come from the existing Table13-5/6/7 model with no plane mask,
transparency or clipping. Table13-6 gives linear single-row B/C/D counts
10/9/9 states for N1, 13/13/13 for N2, and 17/15/15 for N3; XY adds two
setup states and disabled cache adds three. The N3 B five-state tail is
preserved. Section13.3.2.3 requires one write or read-modify-write for the
single-word row; §13.3.2.4 requires increasing word order. The bus plan reads
each partial edge once, writes each affected word once, and transfers center
words as complete 16-bit words. There is no new exact first-write or edge
phase assumption. Existing aligned row/word cadence assertions remain active.

COLOR1 is a 16-bit pattern, as specified on p.12-80. The memory golden inserts
its bits at matching physical word lanes and preserves every bit outside the
rectangle. Initial affected words contain the inverse pattern, so overwriting
an untouched edge changes a checked bit. Both neighboring words, all defined
GPRs and full ST remain checked; reserved B10..B14 values remain unspecified.

Ten representative Verilator probes on unchanged CPU77 all fail duration;
eight also reject extra per-pixel BUS/TARGET transactions. All ten preserve
the checked architecture and memory. For example, linear PS4/N1/D expects
72 INCLK and observes 216, with two required transfers versus four observed.
On the unchanged source77/ce9d833b DataStorm image, the full 140-case subset
fails duration in each BASE/W1P7/W3 profile (420 failing executions), with
108 per profile also failing BUS/TARGET transaction counts. Both NOP controls
pass in every profile; all six batches per profile finish with raw transport
exit0 and no timeout/overflow. Every raw verdict field reproduces exactly.
The 30 representative observations, errors and complete relative bus traces
agree diagnostically with Verilator; standard positive equivalence correctly
refuses these failing inputs. All defined register/status/memory/canary checks
remain active and pass. Complete host walls are 3.787164771/3.926996138/
3.806566346 seconds; concurrent Quartus work prevents a controlled speedup
claim. No FPGA recompilation/programming was needed for these programs.
These are permanent failing regressions, not a partial-word compliance claim.

```sh
source setprj.sh
python3 -B modules/jttms10/ver/timing/test_fill_cases.py
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --case fill_partial_ --report /tmp/fill-partial.json
python3 modules/jttms10/ver/fpga/check_results.py prepare \
    --protocol-version 5 --case fill_partial_ --output /tmp/fill-partial-manifest.json
```

The timing command must return nonzero while these mismatches remain. The
standard runner already includes the fixture tests and all generated cases;
there is no failure allowlist or change to the independent timing equations.
Plane mask, transparency, Boolean/arithmetic processing, multiple partial rows,
window preclipping and partial-edge interrupt timing remain separate work.


## Native partial-word development path

The replacement path now groups each pixel-aligned PSIZE 1/2/4/8 edge into
one physical-word read/modify/write through the existing field adapter.
Whole words still use one write. The five-bit span records the smaller of
the remaining row and physical word; fixed PSIZE selectors convert that span
back to a pixel stride. COLOR1 remains a physical-word pattern, shifted for
the destination lane. This adds one span register and one long-B mode bit;
it adds no arithmetic unit, DSP, register bank or asynchronous RAM access.

The native loop primes the next pointer before entering the next word,
loads COLOR1 while capturing the edge, and overlaps the pointer/count work
with the posted transfer. A new partial row reloads its lane-shifted pattern;
a new full row reloads its word stride before the row emit. This preserves
changing-pitch and overlapping-row architectural behavior. The independent
oracle and fixture expectations are unchanged.

Initial B/C/D read reservations follow Table13-6; a C row spanning several
words keeps the full setup reservation. Long B rows drain the preceding
word before the additional tail processing interval. The field response
latch accounts for four clocks of that interval. A reserved bus operation
also waits for its own request before accepting completion, so completion of
the preceding posted word cannot silently discard the delayed tail write.
These are bus scheduling changes; retirement padding does not establish the
edge traffic or compensate for missing transactions.

Local development checks cover 26 focused timing programs in BASE, W1/P7
and W3: 20 partial-edge cases and six preceding aligned controls. Separate
architectural checks pass 160 array programs, 124 FILL boundary programs and
56 changing-pitch row programs; the existing five-size linear/XY FILL
IRQ/NMI continuation bench and strict lint also pass. These checks do not
establish the full 140-case partial timing matrix or the preceding 2,240
aligned matrix on the changed FPGA implementation. The physically loaded
partition image contains the earlier graphics-Y factoring only; the partial
edge changes still require a new source-bound build and FPGA validation.
Exact multirow partial timing, additional processing/window/mask/transparency
conditions, and posted-wrapper partial-edge interrupt timing remain open.

## Multirow partial-word timing baseline

An additional 280 probes append two- and four-row B/C/D rectangles to the
one-row cases. They retain PS1/2/4/8, N1/2/3, linear/XY, both cache modes,
and a constant word-aligned 0x100-bit pitch. The preceding 2,380 FILL fixture
and program contracts remain unchanged, including order. The FILL inventory
is now 2,660; the complete timing inventory is 142,392 cases. This expands
required coverage without establishing compliance for the new cases.

The unchanged Table13-6 equations apply to the whole rectangle. In particular,
the long-B five-state tail occurs once, rather than once per row. Literal
linear counts for L=2/4 are 14/22 for N1 B, 13/21 for N1 C/D, 20/34 for
N2 B/C, 21/37 for N2 D, and 25/41, 24/42, 25/45 for N3 B, C, D respectively.
XY adds two setup states and disabled cache adds three once. Per-row ordered
edge reads and writes, every defined register, full ST, all affected memory
and both canary words per row remain checked.

On the preceding native one-row RTL, seven directed multirow probes fail
duration while an aligned N3/two-row control passes in each of BASE, W1/P7
and W3. Checked architectural state, memory and bus transactions pass for
all 24 executions. Linear PS4 N3 B with
two rows expects 200 INCLK and observes 224; four rows expect 328 and observe
400. Linear N3 C/D with two rows expect 192/200 and observe 200/216.
These are retained timing gaps. No multirow partial FPGA or full-matrix
pass is claimed. Run a short reproducer with:

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case fill_partial_l_ps4_n3_B_rows2_hit
```

The source6dae / RBF383bf physical baseline now covers all 280 new cases
in BASE, W1/P7 and W3. Each profile returns 32 passing partial cases and
248 duration-only failures; four surrounding NOP controls pass. All 852
raw verdicts replay exactly, including checked architectural state, memory
and ordered bus traffic. Seven failing representatives per profile match
the original Verilator diagnostic observations without clearing their
errors. Enclosing host commands take 4.490/5.844/5.080 seconds. These are
failing-baseline measurements, not a multirow compliance claim.

The row-handoff development schedule combines the row decrement with
loading the next row base, captures EA with the existing WORD action,
and reloads the appropriately shifted COLOR1 before the next write.
B/D rows overlap that preparation with the preceding posted field;
A/C rows retain their drain so external waits cannot disappear inside
row processing. Two scalar flags record the row end alignment and final
row, using the existing synchronous RF write to S46 rather than another
RAM read. The long-B extra tail reservation applies only to the final
row. No field-adapter state, memory port, DSP or wide arithmetic unit is
added, and the independent equations and fixtures are unchanged.

Thirty-two directed cases pass each of BASE, W1/P7, W3 and W1/P1 in
Verilator (128 executions), including all four partial-edge pixel sizes,
L/XY, hit/CD, two/four-row boundaries, aligned controls and the prior
PS8 three-word qualification. This is bounded development evidence;
the complete 2,660-case FILL matrix and ordinary regressions on a matching
new FPGA image remain required.

The local gate also passes all 263 timing model/checker tests, strict lint,
160 array, 124 boundary and 56 changing-pitch/overlapping-row architectural
programs, and the existing ten linear/XY FILL pixel-size IRQ/NMI modes.
Repeating the 56 row programs through the timed word wrapper with and
without HOLD passes 112 executions. The architectural wrapper explicitly
leaves its unused `halted` output open, avoiding a fatal Verilator missing-pin
warning. Fifteen mutation controls pass; twelve timing mutants retain
correct architectural state/memory and fail, and three functional/protocol
mutants fail their specific checks. New mutations remove the C-row wait
drain, serialize the D-row handoff, repeat the long-B tail per row, or omit
the row's lane-address capture.

Use the FPGA batch backend for the expanded matrices after the matching
image and host checking path have been validated.

Run the focused permanent mutation group with:

```sh
python3 modules/jttms10/ver/timing/mutations.py --group fill --report fill-mutations.json
```

The group includes the prior FILL scheduling mutations, a shortened long-B
tail interval, an incorrect partial-word pattern, and a stale posted ACK.
Timing mutants must preserve checked architecture/memory; functional and
transaction failures have separate required diagnostics. A syntax failure
is never accepted as detection.

## PS8 three-word edge qualification

The native one-row FPGA image from source6dae passes all 78 focused comparisons,
but its complete BASE FILL command returns two duration failures among 2,380
cases. Linear PS8/N3/D hit/CD expect 120/144 INCLK and observe 128/152. All 2,380
raw verdicts independently replay; the 2,240 aligned cases also match their
original Verilator references. Both failures reproduce in short Verilator
runs with matching defined architecture, memory and complete relative BUS and
TARGET traces. W1/P7 and W3 FPGA commands stop after the BASE failure; they
are not counted as completed.

A PS8 type-D span has four pixels here, but its partial edges touch three
physical words. Comparing its pixel count with twice the pixels per word
incorrectly calls the aligned two-word processing routine. That routine is
now qualified by full-word mode. The correction changes the scheduling
condition, adds no state or arithmetic resource, and preserves all fixture
definitions and independent timing equations.

Six directed linear/XY hit/CD and aligned controls pass each BASE, W1/P7,
W3 and W1/P1 (24 short Verilator executions), with strict lint passing.
The permanent FILL mutation group restores the unqualified predicate to
require timing-only rejection of this bug; omitting the real aligned
two-word state must still be rejected.

Source27eda832's physical RBF is
`c05a249871c2479a1a96e104fd594764cfd160e1c3f1ceae209766a85f4c9649`.
Its six focused cases pass in each BASE/W1-P7/W3 and match Verilator.
All 2,380 aligned/one-row partial cases pass per profile (7,140 executions),
every raw verdict field independently replayed. The 2,240 aligned cases per
profile also match their original profile-specific Verilator observations.
The separate 280 multirow cases are explicitly excluded from this passing
scope and retain the physical baseline above. Complete ordinary/inventory
regressions and the row-handoff candidate's physical validation remain open.

This `/opt/quartus_free` build takes 904.06 seconds in Quartus and
908.711 seconds enclosing the command. Top infrastructure placement and
internal routing preservation are both 100%, with CPU rebuilt from SOURCE
and no partition fallback. All 88 final STA rows have positive slack; the
21 RAM geometries/modes/counts and 32 DDR margin rows are preserved.
The entire 25MHz appliance uses 11,782 ALMs, 8,062 registers, 373 M10Ks and
six DSPs; this is separate from the CPU-only 20ns/3,500-ALM acceptance gate.
Loader time is 0.328929 seconds; enclosing programming SSH takes 1.400381
seconds. The scoped FILL commands take 9.500/9.080/9.351 seconds per profile.
Concurrent host work prevents a controlled compile-speedup claim. Rapid
Recompile previously hit a Quartus CDB error; this successful command uses
the regular compile flow with fitted partition reuse.

## Non-replace Boolean word baseline

Three hundred appended fixtures cover every Boolean PPOP1..15 at PS1/2/4/8/16,
linear/XY and hit/CD, with one full destination word in one row. PMASK, T and
windowing remain disabled. The preceding 2,660 FILL fixture and program
contracts, including order, are unchanged. FILL inventory is 2,960 and the
complete instruction inventory is 142,692 across the same 133 forms.

The expectations reuse the independent Table7-1 Boolean equations already
used by scalar PIXT. A full word has the same bitwise result for every pixel
size. COLOR1 is AA55 and the initial word is A497: AND gives A015, XOR gives
0EC2, and complement-source gives 55AA. Both canaries, all defined GPRs,
full ST and the final B2 pointer remain checked. The program builder warms
the cache without executing the measured FILL, so non-idempotent operations
see the declared initial destination.

SPVU001A §13.3.2.3 (pp.13-12/13) requires one word write or RMW for a short
row; §13.3.2.4 requires increasing word order. Section13.3.2.5 and Table13-7
give G4 for non-replace Booleans without masking/transparency. Substitution
in Table13-6 A/N1 gives linear setup4 + (1+4) +2 =11 states (88 INCLK).
XY adds two setup states; CD adds three. The bus checker therefore requires
one destination-word read and write, with ordered data/address/IAQ and
logical/target durations. It does not prescribe an unprinted first-read
phase or intra-word processing phase. Duplicate pixel RMWs must fail even
when the architectural result is correct.

Six directed source65e8 Verilator probes retain correct architecture/memory
but fail timing. Linear PS16 AND observes128 versus88 INCLK; linear PS4 XOR
observes480 versus88, and PS1 XOR1824 versus88. The latter two perform12/48
physical transfers instead of two. XY PS8 complement-source observes616
versus104 with six transfers; XY PS16 zero/CD observes536 versus128. These
are permanent failing requirements, not compliant Boolean FILL support.
The complete 300-case family subsequently ran on the matching source65e8
image in BASE/W1P7/W3: all 900 cases fail duration, with 240 per profile also
failing BUS and TARGET word-transaction counts. Checked architecture/memory
pass; every raw verdict independently replays, and the 18 original diagnostic
observations match without clearing errors. Long local matrices are unnecessary.

For one short reproducer:

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case fill_boolean_pp10_l_ps4_n1_rows1_hit
```

Prepare the complete family for the FPGA using the existing transport and
independent source oracle:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare --protocol-version 5 \
    --case fill_boolean_ --output /tmp/fill-boolean.json
```

Use the source-bound `run_batch.py` flow documented in the FPGA README.
All expected counts and bus transactions remain active, so these baseline
commands must fail until the native word-processing schedule is implemented.


## Short C/B row cadence development

Physical source65e8/RBF56696c4e runs the complete 2,660 replacement FILL
fixtures in BASE/W1P7/W3. Each profile passes 2,596 and fails 64 durations;
checked architecture, memory and bus traffic pass. The remaining cases are
C/N1 and B/N2 at two/four rows, all PS1/2/4/8, L/XY and hit/CD. C/N1 is one
machine state slow per row handoff; B/N2 is one state fast. Two rows differ
by eight INCLK, four rows by 24. All 7,980 raw verdicts independently replay.
The original 32 focused probes passed but omitted these two geometries.
Four additional failing representatives match short Verilator observations,
including architecture, memory, relative BUS/TARGET traces and errors.
The 300 appended Boolean probes also retain their separate physical failing
baseline: all 300 fail per profile, with correct checked architecture/memory.

Table13-6 C/N1 overlaps row metadata with its single partial-word RMW.
B/N2 retains that work after the trailing RMW before accepting the next row.
The development correction captures these two row classes before the first
posted word changes the remaining-width RF operand. Two scalar flags select
the existing row synchronization condition; no RAM port, wide arithmetic,
extra transfer or retirement delay is added. The ordinary C/N2+ drain still
preserves its external waits: deriving C/N1 from a later RF value incorrectly
absorbed one wait state in an intermediate prototype.

Forty directed cases include the preceding 32 controls and eight additional
C/N1, B/N2 and neighboring cases. BASE/W1P7/W3/W1P1 each pass all 40 in
Verilator, with architecture, flags, memory and bus checks active. Two
permanent mutants disable the short-C overlap or short-B drain and fail
duration while retaining correct architecture/memory. The complete FILL
mutation group passes 17 controls, rejects 14 timing mutations with correct
architecture/memory and rejects three functional/protocol mutations. The
160 array and 124 boundary architectural programs, 112 timed row/HOLD
executions, ten L/XY/PSIZE IRQ/NMI modes, 266 model tests and strict lint pass. Complete replacement
FILL and ordinary matrices must run on the FPGA after this correction is
compiled, source-bound and programmed. Boolean processing, masks, windowing,
changing-alignment timing and full #144 acceptance remain unqualified.


## Boolean word and row boundaries

The Boolean family now appends 1,500 independent probes for N2/row1,
N3/row1, N1/row2, N2/row2 and N3/row3. Each geometry covers PPOP1..15,
PSIZE1/2/4/8/16, L/XY and cached/CD. All preceding 2,960 FILL fixture and
program contracts remain unchanged. The total FILL inventory is 4,460,
including 1,800 Boolean cases; this adds requirements rather than compliance.

Table13-6 alignment A supplies row coefficients 5 for N1, 10 for N2 and
13 for N3 when Table13-7 gives G4. With the final two-state tail and linear
setup4, the five new geometries require 16, 19, 16, 26 and 45 states.
XY adds two states and CD adds three. Every destination word must have one
ordered read/write pair, irrespective of pixel size. The memory oracle
applies Table7-1 independently to each original word and preserves both
neighboring canaries on every row. No first-read phase is inferred from RTL.

The source175 replacement image passes all 2,660 replacement FILL fixtures
in BASE/W1P7/W3 (7,980 executions), and all 120 focused observations match
profile-specific Verilator references. All raw verdict fields independently
replay, including architectural state, memory, duration and checked bus events.
Full inventory validation remains pending. The Boolean fixtures are separate
failing requirements: the loaded source175 has no native Boolean word schedule.

A short boundary reproducer uses the ordinary Verilator runner:

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case fill_boolean_pp10_l_ps4_n2_rows1_hit
```

Use the existing `--case fill_boolean_` FPGA preparation command for the
complete 1,800-case Boolean family. Programs, expectations and supported
stimulus settings require no FPGA recompile. Arithmetic operations, partial
Boolean words, masks, transparency, window rules, changing alignment and
exact graphics interrupt timing remain outside this bounded family and
remain requirements of #144.


## Native Boolean word-processing development

The development path admits aligned complete-word Boolean FILL PPOP1..15
with PMASK0/T0/W0 at all five pixel sizes. It reads each destination word
once, applies the existing 16-bit pixel Boolean helper to COLOR1 and that
word, then posts one full-word write. The initial and repeated PROCESS
microinstructions select this read dynamically; replacement uses its
existing schedule. The graphics ROM remains 4,096 by 64 bits, and no
register-RAM port, Boolean datapath, DSP or asynchronous memory is added.
Arithmetic PPOP, partial Boolean words, masks, transparency and windowed
conditions retain the generic path and have no new timing claim.

The accepted full-word read retains the field adapter's existing RMW slot
through its following write, as scalar pixel processing already does.
Unrelated operations and CEN pauses release slot credit under the existing
rules. The initial read reserves the row's processing work and launches on
a machine-state boundary; an accepted pending read or captured response
must not be withdrawn when that phase changes. N2 replacement's separate
initial write budget is not charged again to Boolean read processing.
These are transfer/setup rules; no retirement padding changes the measured
boundary or hides a bus/interrupt mismatch.

Boundary development exposed two distinct failures: releasing the RMW slot
added machine states between words; allowing a newly ready first read to
claim a preceding boundary absorbed a one-clock CEN pause. The dedicated
CPU-only response test must pause after the accepted read, rather than
before its reserved launch. It still requires request < pause <= captured
response < resume, exact paused clocks, correct architecture/memory and
ordered physical transactions. Its overlapping-pause completion bound is
separate from the normal suite's exact TI counts and early-pause alignment.

The permanent array IRQ bench additionally exercises XOR at PSIZE1/2/4/8/16,
L/XY. It checks eight whole-word writes against literal C33C XOR 55AA =9696,
compares uninterrupted/IRQ/NMI destination order and memory, verifies PBX,
restored pointers and SP, and checks the nested one-pixel XOR result from
BEEF/COLOR1 5678. The standard `sim.sh arrayirq` includes these cases.
This is architectural continuation coverage; exact Boolean interrupt
recognition/context timing still requires a separate specification audit.

All 61 directed programs pass BASE/W1P7/W3/W1P1 in Verilator (244 executions),
with the independent architecture, status, memory, bus and exact-duration
checks active. The 23 mutation controls pass; 17 actual timing mutations
are rejected while retaining correct architecture/memory, and six functional
or protocol mutations are rejected. New timing controls specifically cover
lost RMW-slot ownership and absorption of short CEN pauses. The complete
response suite passes 55 controls and rejects the lost-response mutation.
The 160 array and 124 boundary architectural programs, 112 timed row/HOLD
executions, 20 replacement/XOR L/XY/PSIZE IRQ/NMI modes, 267 model tests and
strict lint pass. The graphics ROM still has 4,096 words of 64 bits.

Source `caa0d12f87851e1a8e09686d8e13ab03637b9542` is physically validated
as RBF `49dccd1e208ca2e333d238ebb51386a4b6f4647f4c2161b1de4ab337fc44e086`.
All 4,460 FILL cases pass each BASE/W1P7/W3 (13,380 executions), and
183 focused observations exactly match profile-specific Verilator references.
The complete preceding 144,192-case ordinary inventory also passes each
profile (432,576 executions, 133 forms, no exclusions). Every complete raw
verdict independently replays. Ordinary driver walls are
338.393/331.735/338.543 seconds; full FILL walls are 15.150/14.332/16.755
seconds. Six additional early CEN pause widths, 1..6 clocks with one wait
state, pass all 4,460 FILL cases and two NOP controls each (26,772 executions),
with 76 declared positive Verilator comparisons. The separate published
MOVB matrices still fail 27 CD duration targets per profile, as required.
These ordinary passing counts do not include the arithmetic baseline below.

The `/opt/quartus_free` build takes 893.78 seconds in Quartus,
899.332 seconds enclosing wall time. Its stable Top partition retains 100%
placement/internal routing while the CPU SOURCE partition is rebuilt without
fallback. All 21 fitted RAM geometries/modes/counts and 32 DDR margins are
preserved; all 88 final reported STA rows are positive with zero TNS.
This is the 25MHz regression appliance, not CPU-only area/20ns or final NARC
acceptance. One verified programming operation takes 0.333748 seconds,
1.314245 seconds including SSH. Exact saved final-health scripts confirm
the intended active image, unchanged boot/SYSID, healthy bridges/manager,
taint zero and no remaining FPGA processes. Concurrent development work
prevents a controlled recompilation or end-to-end speedup claim.
Evidence is under `/nobackup/tasks/jtcores-144/artifacts/fill-boolean-native-1/`.
Exact Boolean interrupt timing and all broader unqualified conditions remain
open. Short debugging uses Verilator; large supported matrices use DataStorm.

## Arithmetic whole-word failing baseline

Another 1,728 independent fixtures cover PPOP16..21 (ADD, ADDS, SUB, SUBS,
MAX, MIN), PS4/8/16, L/XY and hit/CD. Shapes include N1/N2/N3, single and
repeated rows. Four operand patterns exercise dithering, maximum plus one,
zero minus one and equal maxima. All preceding 4,460 FILL fixture/program
contracts are retained exactly. The new FILL inventory is 6,188; the ordinary
inventory is 145,920. Probe presence does not establish timing compliance.

SPVU001A 7-15/16 Table7-2 supplies unsigned pixel arithmetic, wrapping or
saturating independently at each pixel boundary. COLOR1 can hold a dither
pattern (5-5,12-80), so the memory model evaluates separate source/destination
lanes; a whole-word add or subtract is not its oracle. Table13-7 gives
G=4/5/5/6/5/5 respectively, combined with Table13-6's aligned-word row
equations and Table13-5's setup. There is one destination word read and write
per complete word. Architecture, flags, canaries, pointers and bus checks
remain active. The arithmetic count model and all CPU RTL are unchanged.

Eighteen short Verilator representatives all retain duration failures.
PS4/8 also retain repeated pixel-level read/write traffic instead of the
required word operations. Their checked architecture and memory agree with
the independent arithmetic model. All 1,728 arithmetic cases and two NOP controls now run each BASE/W1P7/W3
on the unchanged source-caa image: 5,190 executions. Each host command exits1;
both NOP controls pass and all 1,728 arithmetic cases fail duration, including
1,152/profile with excess BUS/TARGET transaction counts. Every complete raw
verdict independently replays, and all 18 declared BASE observations match
Verilator diagnostically with their errors retained. There are no architectural,
memory, timeout or overflow failures. Maximum actual event use is 327/512 per
case and 5,751/16,384 per batch. A conservative count of separate bus/target
lines overstated capacity use because a runner event can encode several signals.
Driver walls are 10.277733033/10.298957614/10.453181291 seconds. Final board
health passes without reprogramming/reset. These results belong to test-only
source `5a33c9b097468651a1c212e4770a588e88fc3a03`; proof is in
`artifacts/fill-arithmetic-baseline-1/physical-1/root-all-profiles-review.json`
under the #144 task. All failures remain requirements.

Reproduce the model and selected failing probes with:

```sh
python3 -B -m unittest discover -s modules/jttms10/ver/timing -p 'test_fill*.py'
python3 -B modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case fill_arithmetic_pp16_l_ps4_n1_rows1_s1_hit \
    --exact-case fill_arithmetic_pp19_xy_ps8_n1_rows1_s3_hit \
    --report /tmp/fill-arithmetic.json --traces /tmp/fill-arithmetic-traces
python3 -B modules/jttms10/ver/fpga/check_results.py prepare \
    --case fill_arithmetic_ --protocol-version 5 --output /tmp/fill-arithmetic-fpga.json
```

The timing command is expected to exit nonzero on this baseline. Execute the
prepared FPGA batches using the source-bound driver and current programming
receipt described in [the FPGA runner](../ver/fpga/README.md), preserving raw
captures and nonzero verdicts. A new test program or oracle fixture does not
require recompiling an unchanged CPU image. Arithmetic scheduling, partial
processing words, masks, transparency, window conditions and the full #144
acceptance remain open.


## Native arithmetic word-processing development

A development path extends the aligned full-word PMASK0/T0/W0 FILL schedule
to all six defined arithmetic operations at PS4/8/16. It packs pixel lanes
with spacer bits into operands of the existing shared 32-bit ALU. Addition
absorbs each carry in its spacer; subtraction starts each destination lane
with a set spacer, preventing inter-pixel borrows and retaining an independent
D>=S result for saturation/MAX/MIN. Result extraction uses lane muxes. There
is no additional adder, ALU, DSP or register-file memory port.

ADD overlaps the accepted word read, retaining G4. Other operations capture
the packed ALU result in a 32-bit response register, then use a word-processing
stage before the write; SUBS has a second borrow/clamp stage. This produces
G5/G6 by scheduling each word's read/compute/write, without retirement padding.
Response capture is independent of CEN; processing advances only when enabled.
The prepared row address remains in A when arithmetic owns the ALU, and
must not be replaced with the packed pixel result. Partial words, masks,
transparency and window conditions retain their generic paths.

The pixel/ALU unit passes 179,297 checks, including 4,608 new packed arithmetic
random/literal checks. All 93 directed programs pass BASE/W1P7/W3/W1P1
(372 executions): 72 arithmetic word/row/operand cases and 21 preceding
replacement/Boolean/NOP controls per profile. The source count oracle,
fixtures and seven generated ROM payloads are unchanged. These are bounded
Verilator development checks. All 27 positive FILL mutation controls pass;
19 deliberate timing regressions retain correct checked architecture/memory
while failing timing, and eight functional/protocol regressions are rejected.
The new arithmetic mutations remove a processing stage, remove the SUBS clamp
stage, collapse packed lanes to scalar arithmetic, or capture a stale sum.
Response tests pass 79 positive controls, including 24 arithmetic accepted-read
ACKs during a CEN pause; a lost-response mutant is rejected. Architectural
regressions pass 180 base, 160 array, 124 boundary and 112 timed row/HOLD
programs. The IRQ/NMI bench passes 56 FILL modes, including all 36 arithmetic
PPOP/size/address-mode combinations with nested ISR graphics. That bench proves
architectural continuation only; exact arithmetic interrupt timing remains
unqualified. The independent 270-test FILL model proof carries over because
all its source files are unchanged.

## Native arithmetic FILL physical qualification

The loaded source-bound image uses source commit
`744acd3e9cac22127a9cb2673a494f0c82d4f53b`, RBF SHA-256
`5d071fc8031c273489cc4f2f73bb75b56441a1d7d88f330674a0b4500fcfb25d`, and
receipt SHA-256
`f4b3e6d2a4b3416e0ea2ea5f589d49527c73284bd312258ae7febbf81eaca753`.
Across BASE/W1P7/W3, all 6,188 supported FILL cases pass each profile
(18,564 executions); all 279 focused observations match the exact
source-bound Verilator references. The complete supported ordinary inventory
passes all 145,920 cases per profile (437,760 executions), spanning 133 forms
with zero exclusions. Every raw verdict was independently replayed. Driver
walls were 324.592828061s, 327.129926624s and 350.657596027s respectively.

The `/opt/quartus_free` build completed in 978.16s. It reused 100% of Top
placement and internal routing while freshly fitting the 9,708-node CPU
partition, without fallback. Final STA is positive for the 25MHz appliance.
Concurrent host work overlapped the build and validation, so this timing is not
a controlled speedup comparison.
These measurements do not establish CPU-only 3,500-ALM/20ns or NARC acceptance;
those remain separate gates.

Six supplemental CEN-phase driver jobs passed 6,190 cases each (37,140
total), with 196 declared positive Verilator matches. All raw results were
replayed. The 498 published-target cases produced 417 passes and 81 CD-duration
failures (27 per profile); each driver exited 1 for those retained failures,
with zero raw transport errors. The two positive and two negative diagnostic
observations on BASE exactly match Verilator; W1P7 and W3 have no Verilator
comparison claim. All raw verdict fields were replayed. The saved final-health
script passed on the same image without reset. The 27 published MOVB CD targets, exact
Boolean/arithmetic interrupt timing, broader conditions, normal clean CI and
full #144 acceptance also remain open. This qualification covers only the
tested image, fixture inventory and declared conditions. Root evidence is in
`/nobackup/tasks/jtcores-144/artifacts/fill-arithmetic-native-1/physical-1/`.
