# JTTMS10

Microcoded TMS34010 implementation for [jtcores issue 141](http://gitea.jotego.es/jotego/jtcores/issues/141).
The #141 baseline complete NARC CPU boundary fitted in **2,746 ALMs**, or **19.6%** of the
existing CPU's 14,000 ALMs, meeting the 25% target. It trades block RAM for
instruction control and registers (69 M10Ks, no DSPs). Final-source NARC
gameplay/audio simulation, FPGA constrained timing and unmodified-ROM
MiSTer gameplay pass. See the [NARC validation](docs/narc.md) and matched
[area measurements](ver/area/README.md).

Full instruction timing compliance remains unproven. The independent
[timing suite and coverage ledger](docs/timing.md) expose the known failures
under [issue #144](http://gitea.jotego.es/jotego/jtcores/issues/144).
The standard runner includes an [independent PIXBLT timing suite](docs/blit-timing.md)
for all six encodings, partial [FILL timing coverage](docs/fill-timing.md),
[bounded LINE timing coverage](docs/line-timing.md), and unresolved MOVB targets.
Probe presence reaches 133/133 forms. PIXBLT has 544 fixtures: the published
464-case failing baseline, 60 nonzero-coordinate/offset/pitch probes and
20 wider binary-row probes. The last 20 pass short Verilator checks in three
profiles; their FPGA validation is pending.
Aligned opaque regular PIXBLT uses a native word schedule: all 360 fixtures pass
on DataStorm in base/W1-P7/W3, and 84 focused observations match Verilator.
Aligned opaque binary PIXBLT now has a native word schedule for rows of at
most 32 source bits. It passes 102 focused Verilator observations, including
nonzero coordinates, offsets and unequal pitches. All 102 focused physical
observations match Verilator. Its source-bound FPGA image
passes all 141,952 fixtures /133 forms in each base/W1-P7/W3, including every
binary and regular fixture, with every raw verdict independently replayed.
Aligned replace-only W0 FILL has 2,240 passing hit/CD timing cases
(260 linear and 1,980 XY). Other processing/window/mask/edge conditions
still require timing implementation.
The [partial-word FILL baseline](docs/fill-timing.md#partial-word-edge-timing-baseline)
adds 140 one-row B/C/D edge probes. Ten CPU77 Verilator representatives fail
timing while preserving checked architecture and memory. The full subset also fails all140 duration targets in each BASE/W1P7/W3
FPGA profile, while both NOP controls pass and30 diagnostic observations
match Verilator. The earlier aligned FILL passing scope remains distinct.
The preceding validated 127-form fixture inventory includes
scalar/immediate operations, MPYS/MPYU, shifts/rotates, DIV/MOD, all
memory-to-register MOVE/MOVB modes, nine [control-flow forms](docs/control-timing.md), and register-to-memory stores with
[hidden-write/dependency checks](docs/store-timing.md), scalar coordinate and
register-list operations, pixel reads, linear Boolean writes and aligned
replace-only linear/XY pixel copies and DRAV. The newest
[XY-to-XY copy subset](docs/pixel-xy-copy-timing.md) passes its targeted clean,
cross-simulator, pause and mutation checks. Full current-source normal/clean/CI
validation remains required.
Probe presence is
only a necessary gate; conflicting printed store counts have explicitly
labeled inferred policies and remain excluded from unqualified signoff.
Cached single-word absolute MOVB consumes resident address operands with
the opcode to meet the one-state target printed in both TI tables. Its
cache-disabled seven-state target remains open. The source-bound DataStorm image
passes 141,952 cases across all 133 forms each at base/W1-P7/W3 without
fixture exclusions (425,856 FPGA executions). The directed published-target
command retains 27 CD duration failures.
See [FPGA evidence and reproduction](ver/fpga/README.md).
The runtime [no-stack NMI fixtures](ver/fpga/README.md#no-stack-nmi-runtime-fixtures)
cover the documented NMIM=1 state and bus behavior through the same FPGA
interface. Its total context duration remains explicitly unqualified because
TI does not separately specify that count.
Complete condition, bus and interrupt audits remain
required. Current #144 development shares DSP multiplication with shifts
and uses a second shared product for field alignment;
the final fitted area, FPGA timing and NARC checks must be repeated after
the instruction timing changes are complete.

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

This requires the repository's `jtframe` binary, Python/PyYAML, Verilator
and a C++ compiler. The complete normal runner uses Verilator for unit,
architectural, bus, response, EMU and timing checks. The Python architectural
and timing runners retain an explicit Icarus option for independent debugging. Generated files stay in `ver/build`. `ver/tests.yaml` documents
program words and expected architectural state at retirement. The command
also runs the ALU boundary and complete field-offset/width sweeps.
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
strict lint. At the #141 checkpoint, the NARC simulation completed its 1,310-input-frame
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
SLA/SLL/SRA/SRL/RL support both constant and register counts through the shared
DSP; [shift notes](docs/shifts.md) describe count encoding, flags and timing.
SETF, SEXT/ZEXT, EXGF, BTST, and the hierarchical LMO encoder are also covered; see
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
MPYS/MPYU use an inferred DSP multiply with even/odd destination
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
pointers; see [array ISA notes](docs/array-isa.md). Generic binary transfers fetch
32-bit source chunks and save cached bits for PBX continuation. The timed
aligned short-row path uses one or two 16-bit reads. Its native IRQ/NMI
continuation passes a physical-word Verilator sweep with nested ISR graphics,
waits and CEN pauses; physical FPGA interrupt injection remains unvalidated.
The native regular path also passes all four encodings through a separate
3,280-mode timed-word IRQ/NMI sweep. Its next-source reservation checkpoint and
RETI native timing restoration fix remain pending FPGA validation.
[LINE](docs/line-isa.md) shares the pixel/window/ALU paths and has independent
octant/tie/window cases plus a PC-rewind interrupt test. Array and LINE
continuation benches nest ISR graphics under MMTM/MMFM and compare resumed
write streams; architectural agreement does not establish cycle parity.

The reference runner separately reports documented old-CPU differences for
three same-register auto-update cases, empty register lists, and a maximum-extent
window query. Primary assertions retain the TI results; see
[the memory ISA notes](docs/memory-isa.md) and [array notes](docs/array-isa.md).
