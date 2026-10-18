# EMU timing with RUN asserted (#144, in progress)

SPVS002C, June1991, printed p.14 gives EMU a six-state minimum and marks
all status bits unaffected. SPVU001A's summary p.12-17 gives hit/CD6/9,
while its instruction entry p.12-77 gives8/11 and indeterminate NCZV. The
same entry says RUN-high acts as a NOP and pulses EMUA; RUN-low enters
emulation with a potentially longer duration. Its `ST -> Rd` execution
line conflicts with that NOP description and the register-free0100h opcode.

The project selects6/9 with RUN asserted, following the later data sheet
and summary. This keeps the common one-word instruction scheduler and
preserves all registers and full ST. Preserved NCZV satisfies the earlier
indeterminate statement too; no undefined-bit mask is needed. The simpler
choice follows the owner's ambiguity fallback, retains the entry's8/11
alternatives in every fixture, and is not an official TI correction. Exact
source signatures accept these296 project-choice instances without
waiving any known MOVB target or a different future discrepancy.

The core adds EMU to its existing scheduler with six intrinsic states;
CD adds the ordinary three-state following-opcode cost. No microcode,
arithmetic unit, storage bank or DSP is added. The existing EMU operation
still emits its acknowledgement pulse and samples RUN.

The296 permanent timing programs cover both cache modes, all sixteen NCZV
patterns, every ignored field width1..32/FE in both fields, and all four
opcode positions. Every initialized A0..A3/B0..B3/SP and full ST remains
checked. Full wait/CEN stress passes. All296 case objects and source/ROM
provenance match Icarus and Verilator exactly. All107 checker/model tests
and strict lint pass. A shortened-schedule RTL mutation is rejected with
correct architectural results. The existing coordinate-stage source audit
explicitly excludes later EMU probes and preserves its audited3,520/116
counts; the new EMU source-policy checks are separate.

A separate committed event monitor observes the real CPU EMU output as
another Icarus simulation root. It does not replace or alter the standard
bench, CPU, cache or bus. Eight controls cover both cache modes and pauses
0/1/6/7 with one external wait, retaining exact selected instruction counts,
full state and logical/raw bus checks. Each requires exactly one sampled
acknowledgement inside the measured EMU instruction. Removing the actual
RTL strobe is rejected while timing and architectural results remain
correct. This is a pulse contract; it does not claim original EMUA electrical
pin phases or RUN-low hold/resume timing. `ver/run.sh` runs this monitor
alongside the normal timing suite, whose mutation phase retains the
short-schedule regression.

On unchanged public parent `d65fbc3bc`, all296 programs fail timing/bus
checks with correct full architectural state. Warm EMU takes6 INCLK rather
than48; CD takes32 rather than72. The committed historical baseline retains
28 representatives and22 verified old HDL/YAML hashes. It is evidence,
never an oracle or expected-failure allowlist. All83,508 previous fixture,
program and golden hashes remain unchanged.

This adds probe presence for one form, giving107/133 forms and26 missing.
The inventory becomes83,804 cases,10,771 explicit project choices and the
same448 unresolved MOVB instances; the strict audit retains11,219
discrepancies. Probe presence does not validate every condition. RUN-low
hold/resume, CPU HOLD/IRQ/graphics resumption, broader cache/peripheral
rules, the remaining ISA and known MOVB targets all stay open. Full standard
runner, clean checkout and hardware validation for this stage are pending.
The final hardware gates remain fitted area≤3,500 ALMs, positive STA, NARC
simulation and MiSTer gameplay.
