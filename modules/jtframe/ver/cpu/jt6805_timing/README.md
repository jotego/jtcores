# JT6805 timing assessment

This isolated simunit assesses the `jt6805` CPU used in `jtframe_6805mcu`.
It uses synchronous `jtframe_ram`, generates microcode in this directory, and
records measured enabled-clock bus events in `bus_trace.csv` plus per-opcode
timing classifications in `timing_results.csv`; IRQ/TIRQ service observations
are recorded separately in `service_results.csv`.

The selected timing profile is the Motorola HMOS column for the 11-bit P3
class, anchored by the exact MC68705P3 sheet in the local component archive
(`/gdrive/jotego/arcade/components/MC68705P3.pdf`, SHA-256
`df1625d1419ce38be5c35b276699c5428beec90d5b3ab84f2439fe7df05950b2`). The
wrapper default ROMW=11 and address truncation fit that profile; the wrapper is
used by Slap, Bubl, Fairy Land Story and Kunio. Its `pc_in` comment also names
MC68705P5 as a variant with that port, so wrapper integration alone does not
prove every board's exact part. Timing expectations use the manual's HMOS
column; P3-specific physical stack conclusions below use only the P3 sheet.
The Motorola M6805 User's Manual, second edition (1983), Table 1-1 and
Appendix G2 identify P3 as an 11-bit-PC HMOS MCU and say HMOS parts do not
implement STOP or WAIT. Those instructions are retained as CMOS-only
extensions and are not included in the 207-instruction HMOS matrix.

The deployed-part audit shows multiple profiles behind this wrapper: Fairy
Land Story uses P5S; Slap-family records identify Tiger-Heli A47_14 as
P3-compatible, Slap Fight A77_13 as P5S, and Get Star A68_14 as P5. In Kunio,
Renegade is P5 while original Kuniokun is P3; Renegadeb removes the MCU. The
Bubl wrapper route for Tokio uses P5, while Bubble Bobble's original MC6801
path is separate. ROMW=11 does not identify one part for every user.

The independent encoding/timing inventory is transcribed in
`manual_inventory.py` from the manual's instruction tables and cycle-by-cycle
summary. It is reconciled against, but never generated from, JT6805 YAML.
When Appendix F disagrees with an instruction-specific table or Appendix G2,
the inventory records the conflicting Appendix F value and follows the
instruction-specific table and, where present, the HMOS bus sequence. The
eight conflict rows are B7 STA direct, BC/CC/DC/EC/FC JMP (direct, extended,
indexed 16-bit, indexed 8-bit, indexed no offset), CE LDX extended, and CF STX
extended. Appendix F values remain explicit in the inventory notes. G2 does
not list CC JMP extended or CE LDX extended, so those rows rely on the
instruction-specific table rather than claiming G2 confirmation.

`manual_cases.hex` and `oracle.csv` contain source-derived HMOS/CMOS
expectations. The runtime gate checks all 237 measured opcode/path outcomes
against the manual HMOS counts and also requires integral four-CEN-per-E
intervals. `known_observations.mem` remains an untouched historical diagnostic
from the earlier implementation; it is not read by the inventory checker or
timing simulation. `strict_hmos.py` independently checks the generated runtime
results against the same manually transcribed HMOS inventory.

The timing boundary is opcode acceptance at an enabled edge where the internal
`ni` control is asserted and the latched opcode in `md` matches the test case.
The public `addr` bus must simultaneously equal the expected 13-bit program
address. This pairs the acceptance boundary with the public bus while excluding
operand/vector fetches; `md` is the synchronous-RAM byte already accepted by
the core. It does not count the broad `fetch` microstate. The raw trace records
public address/data/write signals and the internal qualifier separately.
Three warmed-up NOP intervals each measure exactly eight enabled edges, so
four enabled edges are one E cycle. Reset-to-first-opcode latency is kept
separate from instruction intervals.

The fixture RAM is 11-bit wide to model the selected MC68705P3 ROM interface:
the wrapper's default `ROMW=11` truncates the generic CPU's 13-bit address.
Consequently, the CPU's vector reads at `$1FFE` etc. alias the P3's physical
`$7FE` vector locations, as they do in `jtframe_6805mcu`.

Run from the repository root:

```sh
source ./setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/jt6805_timing
```

The assessment reports independent HMOS matches, CMOS matches, overlaps, and
values matching neither column. A CMOS-only match on an MC68705P3 is an HMOS
profile mismatch, even when it matches the module's YAML cycle declaration.
The observer/harness pass is separate from this silicon-fidelity result. The
207 HMOS instruction forms run once; bit-test branches and conditional
relative branches also run both outcomes. STOP and WAIT are listed as CMOS-only
extensions and are outside the normative HMOS instruction matrix. CSV outputs
and waveforms are generated locally and ignored by Git.

The directed service fixtures cover external IRQ and timer IRQ vectoring,
handler execution, five stack writes, RTI return, stack-pointer restoration,
and a held-CEN pause across a store. Service timing starts at the accepted NI
edge for the interrupted instruction after the completed NOP tail and ends at
the handler opcode acceptance. IRQ and TIRQ each measure 44 CEN edges (11 E),
matching the manual; any other interval is a harness failure. The earlier
52-edge observation included the preceding NOP and was a fixture-boundary
error. The service sequence records five stack writes plus vector fetch, then
verifies RTI restores S and I.

One simultaneous pending-request case confirms the manual's IRQ-before-TIRQ
priority and that TIRQ remains pending through IRQ service and RTI. Separate
masked external IRQ tests release a qualifying pulse before CLI and RTI each
clear I, then require service at the first eligible boundary. For CLI, the
final I-clear micro-op shares its NI completion edge; a pending request is
accepted there and returns to the byte after CLI. RTI restores I before its
final NI boundary. Both fixtures check the full 13-bit return PC at that first
boundary and the stacked return PCL. The mask check uses the I value written
on the completion edge: CLI exposes the request as I clears, while SEI keeps it
masked as I sets. A SEI→NOP→CLI fixture checks that a request remains pending
through SEI and is accepted on CLI completion. The P5 datasheet
specifies a synchronized falling-edge-latched INT input and both pulse widths
`tWL` and `tWH` at least `tcyc + 250 ns` (printed pp. 3-853, 3-861). It says
the opposite level is required to rearm the input (printed p. 3-862). Four
CEN edges equal one normalized E cycle here. Masked CLI and RTI tests use 2E
and 3E asserted pulses; the reset/rearm test uses both a 2E inactive interval
and 2E asserted pulse. At the P5 maximum oscillator rate of 4.2 MHz, the
datasheet minimum `tcyc` is 0.950 us, so 2E is about 1.90 us and exceeds
`tcyc + 250 ns` (about 1.20 us). The testbench clock runs faster than legal
part clocks, so these durations are normalized E-cycle checks, not literal
nanosecond simulation. The generic test input uses asserted-high logical IRQ,
so its rising edge represents the physical active-low INT falling edge. The
raw input remains available to IRQ polling instructions; only interrupt
arbitration uses the retained edge request.

The architectural frame follows the P3 and P5 11-bit profiles supported by
the current `jtframe_6805mcu` users. Both sheets show a 5-bit stack address
with six fixed high SP bits, reset SP `$07F`, a `$60`–`$7F` stack area, and
PCH/CCR frame bytes whose unused high bits are ones (P3 printed pp. 3-571–572;
P5 Figure 5 printed p. 3-855 and SP description p. 3-856). The controller now
keeps the architectural PC at 11 bits, maps SP through `$60`–`$7F`, writes
`$FA` for return PC `$0202`, and writes CCR `$E8` for SWI or `$E0` for IRQ/TIRQ
with the tested flags. Pulls mask the stacked format bits and restore the
target-valid PC. The generic 13-bit public bus remains zero-extended for PC
addresses; 13-bit effective data addresses remain available for wrapper alias
tests.

Directed frame checks cover SWI, all five JSR forms, IRQ and TIRQ, including
PCH/CCR bytes. Separate JSR/RTS and IRQ/RTI probes start at stack address
`$60`: they verify pushes wrap from `$60` to `$7F`, pulls return across the
same boundary, poison at `$5F` is untouched, and PC/SP are restored exactly.
The P3 and P5 manuals independently show the same frame layout and stack
prefix, so this behavior is shared only across those audited profiles.

The matrix's 237 cases contain all 207 documented HMOS forms and both
outcomes for every BRSET/BRCLR and conditional relative branch. All branch
destinations are checked. The fixtures make 169 explicit result/flag/memory/
stack checks across loads/stores, ALU and unary operations, bit operations,
branches, subroutine/interrupt return, and service behavior. Three additional
semantic-only address probes (outside the 237 timing rows) check IX1 carry
from X=$30 plus offset=$F0 to EA=$0120, IX2 X=$20 plus offset=$0150 to
EA=$0170, and the P3 physical alias of public EA=$0800 to RAM address $0000.
Each has a distinct poisoned alternate address and checks the public address
and accumulator result. The manual describes X-plus-offset indexed addressing
in §§2.2.2 and 2.3.5 (printed pp. 11 and 21–25); the exact P3 sheet establishes
the 11-bit physical address map. RESET vectors and
the first fetched opcode are exercised for every fixture, but reset-entry
latency is deliberately not assigned a cycle oracle here. STOP and WAIT are
classified as CMOS-only extensions, outside the P3 timing matrix; their halt
behavior is not dynamically exercised in this P3-focused suite.

The current source-derived result is 237 of 237 HMOS timing outcomes,
including 22 that also match the CMOS column. All intervals are integral in
the independently calibrated four-CEN-per-E observer; no outcome matches
neither source column, and there are zero observer or fixture failures. The
default simunit therefore enforces strict HMOS timing for the audited P3
profile. The old report at source revision `35dbb7636` recorded 22 HMOS matches
and 215 CMOS-only observations; that report is retained as historical context,
not as a passing timing oracle. `known_observations.mem` is not used by tests. The suite separately rejects malformed/incomplete inventory, a
retimed NOP oracle, a changed immediate operand, a swapped indexed effective
and poison address, a corrupted IRQ vector, removal of IRQ edge capture, and
acceptance delayed past the first eligible boundary. It also rejects changes
to the measured timing baseline, service interval, interrupt priority,
masked-pulse state, and P3/P5 stack-frame values.

After the simunit build, run the deliberate empty/truncated/duplicate/malformed
inventory and altered-NOP-timing checks with:

```sh
python3 modules/jtframe/ver/cpu/jt6805_timing/negative_controls.py
```
