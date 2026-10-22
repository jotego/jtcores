# JTTMS10

Instruction timing development has restarted under
[#149](http://gitea.jotego.es/jotego/jtcores/issues/149) from the accepted #141
implementation. #144 is closed **unsolved**. Read the
[restart status and design rules](docs/timing-restart.md): timing adjustments
belong in YAML microcode, with measured resource and speed gates before expansion.
The current `7327cd12` image passes **228 exact FPGA/Verilator comparisons**
across BASE, W1P7 and W3, including ten additional cached ALU schedules
expressed entirely in YAML. All **13,338 cached FPGA matrix executions** pass
with the unchanged Python oracle: 28/133 encoding forms have cached coverage;
105 have no new cached matrix.
Cache-disabled/cold NOP controls pass; full-condition timing signoff remains
open for every instruction form.

The new YAML/HOLD checkpoint (`8a6e8f4e`) fits at a four-seed mean
**3,142.5 ALMs /53.875 MHz** with
69 M10Ks and no DSPs, exactly matching the preceding measured checkpoint.
All seeds pass constrained 50 MHz: the ten additional schedules add no
measured hardware cost. The later `7327cd12` build fix removes only generated
date comments. Current strict lint and the inherited decoder audit remain
open; the #141 validation recorded below is historical.

Microcoded TMS34010 implementation for [jtcores issue 141](http://gitea.jotego.es/jotego/jtcores/issues/141).
The accepted #141 NARC CPU baseline fits in **2,746 ALMs**, or **19.6%** of the
existing CPU's 14,000 ALMs, meeting the 25% target. It trades block RAM for
instruction control and registers (69 M10Ks, no DSPs). Final-source NARC
gameplay/audio simulation, FPGA constrained timing and unmodified-ROM
MiSTer gameplay pass. See the [NARC validation](docs/narc.md) and matched
[area measurements](ver/area/README.md).

`ucode/tms10.yaml` and `ucode/gfx.yaml` are compiled by `jtframe ucode`, as in
JT680X. The scalar and graphics sequencers share one ALU, synchronous
register RAM, operand registers and field bus. Graphics control uses a
separate 4,096-by-64-bit block-ROM image; YAML selects ALU operands, register
addresses, memory/pixel actions, flag masks and flow. See
[the architecture](docs/architecture.md).

Run the self-checking instruction programs with:

```sh
modules/jttms10/ver/run.sh
```

This requires the repository's `jtframe` binary, Python/PyYAML, Verilator, and
a C++ compiler. The architectural runner compiles its SystemVerilog bench once,
then runs each program from runtime fixture files in `ver/build`. Run one case
while debugging with `python3 modules/jttms10/ver/run.py --case CASE`, or repeat
`--case` to select several cases with one compile; the same
build directory retains the executable, program image, memory/vector inputs,
and checkpoint file. Run an individual unit bench with
`modules/jttms10/ver/run.sh --unit NAME` (for example, `--unit field`).
The runtime serializer checks can be run alone with
`python3 modules/jttms10/ver/runtime_test.py`.
`ver/tests.yaml` documents program words and expected
architectural state at retirement. The full script also builds the ALU boundary
and complete field-offset/width sweeps, then runs the existing unit benches
with Verilator `--timing --assert`. Inherited lint warnings are nonfatal during
these diagnostic builds; assertion failures and simulator timeouts fail the
command.
The word-bus smoke test additionally runs the CPU and field adapter together
against a waiting 16-bit memory, including partial-word write preservation.
See [the architecture](docs/architecture.md), [field transfers](docs/field.md), and
[the opcode references](docs/opcodes.md).

Compare the same architectural programs against the pinned existing CPU with:

```sh
python3 modules/jttms10/ver/reference.py
python3 modules/jttms10/ver/decoder/check.py
modules/jttms10/ver/lint.sh
```

That command requires Verilator and a C++ compiler; it checks architectural
results rather than instruction timing. [Area measurements](ver/area/README.md)
use standalone Quartus projects with recorded source hashes.

Validation passes 180 architectural programs, the unit/system suite, 160
independent array programs, 44 all-PPOP PIXT programs, 20 LINE programs and
strict lint. The final NARC simulation completes its 1,310-input-frame
script with exit status zero, over 36.7 million reported retirements and
captured gameplay/audio. It uses the directed POST skip; unmodified startup
is independently verified on MiSTer. The normal quick build is compiled
with `jtcore narc -mrq --seed 2` and passes constrained timing. The
implementation does not claim instruction-cycle equivalence with the
original CPU. Build profiles, source hashes and limitations are recorded
in the [validation report](docs/narc.md).

Current tests cover reset-vector loading, MOVI/MOVK, ADD/SUB and their K
and immediate forms, register MOVE including cross-file, short conditional
JR (short and long), JAcc, JUMP, GETPC/EXGPC, REV, GETST/PUTST,
PUSHST/POPST, CALL/CALLA/CALLR, RETS, TRAP/RETI, ABS/NEG/NEGB/NOT,
ANDI/ANDNI/ORI/XORI, ADDC/SUBB, and all MOVE/MOVB memory addressing forms. The latter
include both field definitions, sign extension, auto-update aliases, signed
offsets, absolute addresses, and memory-to-memory copies.
Reserved opcode ranges take architectural TRAP 30; `fault` remains a
development diagnostic for encodings outside the implemented families.
The exhaustive decoder audit compares all 65,536 words with the pinned
reference, requiring coverage of every recognized instruction encoding.
Stack and trap assertions cover architectural results and physical
MSW-first writes. RETI graphics resumption has separate focused tests.
See [stack and unary ISA notes](docs/stack-isa.md).
SLA/SLL/SRA/SRL/RL support both constant and register counts through shared
bounded shift logic; [shift notes](docs/shifts.md) describe count encoding,
flags, the YAML schedules and the remaining timing scope.
SETF, SEXT/ZEXT, EXGF, BTST, and bounded LMO are also covered; see
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
and host-indirect I/O. Physical asynchronous host-pin timing is outside the
NARC validation, which uses the existing host tie-offs.
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
field/HOLD tests and is connected to the CPU. The real system test covers
opcode/extension fills, loop hits and host-written CD/CF modes.
FILL L/XY and all six PIXBLT forms run in the graphics ROM and have tests for
row pitch, direction, windows, overlap, binary expansion and completion
pointers; see [array ISA notes](docs/array-isa.md). Binary transfers fetch
32-bit source chunks and save cached bits for PBX continuation.
[LINE](docs/line-isa.md) shares the pixel/window/ALU paths and has independent
octant/tie/window cases plus a PC-rewind interrupt test. Array and LINE
continuation benches nest ISR graphics under MMTM/MMFM and compare resumed
write streams; architectural agreement does not establish cycle parity.

The reference runner separately reports documented old-CPU differences for
three same-register auto-update cases, empty register lists, and a maximum-extent
window query. Primary assertions retain the TI results; see
[the memory ISA notes](docs/memory-isa.md) and [array notes](docs/array-isa.md).
