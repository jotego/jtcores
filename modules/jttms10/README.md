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
being claimed as verified. Unsupported instructions stop with `fault`;
architectural illegal-opcode trapping remains to be implemented.
Stack and trap assertions currently cover architectural results; physical
MSW-first trap writes and RETI graphics resumption remain outstanding.
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
benches are part of `ver/run.sh`. CPU/bus integration and host transactions
remain pending.
`jttms10_fabric` connects the peripherals and arbiter; its field-adapter
integration bench also runs in the standard suite. MMTM/MMFM use the shared
register RAM and a mask scan, with [register-list semantics](docs/register-lists.md)
and an additional documented empty-list reference difference.

The reference runner separately reports documented old-CPU differences for
three same-register auto-update cases. Primary assertions retain the TI
sequencing; see [the memory ISA notes](docs/memory-isa.md).
