# Project choices where TI sources conflict (#144)

The project owner directs: “If you cannot find a reliable conclusion,
implement the easier one” (2026-10-18). Online searches have not located a
verified SPVU001B or a relevant TI erratum. The available 1986/1988 guides
repeat discrepancies; the June 1991 data sheet supplies useful minimum
counts but does not resolve every cache-disabled count or worked example.
Retain the current shared datapath and the interpretations below. These are
explicit project decisions, not official TI corrections or proof that every
contradictory number has been satisfied.

| Rule | Project choice | Evidence and practical reason |
| --- | --- | --- |
| CMPXY | Hit/CD 3/6 states | SPVU001A summary p.12-12 and SPVS002C June1991 p.11 minimum3; the guide entry p.12-56 prints1/4. Retain the simple shared-ALU schedule. |
| Untaken short JR | Hit/CD 1/4 | Entry pp.12-94/95 and data-sheet p.14 minimum1, versus summary2/5. Skip the unused operand/target work. |
| Untaken long JR | Hit/CD 2/5 | Data-sheet p.14 minimum2, versus guide entry4/7 and summary1/4. CD5 is explicitly inferred from two intrinsic states and the following-opcode fetch; it is not a printed paired count. |
| Aligned absolute MOVE load | 16-bit5/14;32-bit7/16 | Table13-1 p.13-5 and the CD instruction-word rule, versus entry p.12-153's5/15 and7/13. Keep the common load schedule. |
| MOVE offset store | `3+(H)` hit; `3+H+6` CD | Table13-2/entry p.12-132 disagree for several classes; the chosen equation shares the address/hidden-write schedule and §5.4.7's per-instruction-word CD cost. |
| MOVB offset store | `3+(H)` hit; `3+H+6` CD | Entry p.12-116 and Table13-2 disagree. Retain the shared offset-store schedule, including the documented extrapolation to other alignment classes. |
| MOVE absolute store | `3+(H)` hit; `3+H+9` CD | Table13-2 agrees with the common equation; the typical entry p.12-134 prints different CD counts. |
| Plain MOVE copy, G-to-F alignment | CPU7/CD17 | Table13-4 index12 prints CPU5/CD17/H7 despite three source reads. Retain the common source-read schedule and the self-consistent CD17; the printed 5 remains explicit. |
| CVXYL results | Repeated OR/shift/add formula | Formula pp.4-12/12-59 and pitch encoding p.6-15 conflict with four worked outputs p.12-60. Retain the shared DSP conversion; preserve all four printed alternatives. Timing3/6 agrees. |

Here H is the alignment-dependent hidden-write count from Table13-2.
The detailed [store](store-timing.md), [load](load-timing.md),
[control](control-timing.md), [XY](xy-timing.md) and
[coordinate](coordinate-timing.md) reports preserve conditions and source
alternatives. The source registry contains exact source/count signatures;
new alternatives, changed selected counts, different instruction forms or
changed result expectations cannot silently inherit a choice.

The current source audit reports **12,625 probe instances with project
choices**, zero unresolved probes and zero agreed published-target gaps.
Source `54ab1116` selects literal absolute-byte CD7/CD13 and plain byte-copy CD7
rather than the previous generic CD15/19 and CD9 equations. All 401 previously
unresolved instances are resolved without a new ambiguity fallback. Cached
absolute bytes retain their published one-state intrinsic duration. These
counts are independent Python expectations, never measured RTL timings;
see [native byte contracts](movb-cd-timing.md).

The directed `--published-targets` mode checks the agreeing entry/summary
duration rather than accepting a differing shared-schedule duration. It
selects 164 probes: 114 cached absolute MOVBs (including cold-extension and
new boundary probes),23 cached indirect MOVBs, nine cache-disabled absolute
MOVBs and 18 cache-disabled indirect MOVBs. Agreeing targets stay selected
after an implementation fix; this mode retains passing targets when the
ordinary fixture uses the same count. On the historical cached-MOVB image, 137
pass and 27 CD cases fail solely on duration: absolute expected 56/observed
120 INCLK, indirect expected 56/observed 72. All 164 diagnostic observations
and error lists agree with the original Verilator bench. Failing inputs still
fail the standard equivalence command and do not establish compliance.
Programs, initial state, architectural/memory expectations and existing bus
checks are preserved. Cold extensions retain the independent nine-state fill
penalty. Source `54ab1116` passes all 164 each BASE/W1P7/W3 on DataStorm, with all 492
exact Verilator comparisons. The complete physical bus inventory, ordering and
cycle lengths remain checked; the internal posted-write placement is an
explicit project observation policy, not a claim about TI pin waveforms.

```sh
python3 modules/jttms10/ver/timing/run.py --published-targets --simulator verilator
python3 modules/jttms10/ver/fpga/check_results.py prepare \
    --protocol-version 5 --published-targets --output /path/to/movb-targets.json
```

These commands remain mandatory regressions after an implementation fix. Any
duration or other checked mismatch still produces a nonzero checking command.
The FPGA runs the same selected programs
and checker through the normal batch transport. The ordinary fixture matrix
retains architectural and bus checks while using the independently specified
cached one-state target. A matrix pass cannot replace the published-target
check. The earlier failing baselines remain archived.

The historical unchanged native-LINE CPU on DataStorm reproduced all 45 duration gaps,
with correct architecture, memory and checked bus events. Two surrounding
NOP controls pass. Four short original Verilator observations match the FPGA
exactly. Cached absolute byte takes 24 INCLK versus eight; cold extension
variants take 96 versus 80. Absolute CD takes 120 versus 56 and indirect
byte-copy CD takes 72 versus 56. These are failing baselines, not compliant
timings. Evidence is tracked in #144.

The normal runner invokes the policy-aware inventory. Calling
`inventory(rows)` without `accept_project_choices=True` retains the stricter
source-only audit, including all 12,625 current discrepancy instances. Both views
preserve the original numbers and citations. The passed source-policy gate
still leaves condition/bus/interrupt/hardware audits required;
`full_isa_signoff` remains false. Missing forms also continue to fail.

The original policy-only step at `3fcd09f9b` modified no HDL, microcode, encoded
program, timing/result expectation or simulation observation. Ten additional checker tests cover
explicit choices, preserved alternatives, exact signatures, actual result
consistency, agreed-target protection and the full inventory. The complete
checker/model suite now has 112 tests after the POPST expansion. Source choices must never be inferred
from measured implementation latency.


Pointer copies add 642 exact project-choice instances. Table13-4 index12
prints CPU6/CD17 for postincrement and CPU6/CD18 for predecrement; the
shared three-read schedule selects CPU8 with the same respective CD
counts. Predecrement index8 prints CPU6/H7/CD15; the common fetch/hidden
state equation selects CD16. [pointer-copy-timing.md](pointer-copy-timing.md)
records these conditions and all alternatives. They are explicit owner
choices, not official TI corrections. At that historical checkpoint,448
MOVB instances remained unresolved. The current totals above supersede that
checkpoint after the cached and native CD byte fixes.

The offset/absolute-source postincrement copies add 1,882 exact choices.
Their entries support the common CPU+hidden+three-CD-states-per-word
equation, while Table13-4 differs at indices6/7/8/9/12. Every affected
probe retains summary and applicable typical-entry values.
[source-copy-timing.md](source-copy-timing.md) also records p.12-156's
inconsistent example pointer and address labels; its numeric result words
anchor the bit model under explicit instruction semantics, not those
conflicting labels. These are project interpretations, not TI corrections.

Two-address copies add 4,331 exact choices, retaining every applicable
entry/summary alternative. The shared equation adds two/four intrinsic
operand states and three CD states per instruction word; inconsistent
byte/field table columns do not require additional arithmetic or DSPs.
[copy-pair-timing.md](copy-pair-timing.md) records the literal CD9 offset-byte
and CD12 absolute-field entry values as well as summary alternatives. These
choices did not resolve the448 MOVB target instances at that historical
checkpoint; the later byte implementations resolve them.

EMU with RUN asserted selects6/9 from summaryp.12-17 and the June1991
data-sheetp.14 minimum6, retaining entryp.12-77's8/11. Full ST preservation
follows the later data sheet and is allowed by the entry's indeterminate
NCZV. The296 new exact project choices and the separate pulse contract are
documented in [emu-timing.md](emu-timing.md); RUN-low hold/resume remains open.


Register lists add1,854 exact hidden-state/applicability choices. MMFM's
operation is read-only but its table prints parenthesized2/4, while §13.1.1
defines hidden work as writes. Select H=0 with the literal CPU/CD equations;
empty MMTM also performs no hidden data operation. Every printed alternative
is retained and numeric hidden-state policy is audited independently of
status labels. [list-timing.md](list-timing.md) records n/zero-mask choices
and the worked-example discrepancies. No known MOVB target is waived.
