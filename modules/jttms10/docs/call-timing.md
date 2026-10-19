# CALL timing (#144, in progress)

TI SPVU001A pp.12-48/49/50 gives these machine-state counts. Alignment
means SP's low four bits are zero (§3.3.1 p.3-6).

| Form | Cached CPU | Hidden aligned / unaligned | CD aligned / unaligned |
| --- | ---: | ---: | ---: |
| CALL Rs | 3 | 3 / 9 | 9 / 15 |
| CALLA Address | 4 | 2 / 8 | 15 / 21 |
| CALLR Address | 3 | 2 / 8 | 11 / 17 |

All forms push PC', the bit address after all instruction words, then jump.
CALL uses the original source before decrementing SP, including Rs=SP.
CALLR sign-extends its word displacement and adds16 times that value to
PC'; CALL/CALLA discard the target's low four bits. SP decreases by32,
full ST and every other register are preserved. The stack word order is
MSW first, as TI p.12-253 specifies for PC/ST pushes. A32-bit stack entry
remains little endian in memory. This differs from MMTM's explicitly
LSW-first multiple-register writes; CALL does not change that operation.

The implementation reuses the shared ALU, TMP/MD and posted field engine.
CALL captures its source before the predecrement. CALLA/CALLR capture the
last operand into TMP while priming32 and SP for the ALU; PC_MD retains
PC' before changing the target. The field engine captures the entire return
PC and descending write order before cached CPU execution continues.
No arithmetic unit, register bank or DSP is added. The ordinary operand
response path remains in use; an experimental early-capture alternative
was unnecessary and is not included.

The independent oracle starts the stack transfer at intrinsic state2 for
CALL/CALLA and1 for CALLR. Two aligned writes or five unaligned RMW/write
transfers complete at CPU+hidden. CD adds three states per instruction
word, followed by the target opcode fetch. Every physical transfer charges
its own waits. The assertions check address/data/IAQ, MSW-first ordering,
consecutiveness, logical duration, raw readiness windows and the independent
instruction boundary. Correct duration or final memory cannot hide a
wrong word order. These transport checks do not establish original pin
phase equivalence.

The permanent matrix contains1,306 programs: all16 SP alignments, both
cache modes, clear/set NCZV, every ignored FS0/FS1 width1..32 and FE,
A/B source registers and shared SP, all ignored target low bits for ordinary
register sources, high targets/stack addresses, relative displacement
endpoints and0/1/2, and every opcode word position. SP-target fixtures use
aligned SP so a partial pushed word cannot alter the target opcode. Exact
unaligned self-modifying SP-target behavior remains outside this matrix.
All initialized A0..A3/B0..B3/SP and full ST remain checked. The84 real
following loads use A/B registers and0/1/2/3/7/10/20 intervening NOPs to
check residual hidden-write stalls, following state and drained memory.
They load32 bits of the actual pushed PC', rather than only a low word.

Program setup and targets fit the four instruction-cache segments; the
builder rejects a fixture that cannot preserve the claimed warm hit.
Remote targets use eight sparse words, with an explicit16-word input
limit. Cached remote cases freeze CPU execution only after the measured
boundary while the accepted write drains. Local target cases execute
cached instructions during pending writes. Cold-target/operand fills,
cache replacement/contention and consecutive calls still require separate
condition audits. Expected results/counts never enter the HDL manifest.

Short-pause probes exposed two real prototype errors, despite W=1/CEN=7
passing: unaligned addresses could reuse a previous stack slot after a
one-clock CEN pause, and CALLR could issue its CD operand before the
shifted state boundary. A sampled posting permission and CD operand lead
guard preserve the actual bus boundary. Permanent RTL mutants remove each
guard and must fail with correct architectural state and memory. The
prototype is historical evidence, not accepted full timing validation.
Another proposed operand-capture mutant passed its selected probe and is
not counted as a rejection. Failed sparse-target/array-bound fixture
experiments are also excluded from acceptance.

The guide's worked-example memory labels are shifted relative to SP-32;
CALLR's examples also print a saved PC inconsistent with its instruction
length. This matrix follows the explicit PC'/SP semantics and checks the
actual numeric return address. It does not claim those conflicting example
labels as literal anchors or an official TI erratum. The entry timing
counts above do not require a new source-policy exception.

This adds three forms to the coverage inventory (114/133;19 missing),
with90,338 cases and133 model/checker tests. The source gate still retains
10,771 project choices and448 unresolved MOVB instances, including45 agreed
published-target gaps. No known MOVB target is waived. Remaining ISA and
conditions, cache/peripheral/HOLD/IRQ/graphics resumption, full clean/CI,
final≤3,500 fitted ALMs, positive full-board STA and NARC simulation/MiSTer
validation remain required. This is partial implementation, not signoff.

At the implementation commit, all1,306 W=1/CEN=7 Verilator programs,
133 models, strict lint and the unchanged38-request stack-order regression
pass. Six Icarus pause profiles pass28 programs each (168) with all46 timing
input hashes and generated hashes matching the final Verilator capture.
Five new controls and actual RTL mutants pass, including both one-clock
pause guards. All1,306 historical probes on1a771f905 fail timing/bus checks
with correct main/following state and drained memory. The committed baseline
retains20 representatives and22 verified old HDL/YAML hashes. Typical
cached CALL/CALLA/CALLR changes72/80/80 INCLK to24/32/24. The baseline is
historical evidence, never an oracle or expected-failure allowlist.

Matched NARC GSP quartus_map estimates3,689 ALMs,5,258 ALUTs,1,725 registers,
538,624 RAM bits,five DSPs and zero MLAB bits. Versus PUSHST this is+64 ALMs,
+61 ALUTs and+128 registers, unchanged RAM/DSPs. This combined synthesis
measurement does not isolate one change's cost. Same158 virtual pins,
Quartus Lite20.1.1 Build720,5CSEBA6U23I7,20ns,seed1 and effort; all36 snapshot
hashes/29 copied physical inputs and46 warning classifications verify.
The manifest retains source_commit:null for the live-source capture, with
content checked against the implementation. No current fit or STA is claimed.
All1,306 Icarus/Verilator/clean case objects and46 timing source/generated
hashes match exactly. Four fresh-process probes match batching except the
local case identifier. Clean validation repeats133 models,1,306 stressed
programs and response9/1 events; it is targeted, not a full standard runner.
The uninterrupted114-form runner remains pending at this step. The preceding111-form PUSHST full runner completes268,910 exact programs,
128 models,180 architecture,699 bus scenarios,62 controls and70 rejections,
then exits1 solely at22 missing/448 unresolved sources. The newer114-form
CALL runner remains pending. Full clean/remote CI acceptance stays open.


The uninterrupted114-form development standard runner at7b7b40ffc now
completes272,972 exact programs: three90,338-case matrices,two DIV pauses
and six326-case phase unions. All133 models,180 architecture,699 bus
scenarios,67 mutation controls and75 rejections pass (72 timing/bus/stimulus
plus three event contracts), alongside response9/1 and EMU8/1. Exit1 is
solely19 missing forms/448 unresolved source probes. All46 timing-source
and seven generated hashes match the implementation/map. This establishes
the full development runner at this revision; clean scope remains targeted,
and final full clean/remote CI and hardware acceptance remain open.
