# jt960 — Intel i960KA integer core

Synthesizable, cen-driven i80960KA for the Namco System FL core (Speed Racer /
Final Lap R). The behavioral reference is MAME's `src/devices/cpu/i960/i960.cpp`
(KA/KB device): instruction semantics, condition-code details, call/return
frame handling, reset and interrupt sequences all mirror MAME, including its
known quirks (`faultno` branching like `bno`, `dmovt` clearing AC[31:16],
division by zero returning 0).

## Files

| file             | content                                              |
|------------------|------------------------------------------------------|
| `jt960.sv`       | sequencer FSM, register file, EA calc, bus engine, interrupt entry |
| `jt960_dec.sv`   | instruction class decoder (format, mem size/count, muldiv op) |
| `jt960_alu.sv`   | single-cycle integer ops + condition codes           |
| `jt960_muldiv.sv`| sequential radix-4 multiplier (16 cyc) and divider (64 cyc) |
| `jt960_rcache.sv`| 4-frame local register cache + frame addresses, whole frame per clock |
| `jt960.vh`       | shared localparams (op classes, muldiv ops)          |

`jtframe_edge` (already in files.yaml) latches the IRQ lines.

## Register model

- Flat 32-entry register file: r0-r15 = current local frame (r0=PFP, r1=SP,
  r2=RIP), r16-r31 = g0-g15 (g15=FP). Registers are flops, so call/return can
  update PFP/SP/FP in a single cycle.
- Special registers: AC, PC (process controls, named `PCS`), SAT, PRCB, IP,
  PIP (address of current instruction), ICR (interrupt map, written by
  `synmov` to ff000004).
- Reset: `PC=001f2002` (supervisor, interrupted, priority 31), `ICR=ff000000`,
  IMI fetch of SAT@0, PRCB@4, IP@12, FP=[PRCB+24], SP=FP+64 — same as MAME
  `device_reset`.

## Frame cache (call/ret)

Hardware-faithful 4-frame on-chip cache, as in MAME (`I960_RCACHE_SIZE=4`):

- `call/callx/calls` (and interrupt entry): RIP=IP; if depth < 4 the 16 locals
  are copied into the cache in the same cycle (512-bit wide LUT RAM, r2 taken
  from IP), otherwise they are spilled to memory at FP&~63 (16 word writes
  through the bus engine). Then PFP=(FP&~7)|type, FP=(SP+63)&~63, SP=FP+64.
  A cached call costs 2 cen, a cached ret 2 cen (silicon ~9).
- `ret`: FP=PFP&~63; frames come back from the cache or, when depth exceeds 4
  (or after `flushreg`), from memory. rcache depth is a signed counter so the
  MAME `flushreg`-then-`ret` corner (depth -1 → clamp 0 + memory fill) behaves
  identically.
- `flushreg` writes every cached frame back to its recorded frame address and
  zeroes the depth.
- Return types: 0 (local) and 7 (interrupt, restores PC/AC from FP-16/FP-12)
  — the only ones MAME implements. Others halt.

## Bus protocol

jtframe DTACK style, all state advances on `cen`, bus transactions complete on
`cen & bus_ok`:

```
          ___     ___     ___     ___     ___
cen    __|   |___|   |___|   |___|   |___|
bus_cs ______/^^^^^^^^^^^^^^^^^^^^^\_________
addr   ------<          A          >---------
bus_wr ------<        rd/wr        >---------
bus_ok ____________________/^^^^^^^\_________   slave stretches as needed
din    --------------------<   D   >---------   captured at cen & bus_ok
```

- `addr[31:2]` word address, `dsn[3:0]` active-low byte lanes (also set on
  reads, informational), `dout`, `bus_wr`, `bus_cs`, `bus_ok`. `fetch` flags
  an instruction/displacement fetch so the system can serve it from a
  different (32-bit, read-only) path than data accesses.
- Minimum 2 cen/access (issue + completion), matching the 80960KA 2-clock bus.
  Loads and stores issue their first beat in the dispatch cycle.
- Instruction fetch shares the port: one word per instruction plus one extra
  word for MEMB modes with a 32-bit displacement. No prefetch queue: the
  icache read-ahead covers sequential code on hits.
- Unaligned accesses: any byte/short/word access is split into 1-2 beats with
  lane masking and merge, so unaligned MAME behavior is preserved. Multi-word
  (ldl/ldt/ldq/stl/stt/stq, spill/fill) issues sequential word transactions,
  address+4 each — namcofl maps every range as BURST so MAME also always
  increments.

## Interrupts

4 level-sensitive active-low inputs `irq_n[3:0]` = I960_IRQ0..3. A falling
edge latches the line pending (`jtframe_edge`); taking the interrupt clears
the latch; System FL holds lines asserted until software clears them through
sysreg writes, so re-assertions re-latch.

- Vector for line N = ICR byte N (ICR written by `synmov` to ff000004, reset
  value ff000000). Line with vector 0 is ignored (IAC mode unsupported, as in
  MAME).
- Eligibility checked every instruction boundary: taken when priority
  (vector/8) > PC priority, or priority == 31. Among eligible lines the
  highest vector wins — same observable order as MAME's pending-table scan.
- Entry mirrors `take_interrupt`: read int table pointer [PRCB+20], stack base
  [PRCB+24], vector entry [table+36+(v-8)*4]; call type 7 on the interrupt
  stack (current stack when PC bit13 set = nested); push PC/AC/vector-8 at
  FP-16/12/8; PC = pri<<16 | supervisor | interrupted.
- `ret` type 7 restores PC/AC; a still-pending lower line is then taken at the
  next boundary (equivalent to MAME's `check_pending_irqs`).
- Simplification: MAME parks not-yet-eligible IRQs in the in-memory pending
  table (int_tab+0..) and re-reads it later; jt960 keeps pending state in the
  4 line latches instead and never touches that memory. Observably equivalent
  for FL (nothing reads the table), documented here in case a game does.

## ISA coverage

Implemented (everything MAME implements for the KA, plus atadd/atmod/modify/
extract/syncf which MAME lacks):

| group | instructions |
|-------|--------------|
| CTRL  | b, call, ret, bal, bno..bo, faultno (branches, MAME quirk) |
| COBR  | testno..testo, bbc, bbs, cmpobg..cmpoble, cmpibg..cmpible |
| logic | and, andnot, notand, xor, or, nor, xnor, not, ornot, notor, nand |
| bit   | notbit, setbit, clrbit, alterbit, chkbit, scanbyte, scanbit, spanbit |
| arith | addo, addi, subo, subi, addc, subc, cmpo/i, concmpo/i, cmpinco/i, cmpdeco/i |
| shift | shlo, shli, shro, shri, shrdi, rotate |
| field | modify, extract |
| mul/div | mulo, muli, emul, divo, remo, divi, remi, modi, ediv (sequential, 32/64 cyc) |
| move  | mov, movl, movt, movq, dmovt |
| mem   | ld/ldob/ldib/ldos/ldis/ldl/ldt/ldq, st/stob/stib/stos/stis/stl/stt/stq, lda |
| flow  | bx, balx, callx, calls (local entries), flushreg, syncf (nop) |
| sys   | modac, modpc, synmov (+ICR), synmovq (+IAC 93 reinit / 80 store SAT+PRCB), atadd, atmod |

Halts (asserts `halted`, `st==HALT`) — all paths MAME `fatalerror`s on too:

- Every KB floating-point opcode (67.4-7, 68.x, 69.x, 6c.x, 6d.x, 6e.x, 78.x,
  79.x) — the KA has no FPU; namcofl never executes them in MAME.
- faultg..faulto taken, ret types 1-6, calls to supervisor entries,
  MEMB modes 0-3/6/8-b, literal destinations, undecoded opcodes.

## Known simplifications

1. Instruction cache: parameter `ICACHE_BLK` (256B blocks, power of 2 up to
   64; default 64 = 16kB, 16 M10K; the KA has 512B). System FL runs its game
   code from work RAM (~12kB touched per race frame, MAME trace), so the
   larger cache stands in for the SDRAM latency the real board never sees.
   Direct-mapped 16B lines, word fills on miss, hits take one clk after IP
   changes (registered RAM read), single-word instructions execute in the
   hit cycle. Any bus write clears the line it indexes; IAC 0x89/0x93 clear
   all. No prefetch queue and no data cache (the KA has none).
2. Timing is not cycle-accurate: simple ops take 1 cen on an icache hit,
   mul 18 (MAME 18), div 66 (MAME 37), cached call/ret 2 each, mov/movl/movt/
   movq 1.
3. IRQ pending state in latches, not in the in-memory pending table (above).
4. addi/subi/shli/muli/divi etc. do not raise integer-overflow faults (MAME
   also ignores them).
5. atadd/atmod are not bus-locked (single master in FL).
6. `movre`/extended-real registers omitted (KB only).

## Verification

`cores/sysfl/ver/i960/jt960_tb.v` (`go.sh` runs iverilog in the docker
image): hand-assembled program covering reset IMI fetch, ALU ops, MEMA/MEMB
addressing (32-bit displacement), byte/word/quad load/store, signed loads,
cmpob branches, call/ret, recursion depth 7 forcing frame spill+fill through
memory, mulo/divo, modpc priority drop, synmov to ICR and an external IRQ0
taken through the interrupt table (call type 7, handler, ret type 7). Random
bus wait states exercise the cen/bus_ok stretch. Result: PASS.

Lint: `verilator --lint-only` clean (see go.sh command with `--top-module
jt960`; add `modules/jtframe/hdl/jtframe_edge.v` to the file list).

## TODO (next passes)

1. Integration: DONE in jtsysfl_main.v (sysreg, IRQ clears, bank swap,
   full namcofl decode, 32->16 bus funnel, 20 MHz cen from mem.yaml).
   speedrcr POST passes in RTL simulation; see cores/sysfl/ver/speedrcr/boot.sh
2. Trace-driven verification against MAME (instruction-level compare on the
   speedrcr boot sequence).
3. Divider at 2 bits/cycle (64 -> 32 cen) if MDWAIT shows up again in the
   per-frame counters (`SYSFL_VSTAT` CPUDET line, 1.7k mul/div per race frame).
4. Timing pass: real KA cycle counts where the C75 sync window cares.
5. Integer-overflow faults + a minimal fault-call path (type per PRCB) if the
   game turns out to use them (MAME says it does not).
6. eshro and other CA-era ops only if ever hit (halted flag will tell).
