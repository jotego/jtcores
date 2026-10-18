# Plain memory-to-memory timing (#144, in progress)

Plain indirect MOVE and MOVB now use the shared field engine, including
posted writes. The permanent suite adds **6,860 programs** for these two
forms. The other eight memory-to-memory addressing forms retain their
previous schedule and remain unvalidated for timing.

## Primary rules and explicit choices

TI SPVU001A §13.2.2, printed pp.13-6/7, supplies the alignment indices and
paired CPU/hidden/cache-disabled counts. The operation entries are
pp.12-119 and 12-137/138. Copies preserve every ST bit; field extension does
not add the sign-extension state used by loads into registers.

The oracle classifies the source and destination fields independently,
then selects one of the thirteen Table13-3 indices. It retains the printed
Table13-4 numbers. If R is the number of source words and T the number of
destination transfers, ordinary MOVE uses CPU `2*R+1` states, hidden
`H=2*T-1`, and CD `CPU+H+3`. G-to-G alignment has two additional CPU states,
as its printed 9-state cached entry requires. Partial destination words use
read/modify/write, and whole words use writes. Source data is completely
captured before any destination write, including overlapping fields.

Two discrepancies stay explicit:

- Index12 (G source/F destination) prints CPU5, H7 and CD17. Its source
  spans three physical reads; CD17/H7 also agrees with CPU7 plus the usual
  fetch cost. The project selects CPU7/CD17 under the owner's simpler-
  implementation direction, retaining the printed CPU5. One hundred
  cached probe instances carry this exact project choice. No official TI
  erratum is claimed.
- Byte index2 prints CPU3/CD7. The typical byte-aligned instruction entry
  agrees with that CD7; the shared source-read/RMW/fetch equation gives
  CD9. The implementation currently uses CPU3/CD9. All 332 affected CD
  probes remain unresolved, including 18 agreed entry/summary target gaps.
  A cached three-state match does not resolve the CD discrepancy.

Together with the earlier absolute-MOVB gap, the normal source gate retains
448 unresolved probes, including 45 agreed published-target instances. It
records 3,620 project choices and keeps all 4,068 discrepancies available
through the stricter source-only audit. See [source-policy.md](source-policy.md).
These are probe-instance counts, not distinct rules.

## Data, overlap and following consumers

The model extracts and inserts architectural bits individually, independently
of the RTL DSP alignment product. It computes the warm-up image and the
measured image separately: an overlapping copy need not be idempotent.
All initialized A0..A3/B0..B3/shared-SP values, full ST and every initialized
memory word remain checked. A wrapped source that includes the reset-vector
high word initializes that word to zero so reset still starts at 0x1000.

Coverage includes every width 1..32, both fields/FE, source/destination
alignment combinations spanning all thirteen indices, both banks, aliases,
shared SP, signed-bit/offset boundaries, all byte bit offsets, overlap,
address wrap, flags and every ignored FS/FE definition for MOVB. Thirteen
field and sixteen byte result examples run in both banks/cache modes:
116 literal programs. The last field example's mnemonic selects F0 while
its field column shows FS1=32; its semantic fixture selects/programs FS1=32
and records the distinction. The full width matrix also covers F0.

The 120 dependent-load programs put a real load after K=0/1/3/7/20 cached
NOPs. The first destination transfer begins at CPU-1, after source waits.
The following load starts at:

```
source_waits + max(CPU + K, CPU - 1 + T*(2+W))
```

Here W is the wait-state count per physical transfer. The following load
adds its own reads and final CPU state. Tests check its exact decode
boundary, registers/ST, data/address/IAQ/order and logical/raw traffic.
They exercise completely hidden writes and partial/full residual stalls.
Cached retirement charges source-read waits; trailing-write waits extend
outstanding work and are charged when the following instruction needs it.

## Implementation and permanent checks

The fetched opcode primes both register ports. The first microinstruction
reads the complete source; the second posts its destination and finishes.
The existing MD and field-engine storage hold the payload. Copies retain
a low request clock between read/write so raw field ports can drain the
old acknowledgement. The word wrapper can acknowledge a posted operation
on its actual capture edge, retaining its registered response for CEN
pauses. Slot eligibility survives the copy handoff but clears during an
empty paused interval. The first field-write word selects its read/write
state at acceptance, saving a selector clock before Q1 readiness sampling.
Copies reuse the scalar CPU and the field DSPs; the map still infers five
DSP blocks.

The unchanged 3fcd09f9b CPU fails timing/bus checks in **all 6,860** programs
with zero architectural, following-state or memory failures. The committed
[historical baseline](../ver/timing/baseline-copy-3fcd09f9.json) retains
113 representatives, three harness provenances and 22 verified old
HDL/YAML hashes per capture. It is never an oracle or expected-failure list.

The normal runner contains three **52,046-case** matrices, two DIV pauses
and six 78-case early-CEN unions: **156,608 exact timing programs**. The
suite has 85 checker/model tests, 40 mutation controls and 47 rejection
checks (44 timing/stimulus and three separate event contracts). Four new
actual RTL mutations add CPU work, lose copy slot credit, delay the first
field word or restore a late registered post response. Each must fail
with correct registers/ST and drained memory. The existing raw-field
architectural regression also protects the read/write request gap.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator --case copy_
python3 modules/jttms10/ver/timing/run.py --case copy_ --wait-states 1 --pause-clocks 6
python3 modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/timing/mutations.py
```

The inventory covers 98/133 forms; 35 remain missing. Cold-copy fetches,
extended modes, broader consecutive/implicit-peripheral dependencies,
full CPU HOLD/IRQ/resumption and outstanding-response CEN conditions remain
open. Original electrical pin phases are outside the abstract word port.
Final fitted area ≤3,500 ALMs, positive STA and NARC simulation/MiSTer
validation remain separate gates. The current matched map estimates 3,517
ALMs; it is not a fitted-area acceptance result.
