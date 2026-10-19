# Register-to-XY pixel replace timing

This subset covers `PIXT Rs,*Rd.XY` with PPOP=replace, PMASK=0, T=0 and
W=0, using legal aligned 1/2/4/8/16-bit pixels. TI SPVU001A pp.12-215..217
requires four visible CPU states, three hidden write states for partial-word
pixels and one for 16-bit pixels; CD counts are 10 and 8. All GPRs and ST
bits, including V, are preserved when W=0. Window checking, other processing,
plane masks, transparency, SRT and broader cache/interference/HOLD/IRQ/
resumption conditions remain unvalidated. Probe presence is not full signoff.

The native path reuses CVXYL's existing scalar DSP products and shared ALU.
It combines signed Y times destination pitch with X times PSIZE, then adds
OFFSET. CONVDP supplies the pitch encoding; CONVSP deliberately differs in
fixtures. B retains OFFSET while the products use existing A/MD/TMP storage.
The coordinate source port stays on Rd through address preparation, then
returns to the color in Rs before posting. This avoids confusing a color's
high half with Y. No DSP, register bank or arithmetic unit is added. Original
opcode family 106 selects scalar entry 152 only for this subset.

The independent equation from pp.4-12/13 is
`EA = ((signed16(Y)*2**(31-(CONVDP&31))) | (unsigned16(X)*PSIZE)) + OFFSET`,
modulo 32 bits. Source pixels use the low PSIZE bits of Rs, including the
coordinate itself when Rs=Rd. Actual register aliases with OFFSET/DPTCH/shared
SP are retained. The tests cover the conversion formula at signed-Y/pitch
extremes; they do not claim an in-range screen interpretation for overlapping
or extreme terms. Negative X is outside this tested domain.

The explicit transport contract allocates the first posted transfer at state3.
A partial pixel uses an ordered read/modify/write pair; a full 16-bit pixel
uses one write. Each physical transfer takes two states plus W waits. Cached
CPU time stays four states; CD waits for trailing writes and the next opcode.
With T posted transfers, a real following load after K cached NOPs starts at
`max(4+K,3+T*(2+W))` states. Bus request/ACK/IAQ/address/data/order/duration
checks remain active. TI specifies totals/hidden states; first-slot allocation
is the project's explicit transport rule.

The skip-prefill program measures the first write against original memory,
initializing and checking all 31 GPRs, full ST and sparse memory. Following
loads use a separate linear pointer while Rd retains its XY coordinate. The
prefill tail restores its destination/status before measuring. Cache-capacity
guards retain the warm-hit assumptions. No state is forced into the CPU.

The 4,636 fixtures cover every legal lane, both banks, all 32 destination
pitch encodings, signed-Y boundaries, all source/pointer identities/aliases,
ignored FS/FE and array corner settings, source patterns, flags/IE, high/
wrapped offsets, opcode phases, 70 real following loads and all six unmasked
replace numeric examples on p.12-217 in hit/CD modes. The literal examples
use CONVDP=20, DPTCH=0x800 and OFFSET=0. Their numeric addresses and results
remain literal, including the four-bit pixel at 20508. Other examples require
processing/window/mask/transparency conditions outside this subset.

All 118,730 preceding fixture/program/golden contracts remain unchanged.
Historical 136 representative probes on unchanged bc9f2cd4d fail timing/bus
with correct architecture/memory; all 22 old HDL/YAML hashes verify. They are
retained as evidence, never oracle input or an expected-failure allowlist.
The first color/coordinate-port prototype aborted its first batch program;
its repeated transcript is excluded, not 124 independent failures.

Three actual timing mutants lengthen the visible CPU budget, delay the first
post or lose its bus credit, with architecture/memory checks kept active.
Four response-event cases observe the first physical posted-memory response
during a 96-clock CPU pause after acceptance, distinct from the immediate
logical post ACK. Holds, ordering, memory and resume remain asserted. This
CPU-only pause contract is separate from exact TI base timing.

Reproduce from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_store_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_store_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_store_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py --case pixel_xy_store_
python3 modules/jttms10/ver/timing/mutations.py
```

Fixtures, phase probes, events and mutants are included in the normal runner.
Remaining ISA/conditions, known MOVB targets, full clean/remote CI, final fitted
area/board STA and NARC/MiSTer acceptance stay open under #144.

Targeted validation passes all 13,908 programs in three profiles. A detached
clean checkout repeats them, 187 models and 41/1 response events with exact
case objects, 54 source/seven generated hashes and response objects. All 606
representative Icarus stress cases match Verilator except batch-local ID,
alongside 102 short phases, two fresh processes, 180 architecture programs,
strict lint and the original 38-request MSW-first assertion. Three new and
14 affected timing mutation controls/rejections retain correct state/memory.
A malformed mutation helper was cancelled for its demonstrated missing main
declaration and corrected; it is excluded, and live runtime matrices were
preserved. Matched map estimates 3,944 ALMs, 5,677 ALUTs, 1,722 registers and
five DSPs, with 36 snapshot/29 committed input hashes verified. No new fit/
STA is claimed. Clean scope is targeted; the full runner is still running
frozen f99e1baa6. No known source target is waived.
