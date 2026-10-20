# Interrupt, halt and emulation boundaries

Primary reference: TI, *TMS34010 User's Guide* (1988), chapter 8, section
10.3.3.5 (10-18/19), and EMU (12-77). The existing CPU is compared at the
pinned revision recorded in the scalar ISA notes.

At the next instruction boundary the controller uses the completed status
register, including IE changes from EINT, DINT, PUTST, POPST and RETI. NMI
takes priority over an enabled maskable request. The selected vector is
latched before any waiting memory access. Entry pushes the next PC followed
by ST, each high half first, then loads the vector and initializes ST to
`00000010`. Hardware entry emits no architectural retirement pulse.
NMI uses `FFFFFEE0` and pulses `nmi_clear`; NMIM suppresses both pushes.
Maskable priority and vectors come from the peripheral fabric.

HSTCTL.HLT stops instruction fetch at a boundary. Simultaneous NMI and HLT
complete entry and halt before the first handler instruction, as described
on 10-19. A CPU already halted waits for HLT to clear before accepting NMI.
EMU pulses `emu_ack`; when `emu_run` is low it holds at the following fetch
boundary until RUN resumes. These are synchronous functional interfaces;
physical pin phases and silicon state counts remain unvalidated.

Reserved ranges from TI Table 8-6 dispatch to TRAP 30 at `FFFFFC20`, saving
the PC after the offending opcode. Defined instructions awaiting implementation
retain a diagnostic fault. Unsupported graphics instructions are therefore
not silently treated as reserved opcodes.

`ver/arch/test.sv` exercises delayed-bus IRQ entry, the completed IE behavior,
branch return PC, RETI restoration, stacked and no-stack NMI, HLT precedence,
and EMU bus quiescence/resumption. The scalar YAML suite compares reserved
opcode entry and RETI with the unchanged old CPU. `ver/system/test.sv` also
runs CPU/display-IRQ/handler/RETI through the real field and peripheral fabric.

FILL and PIXBLT may accept an interrupt after a completed
destination word or row. A partial logical field finishes first. The
unfinished array emits no retirement pulse; entry stacks next PC and
ST.PBX=1. Seven synchronous register writes publish B0/B2 and the restart
image in B10–B14. RETI with stacked PBX reloads that image, clears the live
PBX bit, rebases row pointers through the shared ALU, and resumes without
fetching the original opcode. The ISR must preserve the implied B-register
context when it uses graphics; the test uses MMTM/MMFM B0–B14 around a
nested FILL. There is no hidden one-level snapshot to overwrite. Binary
PIXBLT keeps its 32-bit source-bit cache in upper register RAM and publishes
that cache in B12 at entry. B0 advances by 32 on a segment fetch; row-base
reconstruction accounts for the already fetched source chunks.

`ver/array/interrupt.sv` compares interrupted and uninterrupted write
streams. It covers 16-bit FILL and unaligned 4-bit PIXBLT with PMASK/XOR,
waiting ACKs, stacked PBX/PC, no entry retirement, nested drawing and one
original opcode fetch. The 4-bit case raises IRQ after its first pixel but
requires entry after the third pixel completes the destination word.
PBH reverse traversal also compares the exact write stream and checkpoint;
TI p. 12-188 requires a linear starting pointer one pixel past the corner,
so its first access predecrements before drawing.

The same bench covers binary DX32/33/65 transfers across two rows, with
unaligned source chunks, exact source requests, and cached-bit continuation.
The bench covers eight baseline/IRQ variants, including clipped W3 FILL XY
and reverse mixed-format PIXBLT, plus stacked NMI resume, no-stack NMI
abandonment without further pixels or stack writes, and
simultaneous NMI+HLT. The latter completes entry, holds handler fetch until
HLT clears, then resumes through RETI. LINE uses ordinary restart with PBX clear: after each nonfinal pixel it
publishes B0/B2/B10, then accepts IRQ/NMI and stacks PC minus 16. Its focused
bench checks refetch, nested drawing, exact destination writes and a wide
COUNT checkpoint. See [line-isa.md](line-isa.md). Complete instruction/bus
cycle parity still needs validation. Cache behavior has
separate tests documented in [cache.md](cache.md).

The aligned native binary schedule has a separate real timed-word/bus bench,
`ver/array/timed_interrupt.sv`. Its standard `binaryirq-timed` sweep covers all
five pixel sizes, both binary encodings, DX16/32, word/row/final checkpoints,
waits and pauses during posted acceptance. It checks independent output values,
stacked defined status, context pointers, nested ISR drawing and preserved
source/canary memory. The native frame uses a private B10 low-bit tag and
B10..B14 layout described in [blit-timing.md](blit-timing.md). Generic frames
retain their existing format. Temporary RTL mutations demonstrate rejection
of missed checkpoints, cancelling accepted writes and failing to resume timing.
These are local Verilator checks. The V4 FPGA runner can drive LINT pins, but
these graphics continuation cases are not yet validated physically.

The native regular path has a separate `copyirq-timed` physical-word sweep
for all four encodings. It withdraws an unaccepted next source read before
publishing regular context, and RETI restores the native word/timing state.
All 3,280 local mode executions pass, including nested ISR drawing, waits and
posted-ACK CEN pauses. Source reads must match completed writes at each tested
checkpoint. The original first-word IRQ defect and reproduction commands are
documented in [PIXBLT timing](blit-timing.md). FPGA interrupt injection and
instruction duration across the ISR remain unvalidated.

## External-pin entry timing baseline

`ver/fpga/irq_cases.py` defines twelve scalar LINT1/LINT2 cases with W0/W1/W3.
They drive the real pins and I/O synchronization rather than internal `irq_req`.
A measured warm NOP retains its independent eight-INCLK requirement. A
following ADDK counter checks resumption through a MOVI/RETI handler. The host
oracle in `irq_contract.py` checks registers/ST/SP, the frame and vector, all
MSW-first stack writes, vector/fetch/RETI reads and each physical/logical word
duration. Both the original full-system behavioral-stimulus bench and actual
Avalon runner use these same independent expectations; neither supplies golden
counts to the other.

Six cases execute the handler once through a synthetic initial RETI frame,
then initialize the test normally. The measured interrupt therefore enters a
warm handler and has no handler-fetch transactions. The frame still contains
the completed ADDK state, and the handler entry snapshot must show reset
ST=`00000010`, the decremented SP and the counter corresponding to saved PC.
Six cold controls observe final continuation instead and check all four
handler-cache-fill reads as well.

TI SPVU001A (1988) section8.5.1, printed8-7/8, Table8-4 gives recognition1..2
states and an aligned interrupt context switch of16 states. Table8-5 note1
gives instruction interrupt time as execution time less one state: these
one-state ADDKs add zero. Refresh and host traffic are disabled. Six entry
word transfers add `6*wait_states` states. The permanent warm check allows one
INCLK on either edge for comparing the recorded falling pin transition with
the rising handler decode. Its expected W0/W1/W3 bounds are135..145,
183..193 and279..289 INCLK.

Baseline CPU source `d668c39968cc946dac20883f32f573bd1112a9c6` observes
183/231/327 INCLK respectively and fails all six warm cases. Physical V4 and
both Verilator backends agree on the complete50 observations;44 pass.
Architectural state, memory, bus order and individual transfer waits pass in
the failing cases. These failures expose an entry-scheduling requirement;
correct return state does not satisfy it. Frozen host source `48dba0aae`
retains the baseline fixture/checker, and the raw physical evidence is in
`/nobackup/tasks/jtcores-144/artifacts/v4-events-baseline-1/`.

The timed controller now pushes complete32-bit PC/ST fields through the
existing field adapter, instead of issuing each half through the generic
helper. The CPU explicitly requests MSW-first order during hardware entry,
independently of the interrupted opcode; PUSHST/CALL/TRAP keep their existing
order. Entry reads SP from the existing synchronous RF and reuses the shared
ALU for both decrements. No delay padding, register mirror, arithmetic block
or alternate interrupt bus is introduced. `TIMED_PROGRAM=0` retains the raw
entry sequence and its original MSW-first architectural assertion.

Both short Verilator backends now pass all50 cases with warm latencies
143/191/287 INCLK. The checker also requires exactly128/176/272 INCLK for the
aligned context: handler decode minus measured NOP completion minus one state
for each completed ADDK. The saved return PC determines that ADDK count, and
the independently checked A2 value verifies it. Thus the acceptance boundary
does not depend on an internal IRQ-take signal. Table8-4 supplies16 states,
and six physical entry words supply the configured waits. Baseline context
is168/216/312 INCLK, so the stronger check still rejects it. Pin recognition
and context duration are separate assertions.

`ver/fpga/check_irq_mutations.py` proves rejection of slow halfword entry with
correct final state, low-word-first entry with correct final values, and a
skipped continuation instruction. All return ordinary identified case results;
compiler errors and timeouts do not qualify. The new CPU entry schedule is
locally validated only until a new fitted image and physical results are
recorded. This is not full interrupt or instruction-timing compliance.

The separate `--irq-phase-sweep` reference mode keeps these exact expectations
and sweeps all eight assertion clocks16..23 for both LINT pins and W0/W1/W3:
48 cases. The programs and original50 cases are unchanged. CPU `d4f6b1857`
passes36 but fails the twelve phase20/21 pin-recognition checks. W0 latency is
147/146 INCLK versus135..145; W1/W3 add the required48/144 word-wait clocks.
Exact context remains16 states in every case, and all checked state, memory
and bus events pass. Both Verilator backends reproduce the timing failures.
The fixed old phase16 therefore proves the context fix but does not establish
the complete asynchronous recognition rule. These new failures are retained
without widening the specification bounds; physical confirmation and a
recognition-path fix remain required. `ver/run.sh` includes the failing sweep.

Reproduce with `python3 modules/jttms10/ver/fpga/check_external_reference.py
--output /path/to/new-evidence` after sourcing `setprj.sh`. Raw logs and checked
reference results are retained even on the expected baseline failure. For a
separate Avalon failing baseline, run `check_runner.py --manifest
/path/to/new-evidence/manifest.json --output /path/to/new-avalon-evidence`.
`check_external_reference.py --prepare-only --output /path/to/new-fixtures`
writes the same runtime manifest for FPGA execution without compiling a local
model. Pin-phase sweeps, interrupt
priority, unaligned frames, NMI/HLT and graphics checkpoint/entry/resume timing
remain required.

## Explicit context completion versus decode

Protocol5 adds synthesized observations of the actual hardware context-completion
edge and the surrounding architectural retirements. The independent bench uses
public PC/ST installation and public retire, rather than CPU control signals.
SPVU001A printed8-6 steps1..4 define context installation; step5 resumes the ISR.
The later handler decode remains recorded but does not define absolute context
latency. The historical V4 phase20/21 failures above used that later endpoint.
A 60-case boundary audit found no recognition/context/first-MOVI failure with
explicit endpoints. This is a measurement correction, not an I/O recognition fix.

The V5 checker preserves TI's16-state aligned context and17..18-state total
recognition/context envelope with six configured entry-word waits. It separately
requires first long MOVI retirement after3 warm states (printed12-160), or12 cold
states plus four word waits, using the existing nine-state line-fill contract.
Missing/duplicate boundaries and a delayed first ISR fail independently of final
state. The original programs, ISA oracle and archived V4 verdicts are preserved.
The source-bound V5 image now passes all 50 original and 48 phase cases on
DataStorm with zero independent Verilator differences. The later decode remains
in the raw observations; the explicit context/retirement checks own these
latency bounds. Broader IRQ/NMI/HOLD/graphics conditions remain open.

## Unaligned scalar context contract

The permanent V5 fixture generator also covers all fifteen nonzero SP bit
offsets, both LINT pins, W0/W1/W3 waits and cold/warm handlers (180 cases).
SPVU001A printed8-8, Table8-4 note3 gives an exact 28-state context for an
unaligned SP. Each PC/ST push spans three words, with read/modify/write at both
partial edges (printed13-4 caseG). Ten stack transfers and two vector reads
therefore add twelve configured word waits. Recognition plus context is
29..30 states, independent of the first ISR instruction's separate duration.

The expected frame is inserted as two 32-bit bit fields into sentinel-filled
memory. Checks preserve all bits outside those fields and verify actual MSW-first
write/RMW order, data, per-word waits, RETI read order, SP and initialized state.
A deliberate partial-write mutation clears only surrounding bits and must fail
even when all architectural registers and timing agree. The original aligned
and phase fixtures retain their existing program and observation contracts.
These conditions use the same V5 image; programs, initial memory and settings
are runtime payloads. See [commands and validation scope](../ver/fpga/README.md#unaligned-scalar-interrupt-frames).

All 180 unaligned fixtures pass both local backends and the same physical V5
image, with zero differences and every complete raw report independently replayed.
The host command takes 5.083s; programs and initial memory change at runtime,
without recompiling or reprogramming the FPGA. Host source is
`00d7547dae7b62c4d04d599faf7114960b1d64cf`, hardware source is
`bb856bf46a6d63f652c4831c2cd06d8c903954dc`. The normal runner includes the boundary
offsets 1/8/15 and six actual RTL mutation checks; the complete fixture matrix
covers all fifteen offsets. This proves the declared scalar LINT conditions,
not general interrupt or instruction-timing compliance.
