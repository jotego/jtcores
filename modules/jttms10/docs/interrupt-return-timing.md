# Interrupt return timing (#144, in progress)

TI SPVU001A pp.12-230/231 specifies11/14 cache-hit/CD machine states with
a word-aligned SP,15/18 otherwise. Section3.3.1 p.3-6 defines word alignment
by SP[3:0]=0. The instruction pops32-bit ST, increments SP by32, pops32-bit
PC and increments SP again. Full ST is restored; PC's low four bits are
ignored. The guide summary p.12-17 and SPVS002C June1991 p.14 minimum11
agree. No timing-source interpretation is added.

These timing probes explicitly cover PBX=0 with no pending interrupt.
The primary entry also requires PBX graphics resumption and immediate
acceptance of an enabled request active in the last state. Those exact
timing/event contracts remain open; passing the base probes does not
establish them. Existing architectural IRQ benches still pass all eleven
array/PBX scenarios and two LINE scenarios, including NMI/no-stack/HLT
cases, but do not supply the missing exact base/resumption clock proof.

RETI shares early full-width stack reads, existing pop32 microcode and the
shared ALU/register storage. One phase bit rearms the second field at the
first SP update. A single settling clock lets the synchronous SP read port
reflect that update before accepting the next field. Using the ordinary
full-state address lead made both aligned and unaligned prototypes one
state late, with correct architecture; a permanent mutation reproduces
that failure. Two CPU states remain after the second response. The source
uses the SP destination read port, preserving the separate B10 source for
PBX resumption. Captured EA now uses the actual accepted address, which is
equivalent to the earlier source selection on all previous forms. No
microcode, arithmetic unit, register bank or DSP is added.

The independent model builds two distinct32-bit reads. At an unaligned SP
the shared boundary word is read twice: six physical transfers, rather than
five unique words. Each transfer charges its own wait; each field's words
must be consecutive, globally ordered and on the machine-state grid
inside the measured instruction. The entry gives total states rather than
an internal first-read microstep, so that edge is not invented. Logical/raw
address/data/IAQ, durations and readiness windows remain independent checks.
CD's next opcode read follows the published total. Original electrical
bus-pin phases remain outside this transport contract.

The1412 programs cover all stack alignments, all NCZV patterns crossed
with restored IE, every ignored original field definition, discarded PC
bits, high/wrapped addresses, opcode positions, TI's numeric stack example
and48 actual A/B target loads. Every initialized register, full ST, return
PC, following state/timing/traffic and sparse read-only word is checked.
The wrapped vectors preserve both reset-vector words. A prototype vector
atFFFFFFD0 overwrote reset low wordFFFFFFE0 and faulted before the test;
that failed batch was stopped for the demonstrated fixture bug, with its
reason/status retained. The corrected vector restores10000810h and a
permanent model guard rejects conflicting reset-vector data.

All1412 W=1/CEN=7 Verilator programs,122 models,180 architectural programs,
strict lint,84 short Icarus phase cases and both new timing mutations pass.
The response-event bench has nine controls/one duplicate-read mutant,
including RETI responses during160-clock CPU pauses. Its bounded event
checks do not replace exact unpaused instruction counts. All1412 stressed
case objects and source/generated-ROM hashes match Icarus and Verilator
exactly. A detached clean checkout repeats122 models, all1412 stressed
programs and nine response controls/one mutant with exact case/event
objects and provenance. Four separate-process probes match batching apart
from local case identifiers. All44 timing input hashes match public
6c7393c8c; its full Git tree equals isolated3520aa037. This clean scope is
targeted; full standard-runner and full clean-checkout acceptance remain
pending. All86,098 preceding fixtures/programs/goldens are unchanged.

On the preceding public dc661d409 HDL/YAML, all1412 historical programs
fail timing with correct architectural/following state and read-only
memory. Ordinary cached116/148 INCLK becomes88/120; CD144/176 becomes
112/144. The committed baseline keeps108 representatives and22 verified
old HDL/YAML hashes. It is historical evidence, never an oracle or allowlist.

Probe presence becomes110/133 forms with87,510 cases, leaving23 missing.
There remain10,771 explicit source choices and448 unresolved MOVB probes,
including45 agreed published targets; strict audit retains11,219 differences.
Remaining stack/call/list, graphics, cache/peripheral/HOLD/IRQ/resumption,
conditions and known targets remain open. The matched complete NARC GSP
map estimates3,643 ALMs,5,159 ALUTs,1,723 registers,538,624 RAM bits,
five DSPs and zero MLAB bits: +73 ALMs/+77 ALUTs/+one phase register
relative to RETS, with unchanged RAM/DSP totals. Same158 virtual pins,
Quartus Lite20.1.1 Build720,5CSEBA6U23I7,20ns,seed1 and effort. All36
snapshot hashes and the same46 warning classifications verify. This is a
live-source capture (`source_commit:null`); no RETI fitter/STA claim is made.
The
preceding RETS fit exceeds the3,500-ALM limit; final area, full board STA,
NARC simulation and MiSTer gameplay remain required. These probes do not
establish full timing compliance.
