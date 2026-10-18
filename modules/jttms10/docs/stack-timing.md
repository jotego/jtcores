# Stack timing (#144, in progress)

POPST uses the existing timed field-read path, shared SP register and ALU.
TI SPVU001A p.12-227 specifies8/11 hit/CD states with a word-aligned SP,
and10/13 otherwise. Section3.3.1 p.3-6 defines alignment as the four low SP
bits being zero; a32-bit boundary is not required. POPST always reads32
bits, restores full ST and then increments SP by32. Its literal example
at0FF00000h contains0010h/C000h and restoresC0000010h withSP0FF00020h.
The guide summary and later data-sheet minimum agree; no timing-source
exception is added for this form.

The source ports are primed with shared SP on the fetched opcode. The
existing load counter starts the32-bit field; four CPU states remain after
its response, yielding four/six read states plus four CPU states. Every
physical source word charges its own wait. The existing field adapter
handles nonalignment and address wrap; FS0/FS1/FE do not select its width.
READ_STACK consumes the retained response before the existing microcode
updates SP and ST. No microcode, storage bank, register or DSP is added.
The word wrapper retains the existing first-slot eligibility mechanism.

The independent oracle checks the printed total counts and each ordered,
consecutive stack word's address/data/IAQ, logical duration and raw target
readiness window. The entry does not specify an internal first-read
microinstruction edge: the tests require the reads inside the instruction
on the machine-state grid, without inventing that edge. CD's following
opcode start follows the printed total count. This transport model does
not establish original bus-pin electrical phases.

The806 programs cover every SP low-bit position, all sixteen NCZV patterns,
IE restoration, both cache modes, every ignored FS1/FS0 width1..32/FE,
wrapped/high addresses, the literal example and all opcode positions.
Every initialized A0..A3/B0..B3/SP, full ST and sparse memory word remains
checked. Twenty-four real following loads use a different A2 source and
exercise restored width1/16/32, FE0/1 and aligned/unaligned stack and source
fields. Their exact duration, state, logical/raw transfers and read-only
memory remain checked beyond the POPST boundary.

Those following loads exposed a real prototype bug: the completed POPST's
SP read selection took precedence over the next opcode's source priming.
POPST's own count/state were correct, but the load read5020h instead of
A2's6000h. Fetch priming now takes precedence. All24 cases pass after the
fix. Mutation validation also now requires any following instruction's
state/memory to remain correct before calling a failure timing-only; a
model regression guards that classification.

All806 W=1/CEN=7 case objects and source/ROM provenance match Icarus and
Verilator exactly. All112 checker/model tests and180 architectural programs
pass. Six short Icarus pause profiles pass11 cases each, including a real
following load (66 programs). Actual RTL mutations shorten the post-read
work or lose the first-slot classification; both are rejected with correct
state/memory. The latter's one-clock-pause case happened to match, so the
permanent mutation uses the sensitive seven-clock profile. An additional
806-program no-slot experiment fails timing in every case with correct
architectural results; the classification is retained.

The response-retention event bench adds aligned and unaligned POPST
controls with96-clock CPU pauses. Two/three-word responses arrive during
the pause, CPU/sequencer/working state stays held, SP/ST restore correctly
after resume, and every read retains its protocol/order. These join the
three previous controls and duplicate-read mutation. This is bounded
capture/resumption coverage: overlapping CEN can hide CPU wait time, and
these event bounds do not replace the exact unpaused timing tests.

On isolated preceding EMU commit `0fda3320d`, all415 cached baseline
programs fail timing;391 CD programs pass. Ordinary cached POPST takes
60/76 INCLK versus the required64/80, while CD88/104 already matches.
All806 have correct architectural, following-state and read-only memory
results. The committed historical baseline retains the source/ROM
provenance and22 verified old HDL/YAML hashes; it is never an oracle or
expected-failure allowlist. All83,804 earlier fixture/program/golden hashes
remain unchanged.

The matched NARC GSP map estimates3,620 ALMs,5,123 ALUTs,1,722 registers,
538,624 block-memory bits,five DSPs and zero MLAB bits. Relative to the
preceding two-address stage this includes EMU+POPST: +17 estimated ALMs,
+9 ALUTs, unchanged registers/RAM/DSPs. Same complete boundary/158 virtual
pins, Quartus Lite20.1.1 Build720,5CSEBA6U23I7,20ns,seed1 and effort.
This is a synthesis estimate; current fitting/STA are unmeasured and the
final limit remains≤3,500 fitted ALMs.

Probe presence is108/133 forms, leaving25 missing. The matrix has84,610
cases,10,771 project choices and448 unresolved MOVB instances; the strict
source audit retains11,219 discrepancies. Full standard-runner and clean
checkout validation for this stage remain pending. Other stack/call/list,
graphics, full cache/peripheral/HOLD/IRQ/resumption conditions, known MOVB
targets and final fitted area, positive STA, NARC simulation and MiSTer
gameplay remain required. These probes are not full timing signoff.
