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
expectations. `known_observations.mem` is a separate baseline of measured
opcode/path intervals for default-regression stability; it is not a hardware
oracle and does not convert an observed deviation into a manual match. Each of
the 237 measured opcode/path/cycle tuples must match this exact baseline. The
strict HMOS script independently compares every interval to the manual.

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
source setprj.sh
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
priority and that TIRQ remains pending through IRQ service and RTI. A separate
four-enabled-edge asserted IRQ pulse during a NOP while I is verified set on
every pulse edge is released before CLI. The manual says requests are latched
until I clears (printed pp.15, 79), but this DUT does not vector afterward.
The generic test input uses asserted-high logical IRQ; the physical HMOS pin
is active-low and edge-triggered per the manual. The fixture explicitly waits
for CLI to clear I before checking the pending vector.

The remaining architectural finding is the stacked PC high byte. For the
selected 11-bit P3 profile, the manual says unused high-PC bits are stacked as
ones (for example, PC `$0202` becomes `$FA`); the DUT writes `$02`. This is
observed for SWI, five JSR encodings, IRQ, and TIRQ. The generic CPU has a
13-bit visible address, but the MCU wrapper only truncates the ROM address;
that does not change the stacked byte. JSR tests capture writes at the
pre-NBA RAM acceptance edge in the P3 stack area `$60`–`$7F`. The exact P3
sheet specifies reset SP `$7F` and a 31-byte maximum stack; out-of-range wrap
states are not treated as normative part behavior. The P3 sheet also fixes
stacked CCR bits 7:5 to ones: SWI should stack E8 for these reset flags and
IRQ/TIRQ E0 after CLI, but the DUT stacks 08 and 00. A directed legal-boundary
wrap probe starts at P3 SP=$60; the manual expects the next push at $7F, while
the DUT writes at $5F. These P3-specific PCH, CCR and wrap findings are
separate from timing and harness status and should not be generalized to P5
without matching part-specific documentation.

The legal wrap fixture poisons both `$7F` and `$5F`. Correct P3 behavior is
PCL `$03` at `$60`, PCH `$FA` at `$7F`, no write at `$5F`, and internal S `$3E`
(physical SP `$7E`). Default regression accepts only the exact current-core
tuple—PCH `$02` at `$5F`, untouched `$7F` poison, and S `$1E`—as a known
failure. Other tuples fail. Stack tests likewise check PCL, X, A, and low CCR
bits against the manual; only the observed PCH and stacked-CCR high-bit values
are separately retained as known P3 findings.

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

The final result is 22 HMOS timing matches, including 22 also matching CMOS,
and 215 CMOS-only timing matches that deviate from HMOS across 185 distinct
encodings. All 237 intervals are integral in the independently calibrated
four-CEN-per-E observer; no row matches neither source column, and there are
zero observer/fixture failures. These DUT/reference deviations are the
assessment result, not a failing default simunit regression. Run
`python3 modules/jtframe/ver/cpu/jt6805_timing/strict_hmos.py` after simulation
for the strict fidelity gate; it exits nonzero and lists the measured
deviations. The suite separately rejects malformed/incomplete inventory, a
retimed NOP oracle, a changed immediate operand, a swapped indexed effective
and poison address, and a corrupted IRQ vector.
It also rejects changes to the measured timing baseline, service interval,
interrupt priority, masked-pulse state, or any stack-frame value outside the
manual result and the explicit reviewed P3 findings.

After the simunit build, run the deliberate empty/truncated/duplicate/malformed
inventory and altered-NOP-timing checks with:

```sh
python3 modules/jtframe/ver/cpu/jt6805_timing/negative_controls.py
```
