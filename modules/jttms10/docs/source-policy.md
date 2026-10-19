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

The source audit still reports every discrepancy. The normal gate separates
**12,625 probe instances with project choices** from **448 unresolved MOVB
probes**, including 45 matching entry/summary targets. Absolute MOVB has
116 unresolved instances (27 agreed); plain memory-to-memory MOVB has 332
(18 agreed). All absolute-MOVB variants remain open, including alignments
for which the entry refers to the summary. Its single-word byte-aligned
published `1+(3),7` remains distinct from current `3+(3),15`. Plain byte-copy
index2 prints CPU3/CD7, while the current shared transport gives CPU3/CD9.
These agreed-target mismatches are outside the ambiguity fallback; status
labels cannot waive them. The 100 copy G-to-F CPU choices are separate:
the three source reads and the same table's CD17/H7 contradict printed CPU5.

The normal runner invokes the policy-aware inventory. Calling
`inventory(rows)` without `accept_project_choices=True` retains the stricter
source-only audit, including all 13,073 discrepancy instances. Both views
preserve the original numbers and citations. A passed source-policy gate
would still leave condition/bus/interrupt/hardware audits required;
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
choices, not official TI corrections. The 448 agreed/source-target MOVB
instances remain open.

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
choices leave all 448 prior MOVB target instances unresolved.

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
