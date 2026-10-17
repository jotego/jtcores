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

FILL and full-color PIXBLT may accept an interrupt after a completed
destination word or row. A partial logical field finishes first. The
unfinished array emits no retirement pulse; entry stacks next PC and
ST.PBX=1. Seven synchronous register writes publish B0/B2 and the restart
image in B10–B14. RETI with stacked PBX reloads that image, clears the live
PBX bit, rebases row pointers through the shared ALU, and resumes without
fetching the original opcode. The ISR must preserve the implied B-register
context when it uses graphics; the test uses MMTM/MMFM B0–B14 around a
nested FILL. There is no hidden one-level snapshot to overwrite.

`ver/array/interrupt.sv` compares interrupted and uninterrupted write
streams. It covers 16-bit FILL and unaligned 4-bit PIXBLT with PMASK/XOR,
waiting ACKs, stacked PBX/PC, no entry retirement, nested drawing and one
original opcode fetch. The 4-bit case raises IRQ after its first pixel but
requires entry after the third pixel completes the destination word.
PBH reverse traversal also compares the exact write stream and checkpoint;
TI p. 12-188 requires a linear starting pointer one pixel past the corner,
so its first access predecrements before drawing.

Binary PIXBLT still reads one source bit per pixel; TI requires 32-pixel
source chunks and corresponding B0/context updates. Binary interrupt
continuation is therefore not accepted. Mid-array NMI/no-stack/HLT
combinations, LINE continuation, and complete
instruction/bus cycle parity still need validation. Cache behavior has
separate tests documented in [cache.md](cache.md).
