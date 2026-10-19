# Register-list timing (#144)

MMFM/MMTM now have permanent timing probes. This adds two forms, for
117/133 with 16 graphics forms still missing. Probe presence is not full
instruction/condition/bus/IRQ acceptance.

The primary source is TI SPVU001A (June 1988), printed pp.12-109..112.
SPVS002C (June 1991), p.13, refers these timings to SPVU001B; no verified
copy or relevant TI erratum has been located. The owner's fallback is to
implement the simpler interpretation when reliable clarification is absent.

| Instruction | Cached CPU states | Printed hidden states | Cache-disabled states |
| --- | --- | --- | --- |
| MMFM, word aligned | 3+4n | 2 | 11+4n |
| MMFM, unaligned | 3+6n | 4 | 13+6n |
| MMTM, word aligned | 2+4n | 2 | 10+4n |
| MMTM, unaligned | 2+10n | 8 | 10(n+1) |

Here n is the number of selected registers. The data sheet's footnote
identifies list length and pointer alignment; the guide does not separately
define n in the entry. A pointer selected in its own list is explicitly
unpredictable and excluded; the largest defined fixture has 15 registers.
The zero mask performs no data access or pointer update, retaining the
literal n=0 CPU/CD equations. MMTM still sets N from the initial pointer.
These applicability choices are explicit, rather than invented encodings.

The MMFM parenthesized counts conflict with its read-only operation and
§13.1.1's definition of hidden work as memory writes. The simpler selected
behavior is read-only, with H=0, preserving the printed CPU and CD equations.
There is no dummy write or fabricated bus read. Empty MMTM likewise has no
hidden data operation. The source ledger retains printed H=2/4 or H=2/8
and selected H=0. Exact signatures register the owner's project choices;
removing a descriptive status label cannot hide a numeric discrepancy.
This does not claim an official TI correction or waive the existing 448
MOVB source/target instances, including 45 agreed published targets.

MMFM restores the highest selected register first, reading full 32-bit
fields LSW then MSW and incrementing Rp by 32 for each register. MMTM saves
the lowest selected register first, predecrementing Rp by 32 each time and
writing LSW first. This differs from CALL/TRAP's descending stack-word
order. Both ignore FS/FE. MMFM preserves full ST; MMTM preserves everything
except N, which is the complement of the initial pointer's sign, including
TI's explicit zero/MIN_INT exceptions.

The numeric MMFM example p.12-110 is independently checked, assigning its
values to B3/B7 from the actual list. The printed After labels instead say
B4/B8. The MMTM example p.12-112 prints Before A2=2220A2A2 but After MSW2222.
The operation stores the supplied 2220; tests preserve that differing 2222
rather than claiming both are satisfied. These example-label/value issues
are separate from the repeated instruction semantics.

The implementation reuses the ALU, EA/MD, field engine and LMO encoder.
The encoder skips unselected bits, so sparse masks cost the same as dense
masks of equal length. The existing list storage retains only remaining
bits. Pointer preparation overlaps an issued field; a separating low
request clock and retained request preserve the raw field interface.
Accepted fields retain bus-slot credit for consecutive transfers. The
first field and mask fetch must earn their own slot after a short CEN
pause. The final posted write uses the existing word-slot phase to retain
two CPU states while its remaining transfers overlap cached execution.
No multiplier, DSP or register bank is added.

The independent oracle retains full state for all 31 distinct GPRs, full
ST and every initialized sparse memory word. It checks LSW/MSW order,
repeated unaligned boundary transactions, IAQ, logical durations/grid and
raw dispatch/readiness windows. The selected logical allocation starts
MMFM data at state2 cached/state5 CD, and MMTM at state4/10 cached or7 CD;
fields then stream consecutively. These allocation choices implement the
published counts/hidden overlap, not a claim about undocumented internal
microedges. Cached MMTM charges waits from all fields before the last;
the last field drains behind CPU execution. CD and MMFM charge every
serial physical wait, including both CD program reads.

There are 3,572 fixtures: all lengths0..15 and bit alignments, both banks
and cache modes, all single-register positions with extreme/shared-SP
pointers, flags/IE, ignored FS/FE, sparse/dense/value patterns, high/wrapped
addresses, 32 opcode-phase cases,24 empty/one/maximum boundary-phase cases and 120 actual following loads through
the updated pointer after0/1/3/7/20 cached NOPs. Fixture programs remain
within four warm cache segments; the sparse input limit is64 words.

The earlier27b0d4e44/e633074cc stressed and short-pause profiles passed,
but an added unpaused zero-wait run exposed1,778 cached failures (889 each
MMFM/MMTM), one state late with correct architecture/memory. A first field
accepted at phase1 must retain the current slot; phase2 after a one-clock
pause must wait for the next boundary. The list-specific phase1 restriction
incorrectly delayed the base path. The correction permits phase1 and carries
that same qualification into the final posted CPU-work budget.

The corrected implementation passes all three separate3,572-case matrices:
zero waits/unpaused, one wait/unpaused, and one wait/seven-clock CPU pause,
for10,716 exact programs. All342 short Icarus phases and seven new mutation
controls/rejections pass with all48 source/seven generated hashes exact.
The new unpaused mutant deliberately restores the rejected first-slot rule.
All mutants preserve full main/following state and drained memory. The144
model/checker tests are unchanged. Strict lint,180 architectural programs,
the original38-request MSW-order assertion and17 response controls/one mutant
pass after the correction. CPU/list state holds across256-clock response
pauses; these are bounded wrapper-event checks, not original TI pause counts.

At corrected implementation299d97666, all588 representative Icarus stress
case objects match Verilator exactly after removing only the batch-local case
ID. Four fresh Icarus processes match batching, split between unpaused base
and stressed profiles. A detached clean checkout repeats all144 models, all
three3,572-case matrices (10,716 programs) and17 response controls/one mutant.
Every case object, all48 source hashes and seven generated hashes match the
development profiles exactly; development/clean event records also match.
This is targeted clean validation, not a full standard runner. The old
27/e633 stressed evidence and failed unpaused capture remain historical.

The corrected matched NARC GSP quartus_map estimates3,824 ALMs,5,495 ALUTs,
1,722 registers,538,624 RAM bits,five DSPs and zero MLAB bits. All36 snapshot
hashes and29 committed inputs match299d97666 exactly. Same158 virtual pins,
device/tool/20ns/seed1/effort; no new arithmetic unit or register bank. This
is synthesis without current fit/STA. The final ceiling remains3,500 fitted
ALMs; preceding RETS fit3,649 fails it. Board timing and game validation remain
separate requirements.

The initial117-form invocation failed stale helper anchors before matrices;
e633074cc corrects those helper patterns without changing runtime inputs.
Its fresh invocation was then cancelled for the demonstrated unpaused RTL
bug, with reason/status retained. Neither is accepted as a complete run.
A fresh full invocation is running on frozen299d97666; its completed outcome
remains required, alongside
remaining ISA/conditions/cache/HOLD/IRQ/peripheral/graphics resumption and
final NARC/MiSTer/area/STA/full-clean/CI acceptance.

Reproduce through `bash modules/jttms10/ver/run.sh`; the normal runner and
CI include the list fixtures, models, events, mutations and all six short
phase unions. Targeted execution is:

```sh
python3 modules/jttms10/ver/timing/run.py --case mmtm_ --case mmfm_ \
  --simulator verilator --wait-states 1 --pause-clocks 7
python3 -B modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/load_pause/check.py
```

The committed historical baseline contains32 representative empty/one/four/
maximum-list probes on c086d6563: every timing/bus check fails with correct
full architectural state and memory. All22 old HDL/YAML hashes are verified.
It is historical evidence, never an oracle or expected-failure allowlist.
All92,138 preceding fixtures, programs and goldens remain unchanged.
