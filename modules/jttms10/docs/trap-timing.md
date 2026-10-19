# TRAP timing (#144, in progress)

TI SPVU001A pp.12-253/254 specifies 16/19 machine states for aligned SP
and 30/33 otherwise (cache hit/disabled). Alignment means the low four
bits are zero. Section8.6 p.8-9 distinguishes TRAP0, which leaves SP and
stack memory untouched, from TRAP1..31, which save PC' and full ST.
All traps set ST to00000010h and load PC through the selected32-bit vector.
The vector address is FFFFFFE0h-32*N; its low-address word is the pointer's
low half. Vector operand low bits are discarded when loading PC.

The entry prints no separate timing exception for TRAP0. Under the owner's
simpler-implementation direction, this implementation applies the printed
alignment columns to TRAP0 too. This is an explicit applicability choice,
not an official TI clarification. TRAP0's functional no-stack rule remains
unconditional, including corrupt, unaligned and wrapped SP values. The
worked examples' After-PC column lists vector locations without specifying
their contents; the tests follow the vector-pointer definition and formula
rather than treating those labels as literal loaded PC values.

For TRAP1..31, the existing ALU predecrements SP by32 for PC' and again
for ST. Each full32-bit field writes MSW first, as p.12-253 requires, with
its descending physical-word order latched in the existing field engine.
Both fields complete before reading the vector. Preparing ST and the
second subtraction at the first write's completion removes an unnecessary
state between the two pushes. One CPU state remains after an aligned
vector response, three for unaligned SP. The existing timing counter
preserves this work across external waits; no arithmetic unit, register
bank or DSP is added. Hardware interrupt helpers retain their original
sixteen-bit MSW-first transfers.

TRAP0 reuses the existing early timed32-bit read path at FFFFFFE0h. Its
four read states leave12/26 CPU states under the selected16/30 rule.
The ordinary field slot qualification preserves each short CEN pause.
An initial sequential-read prototype passed the seven-clock matrix but
absorbed a one-clock pause. Reusing the timed path fixes all six short
profiles; an actual multi-site mutation restores that prototype and must
fail with correct registers, ST, SP and untouched memory.

The independent oracle models two separate32-bit writes for nonzero N,
then the vector's two ascending reads. Aligned cases have six physical
transfers; unaligned cases have twelve, including each partial-word RMW.
The shared boundary word between PC/ST fields retains its separate
transactions. TRAP0 has only the two vector reads. Each transfer incurs
its own waits; CD adds the target opcode's fetch and wait. Assertions
check ordered addresses/data/IAQ, request stability, logical duration,
raw readiness windows, the state grid and transfers within the instruction.
The CD target fetch starts at the printed total minus its three states,
plus all preceding waits. No unspecified internal first-write microedge
or original bus-pin electrical equivalence is claimed.

There are1,800 programs: all32 trap numbers and16 SP alignments, both
cache modes, NCZV/IE, every ignored FS0/FS1 width1..32 and FE, all opcode
positions, vector low bits and high targets, bad/wrapped SP, and16 actual
following A/B loads. Those loads use the reset ST's16-bit field and check
exact following timing, full state and memory. All initialized A0..A3,
B0..B3, SP and applicable B4..B6 remain checked. Input builders preserve
boot vectors initially, reject overlap between a written stack and its
selected vector, and enforce the16-word sparse-memory budget. No expected
result/count enters the HDL manifest.

At this implementation step, all1,800 W=1/CEN=7 Verilator programs and
138 model/checker tests pass. Six short Icarus profiles pass25 programs
each (150), including a following load. Their HDL/YAML/generated hashes
match the final capture; an earlier fixture differs only by a subsequent
four-line vector-overlap/input-size guard. The unchanged38-request
MSW-first stack regression and strict lint pass. The existing180-program
architecture suite also passes before the final TRAP0 read-path change;
the fresh full runner repeats all180 architectural programs and13 functional
IRQ/LINE scenarios successfully on the final source; its full outcome is
pending. All1,800 baseline
programs on2b4fb7683 fail timing/bus checks with correct architectural,
following and memory results; ten representatives retain verified old
HDL/YAML hashes. Historical captures are never an oracle or allowlist.
All five new controls and actual RTL mutants pass, with correct
architectural/following state and memory on rejection. This includes the
original TRAP0 one-clock-pause prototype, wrong word order and shortened
post-response work. The response-retention bench passes13 controls and one
mutant: aligned/unaligned TRAP0 vector reads and TRAP31 first-stack writes
complete during96/160-clock CPU pauses. Working state stays held, memory
and the target opcode are checked, and resume preserves transaction order.
These bounded events do not replace the exact unpaused TI counts.
All1,800 Icarus/Verilator case objects and47 timing-source/generated hashes
match exactly. A detached clean checkout repeats138 models, all1,800 stressed programs
and13 controls/one response-retention mutant with exact observations and
source/generated hashes. Four fresh-process probes match batching except
the local case identifier. This is targeted clean validation, not a full
standard runner. The fresh115-form full runner remains pending.
All90,338 preceding fixture/program/golden hashes remain unchanged.

This adds one form (115/133;18 missing), with92,138 cases. The source gate
still retains10,771 project choices and448 unresolved MOVB instances,
including45 agreed published-target gaps. No known target is waived.
These probes use no pending IRQ/HOLD and default NMI mode. Exact
interrupt acceptance, NMIM conditions, host/display/refresh interference,
graphics resumption and remaining cache conditions still require audits.
Full clean/remote CI, final<=3,500 fitted ALMs, positive full-board STA,
NARC simulation and MiSTer gameplay remain required. This is not full
instruction timing signoff.


Matched NARC GSP quartus_map estimates3,719 ALMs,5,335 ALUTs,1,725 registers,
538,624 RAM bits,five DSPs and zero MLAB bits. This is+30 ALMs/+77 ALUTs
versus CALL, unchanged registers/RAM/DSPs. The combined synthesis result
does not isolate one cause. Same158 virtual pins, device/tool/20ns/seed/effort;
all36 source/ROM snapshot hashes and29 copied inputs verify. The live capture
retains source_commit:null, with content checked against the implementation.
No current fit/STA claim is made; the final fitted limit remains3,500 ALMs.
