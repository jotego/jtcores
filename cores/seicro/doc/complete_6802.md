# MC6802 completion plan

## Goal and reference

Complete the MC6802 implementation against the documented digital behavior of the
[Motorola MC6802 data manual](MC6802.pdf). PDF page numbers below are counted
from the first page of that file. The goal is a reusable CPU and chip-level
wrapper with reproducible, independently checked tests. Electrical levels,
analog oscillator behavior and power-supply characteristics are outside the
digital model; required digital interfaces and timing remain in scope.

## Architecture and integration order

Use the existing `modules/jt680x` controller, registers and ALU, with the
family's fixed-rate microcode scheduler. Select `jt6802.yaml` and define
`JT680X_6802`; instantiate `jt6802` for the external E/VMA/MR interface.
`6802.yaml` includes `680x.yaml`, retaining its shared arithmetic sequences and
providing bus-phase-specific addressing, stack and interrupt procedures. Cycle
checking remains enabled in the generator. Thirty-two microsteps per ROM entry
accommodate the longer procedures; dispatch and return use the profile's matching step width.

Each accepted crystal enable advances one microstep. The `jt6802` wrapper
supplies two-low/two-high E timing and holds that same scheduler during MR or
host memory stalls. There are no master-clock execution bursts, bus barriers or
separate instruction-retirement scheduler. The existing family controller handles
IRQ/NMI priority, WAI, HALT and BA; the profile supplies its vector/wake sequences.
The shared datapath adds the MC6800 CPX flags and the NSC ADCX compatibility flags.
`jt6802_decode` translates only instruction dispatch and branch decoding; operands
and data remain unchanged. Existing 6801/6301 generated microcode is unchanged.

Instruction completion overlaps prefetch of the following opcode. Tests account
for that boundary: the next opcode transfer is the first cycle of the next
instruction, and its legality is separate from the instruction just completed.
The microcode cycle count includes that prefetch. WAI has no following prefetch:
its eight post-dispatch cycles plus the already-fetched opcode make nine external
cycles. Interrupt service and WAI wake procedures include a final prefetch beyond
their respective twelve and four external cycles through vector loading.

The board wrapper remains `../hdl/jtseicro_mcu.v`, with Seicro's ROM, shared
RAM, internal RAM, DIP, DAC and PAL connections. It selects NSC8105 at runtime,
keeps unused interrupt/halt inputs inactive and enables `FC_COMPAT`. The
shared wrapper's default `FC_COMPAT=0` rejects this undocumented compatibility
operation. NSC8105 timing and flags remain a distinct compatibility claim.
See [pal.md](pal.md) for existing bus, NSC8105 and FC evidence.

Next integration checks are the independently specified instruction/bus audit
below, interrupt edge and reset corner cases, the RAM/RE chip wrapper, and
hardware validation. Maintain the existing Seicro regressions alongside the
shared family's tests. Preserve base-family behavior whenever shared code changes.

## Current status

| Area | Current implementation | Remaining work |
| --- | --- | --- |
| Instructions | Shared YAML profile and ALU; 199 baseline operations compared with the previous implementation in each mode, plus opcode eligibility tests. | Independently check every documented opcode, result, flag and cycle; the legacy comparison can preserve the same mistake. |
| Interrupts | Shared IRQ/NMI priority and pending-NMI machinery; 12-cycle entry and exact stack/RTI checks. | Complete edge, masking, reset, simultaneous-event and stalled-bus corner cases against independent sources, including short IRQ/NMI pulses while the scheduler is stalled. |
| WAI | IRQ and NMI wake, mask handling, four-cycle entry without restacking, BA and RTI are tested. | Complete boundary/phase and reset interactions; resolve the manual inconsistency below. |
| HALT and BA | Instruction-boundary hold, bus release, next-instruction address and pending-NMI priority are tested. | Complete single-instruction operation, IRQ pulse retention and reset/phase combinations. Host pause remains distinct from physical HALT. |
| Reset | Restart-vector sequence and board reset/MR regression retained. | Independently verify all startup timing, output and interrupted-state cases. |
| Bus, E and MR | Fixed-rate wrapper preserves E/VMA/R/W timing; BSR/RTS and all eight release phases with and without host stalls pass. | Complete Table 8 addresses/data checks, MR sampling/limits and electrical-timing assumptions. TSX/TXS source/destination addresses have a directed test. |
| Internal RAM and RE | Seicro wrapper supplies 128 bytes at `$0000–$007F`; RE is not exposed by a generic chip wrapper. | Add and test the reusable RAM/RE/retention wrapper and external data-bus ownership model. |
| Tests | Docker/Verilator entrypoints for shared MCU/family checks and Seicro regressions. The shared entrypoint is configured in the unit-simulation workflow. | Verify the configured GitHub job after publication; complete independent manual-based coverage. |

This is an implementation and coverage audit, not a claim that every existing
instruction or bus cycle is wrong. Each unverified behavior below needs an
independent check before it can be marked complete.

The directed TSX/TXS test checks Table 8's VMA-low cycles: the third cycle
addresses the source register and the fourth addresses the updated destination.
The instruction/flag comparisons additionally check the resulting registers.
The YAML also enables `BRN` (`$21`) and direct `JSR` (`$9D`), which are not
listed in the supplied manual's instruction tables. Treat these as a variant
and compatibility question, not documented MC6802 instructions; preserve
Seicro behavior until their origin and usage are established.

## 1. Establish a reproducible baseline

1. Record the current Seicro and NSC8105 behavior without changing it. Identify
   the 6802-only benches in `ver/hdl`, their fixtures and their actual coverage;
   keep board-specific MR arbitration and Seicro address mapping in core tests.
2. Provide one documented command that generates the YAML microcode and runs
   the CPU tests with Docker/Verilator. Use the existing JTFRAME simulation
   conventions. The existing unit-simulation workflow has a dedicated MC6802
   Verilator job; verify its actual execution after publication.
   Follow the project rules for permanent shared-module suites and core scratch.
3. Keep the previous CPU as a regression reference where useful, but add
   expectations derived independently from the manual. Report the command,
   test results and environment; do not claim independent validation from a
   comparison between related implementations.

Run from the repository root:

```sh
cores/seicro/ver/game/mcutest.sh all
```

The shell entrypoint uses an installed Docker simulator and Verilator, generates
microcode from the current file manifest, and keeps generated sources, build
files and logs in ignored `ver/game/scratch/mcu/`. Individual suites are
`decode`, `compare`, `bus`, `compat`, `board`, `nsc` and `mr`. `compare`
exercises both modes against the previous implementation; `bus` includes the
eight release phases with and without independent host stalls; `mr` runs both
modes with a live Z80. These are migration regression checks, not independent
proof of full manual conformance. The core regression runner is separate from
the shared CI job.

The shared command is:

```sh
modules/jt680x/ver/6802/sim.sh
```

It checks MC6802 interrupt/WAI/HALT behavior, TSX/TXS bus addresses and the
default FC policy, then runs the existing 6801 and 6301 assessments using Verilator. Their generated
microcode digests are checked, including all 220/230 documented opcode bytes;
the 6301 assessment retains its existing SLP timing exclusion. All generated
files and logs stay under the shared suite's ignored `scratch/` directory.

## 2. IRQ, NMI and WAI

Manual: signal descriptions, PDF pages 7–9; stack diagram, page 7; vectors,
page 9; WAI and interrupt timing, pages 16–17; bus operations, pages 18–21.

1. Keep the family's active-high normalized IRQ/NMI interface; a physical chip
   wrapper must invert the active-low pins. IRQ is level-sensitive and gated
   by I; NMI is edge-sensitive and independent of I. The manual specifies
   sampling with E high and
   beginning the interrupt routine when E is low. Implement and test that
   E-clock contract; retain a pending NMI until it can be serviced. The
   manual's flowchart on page 9 puts NMI ahead of eligible IRQ and HALT ahead
   of both; verify simultaneous and repeated requests and any remaining
   ambiguities against a separately identified authoritative reference.
2. Accept a request at the documented instruction boundary, save PC, X, A,
   B and the original condition code in the manual's stack order, set I as
   specified and read the appropriate vector: IRQ `$FFF8–$FFF9`, NMI
   `$FFFC–$FFFD`. Integrate the sequencing into the existing YAML microcode
   and controller, sharing primitives with SWI only where bus sequences agree.
   The current base entry paths are implemented and covered by the shared tests;
   the remaining work is broader independent timing and corner-case validation.
3. On WAI, save state once, enter the wait state and assert the documented
   bus-available behavior. An eligible IRQ or NMI must exit wait and vector
   without a second stack frame, and set I as specified. A masked IRQ must
   not wake WAI; NMI can. The manual lists interrupt handling as 12
   cycles after an instruction, or 4 cycles following WAI; establish exact
   counting boundaries and bus signals from its tables before asserting them.
   Table 8 on page 21 appears to label the final WAI condition-code stack
   cycle as a read, although the stack diagram and WAI description require
   storing it. Treat that row as an apparent manual inconsistency and check
   another authoritative reference before deciding the expected waveform.
   Table 8 does not give a complete hardware-interrupt or reset cycle trace;
   distinguish documented timing from a waveform derived from another source.
4. Verify RTI restores CC, B, A, X, PC and SP after both ordinary interrupt
   entry and WAI. Cover interrupt masking, CLI/SEI and RTI boundaries; IRQ held
   active, masked and released; NMI edge capture, held-low and re-arming;
   requests during instruction execution, bus stalls, HALT, reset and WAI;
   simultaneous requests; stack wrap; vector byte order; and absence of
   duplicate writes. Check address, data, R/W, VMA and E for every bus cycle.
5. Tie inactive inputs explicitly in Seicro until the board wiring is
   confirmed. Check the physical schematic before claiming that any board's
   interrupt inputs are unused. Regression-test both CPU modes and game boot.

## 3. HALT, bus availability and reset

Manual: PDF pages 7–9 and timing figures. HALT is active low and stops the
processor at an instruction boundary; BA goes high, VMA goes low, R/W is in
the read state, and the address remains driven. The data bus is not driven in
the available state. Interrupts are latched while HALT is low and serviced
only after HALT is released, as specified on page 8.

1. Validate the shared HALT and BA interface's documented instruction-boundary
   behavior and output states across all phases. Treat existing host pause
   separately: it must not be silently substituted for the hardware pin.
2. Define data-bus output-enable explicitly for FPGA integration rather than
   relying on internal tri-states. Model address outputs as driven, including
   while BA is asserted. Check WAI, HALT, and their interaction with pending
   interrupts and reset.
3. Verify reset assertion and release, including the manual's minimum reset
   pulse, vector `$FFFE–$FFFF`, I flag and specified output behavior. Test
   reset during a read, write, stalled E, interrupt entry, WAI and HALT; check
   that no partial or repeated write occurs. Do not impose definite values on
   register contents the manual leaves unspecified.
4. Add directed tests for HALT changes in every relevant E phase, stopping
   only after the instruction, single-instruction operation, BA/VMA/R/W/data
   ownership, queued interrupts and resume. Resolve any undocumented race
   explicitly and label it as an assumption.

## 4. Internal RAM and chip wrapper

Manual: PDF pages 1, 7, 10 and 12. MC6802 has 128 bytes decoded at
`$0000–$007F`; RE enables the internal RAM. The MC6802 standby supply retains
the first 32 bytes under the stated power conditions; the MC6802NS differs.

1. Keep the instruction engine independent of board mapping. Add a reusable
   MC6802 chip wrapper for on-chip RAM, RE, bus data selection and external
   bus ownership, preserving a CPU-only interface where useful. Separate the
   chip wrapper from Seicro's ROM, shared memory, DIP, DAC and PAL wiring.
2. Verify RE high and low at `$0000`, `$001F`, `$0020`, `$007F`, `$0080` and
   adjacent addresses. Check reads and writes, data-bus output-enable and
   the documented need to disable external RAM when the internal RAM is
   accessed. Verify that reset does not accidentally clear retained RAM.
3. Define a digital model and interface for standby retention, or explicitly
   document the chosen power-model boundary. Verify preservation of the first
   32 bytes where modeled; do not claim analog power-failure fidelity from a
   digital simulation. Treat MC6802NS and MC6808 variants separately.

## 5. Instruction, flags and cycle audit

Manual: instruction list and flag effects, PDF pages 12–16; cycle counts,
page 17; operation-by-operation external cycles, pages 18–21.

1. Build a manual-derived matrix of every documented legal opcode, instruction
   length, addressing mode, cycle count, register and flag effects. Compare
   it with YAML's legal `entry` values, keeping internal microcode helper slots
   and NSC-only operations non-executable in MC6802 mode. Check all 256 bytes;
   identify unspecified opcodes separately, including Seicro's `FC` policy.
2. For each documented instruction/address mode, verify results and affected
   and unaffected flags against independent expectations. Cover boundaries,
   carries and borrows, overflow, zero, shifts, BCD/DAA, indexed and direct
   address wrap, stack wrap and both outcomes of every branch. Do not assert
   manual-undefined flag values as facts. Verify the existing MC6800-family
   CPX handling independently before altering its flag calculation; do not
   replace it with a generic 16-bit comparison on assumption alone.
3. Compare every instruction's cycle-by-cycle address, VMA, R/W and relevant
   data with Table 8, including dummy or invalid cycles, read-modify-write,
   stack operations, SWI, RTI, branch outcomes and vector fetches. Check the
   table's measurement boundaries before interpreting total cycles.
4. Audit E/EXTAL division and MR timing against figures 14–15 and the limits
   in the manual. Exercise MR assertion and release at documented setup
   points, writes and reads, back-to-back cycles, reset, and host `ready`
   stalls. Explicitly identify host stalls that cannot be represented as
   physical MC6802 MR timing. Check the stated maximum stretch and clarify
   any ambiguity against a reliable source before changing the game behavior.

## 6. Shared module and completion criteria

Keep processor functionality in the existing family engine under
`modules/jt680x`, with a profile manifest and shared tests. Preserve the shared
ALU, controller and registers, use stable generated microcode names and check
profile selection. Update Seicro to use the shared manifest, leaving
board-specific logic in the core. Avoid a second CPU implementation maintained
alongside the family. Test existing 6801/6301 users after shared changes.

Completion requires: all documented opcodes and modes independently checked;
IRQ, NMI, WAI, SWI, RTI, HALT, BA, reset, RE and internal RAM tested;
documented cycle and bus behavior checked; unsupported or electrical behavior
and any assumptions explicitly identified; the shared Docker/Verilator suite
passing locally and actually selected by CI; and Seicro regression passing in
both existing MCU modes. A successful game boot or legacy-oracle comparison
alone does not establish full manual conformance. NSC8105 conformance and the
undocumented `FC` behavior require their own sources and remain separate claims.
