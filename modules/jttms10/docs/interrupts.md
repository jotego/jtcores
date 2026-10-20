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
These are local Verilator checks; the FPGA runner has no IRQ scheduler yet.

The native regular path has a separate `copyirq-timed` physical-word sweep
for all four encodings. It withdraws an unaccepted next source read before
publishing regular context, and RETI restores the native word/timing state.
All 3,280 local mode executions pass, including nested ISR drawing, waits and
posted-ACK CEN pauses. Source reads must match completed writes at each tested
checkpoint. The original first-word IRQ defect and reproduction commands are
documented in [PIXBLT timing](blit-timing.md). FPGA interrupt injection and
instruction duration across the ISR remain unvalidated.
