# Draw-and-advance replace timing

This subset covers `DRAV Rs,Rd` with PPOP=replace, PMASK=0, T=0 and W=0,
using legal aligned 1/2/4/8/16-bit pixels. TI SPVU001A pp.12-67..69 specifies
four visible CPU states, three hidden write states for partial-word pixels
and one for 16-bit pixels; CD counts are 10 and 8. All ST bits are preserved
when W=0. Rd receives the sum of its old X/Y halves and the corresponding
halves of Rs, modulo 16 bits separately. X carry never advances Y.

The source is COLOR1 (B9), not Rs. Its low 16 bits form a physical word
pattern; the pixel uses the bits aligned to the old destination address.
COLOR1 bits above 15 are ignored. Address conversion uses old Rd, CONVDP,
PSIZE and OFFSET. Actual aliases with COLOR1, OFFSET, DPTCH and shared SP
retain their single-register meanings. The source data/address are captured
by the post before the final Rd update, so aliasing Rd with COLOR1 cannot
change the queued write. All other GPRs remain unchanged.

The native path reuses CVXYL's scalar DSP products, existing A/B/MD/TMP/EA,
the shared ALU's split-16 addition, and the posted field engine. It prepares
EA, captures the old delta/coordinate, adds the halves, then posts COLOR1 and
commits Rd at the final instruction boundary. The existing finish_mul control
captures the coordinate sum in this context and leaves multiply flags alone.
Original opcode family 109 selects scalar entry 153 only for this subset.
No DSP, register bank or arithmetic unit is added.

An actual regression found while implementing this path was the unsigned
multiply extra-state rule firing for DRAV coordinate conversion. Depending
on X/PSIZE, it added one state with correct registers, flags, memory and bus
sequencing: 24 of the initial 124 probes failed. The rule now requires a real
multiply opcode. An actual removal mutant restores that timing failure;
all 768 existing multiply programs pass three profiles after the correction.
The initial Verilator captures and an Icarus declaration-order compilation
failure are retained as excluded intermediate evidence. Corrected inputs are
used for final validation; no test is allowed to accept the old extra state.

The independent model uses TI's coordinate equation, bit extraction/insertion
and separate 16-bit sums. The transport contract allocates the first post at
state3. A partial pixel performs an ordered read/modify/write pair; a full
16-bit pixel writes one word. Each physical transfer takes two states plus W
waits. Hits keep four CPU states; CD waits for the post and next opcode.
After K cached NOPs, a real following load starts at
`max(4+K,3+T*(2+W))`, where T is the posted transfer count. Logical/raw bus
request, ACK, IAQ, address, data, order and duration assertions remain active.
TI supplies totals/hidden work; first-slot allocation is a project contract.

The skip-prefill route measures the first DRAV so Rd has not already advanced.
Following loads use a separate linear pointer and their prefill destination/
status are restored before measuring. All 31 GPRs, full ST and sparse memory
are checked. No architectural state is forced into the CPU. Cache-capacity
guards retain the warm-hit assumptions.

The 6,126 fixtures cover every pixel lane, both banks, all 32 destination-pitch
encodings, signed-Y limits, all source/pointer identities and aliases, ignored
FS/FE/corner settings, source patterns including every low COLOR1 bit and
ignored high bits, pointer-delta/carry/wrap boundaries, flags/IE, high offsets,
opcode phases, 70 real following loads and all five unmasked W0 replace
examples on p.12-69 in both cache modes. Extreme/overlapping coordinate terms
check the formula and transport, not an in-range screen interpretation.
Negative initial X is outside the tested domain; updated register halves may
wrap. Other processing/window/mask/transparency/SRT and broader cache/
interference/HOLD/IRQ/resumption conditions remain unvalidated.

All 123,366 preceding fixture/program/golden contracts remain unchanged.
Historical 134 representative probes on unchanged69f08ea2a fail timing/bus
with correct architecture/memory; all 22 old HDL/YAML hashes verify. They are
historical evidence, never oracle input or an expected-failure allowlist.
Four actual timing mutants lengthen the CPU budget, delay the first post,
restore the stray unsigned-multiply state, or remove post credit. Correct
architecture cannot waive timing. Four response-event cases observe a real
posted-memory response during a 96-clock CPU pause while the coordinate
commit is held, then verify pointer, status, memory, ordering and resume.
This CPU-only pause event contract is distinct from exact TI base counts.

Reproduce from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case draw_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case draw_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case draw_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py --case draw_
python3 modules/jttms10/ver/timing/mutations.py
```

Fixtures, phase probes, events and mutants are included in the normal runner.
Remaining ISA/conditions, known MOVB targets, full clean/remote CI, final fitted
area/board STA and NARC/MiSTer acceptance stay open under #144.

Targeted validation passes all 18,378 programs in three profiles. A detached
clean checkout repeats them, 197 models and 45/1 response events, with exact
case objects, 55 source/seven generated hashes and response results. All 724
representative Icarus stress cases match Verilator except batch-local ID,
alongside 102 short phases, two fresh processes, 180 architecture programs,
strict lint and the original 38-request MSW-first assertion. Four new and
17 affected timing mutation controls/rejections retain correct state/memory.
All 768 existing multiply programs also pass three profiles with the same
source/ROM hashes. All 123,366 preceding fixture contracts remain unchanged.
The source-order portability fix was followed by new captures; earlier
Verilator results are preserved but excluded from final-input claims.
Matched map estimates 3,963 ALMs, 5,747 ALUTs, 1,722 registers and five DSPs;
36 snapshot/29 committed input hashes verify. No new fit/STA is claimed.
Clean scope is targeted; the full runner remains running frozen c5eb365d8.
