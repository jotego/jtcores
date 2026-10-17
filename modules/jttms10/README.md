# JTTMS10

Microcoded TMS34010 implementation for [jtcores issue 141](http://gitea.jotego.es/jotego/jtcores/issues/141).
The target is at most 25% of the existing CPU's logic utilization, trading
block RAM for instruction control and registers. This is an implementation
in progress; it is not ready to replace the NARC CPU.

`ucode/tms10.yaml` is compiled by `jtframe ucode`, as in JT680X. The
execution RTL contains a shared ALU, synchronous register RAM, a microcode
sequencer, and architectural PC/status/operand registers. Instruction
sequencing and flag masks belong in the YAML.

Run the self-checking instruction programs with:

```sh
modules/jttms10/ver/run.sh
```

This requires the repository's `jtframe` binary, Python/PyYAML, Icarus Verilog,
and `vvp`. Generated files stay in `ver/build`. `ver/tests.yaml` documents
program words and expected architectural state at retirement. The command
also runs the ALU boundary and complete field-offset/width sweeps.
The word-bus smoke test additionally runs the CPU and field adapter together
against a waiting 16-bit memory, including partial-word write preservation.
See [the architecture](docs/architecture.md), [field transfers](docs/field.md), and
[the opcode references](docs/opcodes.md).

Compare the same scalar programs against the pinned existing CPU with:

```sh
python3 modules/jttms10/ver/reference.py
modules/jttms10/ver/lint.sh
```

That command requires Verilator and a C++ compiler; it checks architectural
results rather than instruction timing. [Area measurements](ver/area/README.md)
use standalone Quartus projects with recorded source hashes.

Remaining acceptance gates:

- Complete scalar, memory, graphics, interrupt, and peripheral behavior,
  validated against the existing CPU and TI's TMS34010 User's Guide.
- Preserve the timing needed by NARC; measure instruction and bus timing.
- Measure complete old/new CPU utilization on the same FPGA/constraints;
  the fully functional replacement must use at most one quarter of the logic.
- Replace NARC's CPU and verify game simulation including graphics/audio.
- Compile NARC with `jtcore narc -mrq`, then validate on MiSTer.

Current tests cover reset-vector loading, MOVI/MOVK, ADD/SUB and their K
and immediate forms, register MOVE including cross-file, short conditional
JR (short and long), JAcc, JUMP, GETPC/EXGPC, REV, GETST/PUTST,
PUSHST/POPST, CALL/CALLA/CALLR, RETS, TRAP/RETI, ABS/NEG/NEGB/NOT,
ANDI/ANDNI/ORI/XORI, ADDC/SUBB, and all MOVE/MOVB memory addressing forms. The latter
include both field definitions, sign extension, auto-update aliases, signed
offsets, absolute addresses, and memory-to-memory copies.
Additional encoded families in the YAML require corresponding tests before
being claimed as verified. Reserved opcode ranges take architectural
TRAP 30. Unsupported defined
instructions still stop with `fault`.
Stack and trap assertions cover architectural results and physical
MSW-first writes; RETI graphics resumption remains outstanding.
See [stack and unary ISA notes](docs/stack-isa.md).
SLA/SLL/SRA/SRL/RL support both constant and register counts through a shared
one-bit loop; [shift notes](docs/shifts.md) describe count encoding, flags,
and the outstanding timing difference.
SETF, SEXT/ZEXT, EXGF, BTST, and iterative LMO are also covered; see
[scalar field and bit notes](docs/field-bits.md).

The [standalone peripheral page](docs/peripherals.md) implements CPU-visible
I/O storage/masks, interrupt state, video timing, display-address scheduling,
and DRAM refresh. The [bus arbiter](docs/bus.md) handles NARC cycle kinds,
priority, waits, and partial-write reservations/HOLD restart. Their focused
benches are part of `ver/run.sh`.
`jttms10_fabric` connects the peripherals and arbiter; its field-adapter
integration bench also runs in the standard suite. MMTM/MMFM use the shared
register RAM and a mask scan, with [register-list semantics](docs/register-lists.md)
and an additional documented empty-list reference difference.
MPYS/MPYU use an iterative shared-adder multiply with even/odd destination
and FS1 handling. See [multiply notes](docs/multiply.md) for the independent
seeded arithmetic check.
The [synchronous host engine](docs/host.md) also shares the I/O state and
bus arbiter; its bench covers byte ordering, prefetch, increments, ownership,
and host-indirect I/O. Physical asynchronous host-pin timing remains pending.
DIVS/DIVU/MODS/MODU share an iterative restoring divide through the same ALU;
[divide notes](docs/divide.md) describe flags, overflow, and the seeded
quotient/remainder check.
DSJ variants, MOVX/MOVY, and sequential ADDXY/SUBXY/CMPXY also have primary
and pinned-reference tests; see [scalar XY notes](docs/scalar-xy.md).
The [pixel helper](docs/pixel.md) separately verifies all defined PPOP,
plane-mask, and transparency rules through the shared ALU.
All six PIXT forms and DRAV now use that helper with microcoded memory,
window and XY-conversion sequencing; see [pixel ISA notes](docs/pixel-isa.md).
PIXT, DRAV, clipped-source bus suppression, and 22 PPOP operations also have
architectural programs and independent seeded checks.
CPW and CVXYL have primary and pinned-reference cases; see
[scalar graphics notes](docs/scalar-graphics.md). The word wrapper's
[pixel tag/SRT path](docs/pixel-bus.md) also has a focused delayed-bus test.
The [integrated system](docs/system.md) connects the CPU, field adapter and
peripheral fabric. Its test runs a display-interrupt handler through a waiting
NARC cycle target, including host HLT release and RETI. Boundary IRQ/NMI,
halt and EMU behavior are described in [interrupt notes](docs/interrupts.md).
The [instruction-cache helper](docs/cache.md) has standalone and integrated
field/HOLD tests; CPU integration remains pending. PIXBLT, FILL and LINE
sequencing and interruptible graphics continuation remain outstanding.

The reference runner separately reports documented old-CPU differences for
three same-register auto-update cases. Primary assertions retain the TI
sequencing; see [the memory ISA notes](docs/memory-isa.md).
