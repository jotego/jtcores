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

Interruptible PIXBLT/FILL/LINE checkpoints, PBX graphics resumption, cache
behavior and instruction/bus cycle parity remain outstanding.
