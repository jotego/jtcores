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
