# Immediate instruction timing (#144)

The independent oracle follows the June 1988 TMS34010 User's Guide
SPVU001A. Page numbers below are printed pages in the
[primary guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
The two counts mean cache hit/cache disabled (§13.1 p.13-2).

| Forms | Operand width | States, hit/CD | Primary pages |
|---|---:|---:|---|
| ADDI, CMPI, SUBI, MOVI | 16 | 2/8 | 12-38, 12-54, 12-249, 12-159 |
| ADDI, CMPI, SUBI, MOVI | 32 | 3/12 | 12-39, 12-55, 12-250, 12-160 |
| ANDI, ANDNI, ORI, XORI | 32 | 3/12 | 12-43, 12-45, 12-173, 12-256 |

Each extension word is one intrinsic state; with CD, every instruction
word adds three external-fetch states (§5.4.7 p.5-24). Wait states are
additional for **each** external transfer. In the decode-to-decode interval,
the initial opcode acquisition is represented by the following opcode's
acquisition, while the current instruction's one/two extension reads remain
inside the interval. A 32-bit CD instruction therefore has three measured
reads and gains three states when each target adds one wait state.

TI p.11-24 explicitly distinguishes IAQ: all four words of a cache fill
have IAQ high, including immediates/data. With CD, only opcode reads have
IAQ high; extension reads have it low. The oracle checks the encoded low/high
words in order, followed by the next opcode, and independently checks logical
cycle duration and raw target dispatch/ready clocks. For these general
immediates the logical allocation contract assigns one intrinsic state per
word and the stated three CD penalty states per word: CD reads begin at
+8/+40 INCLK for short forms and +8/+40/+72 for long forms, before waits.
These are logical pipeline allocations; original internal microinstruction
or electrical pin edges are not exposed by this implementation.

The 16-bit operand is sign extended. SUBI/CMPI store the one's complement
of the source-level operand; the mathematical oracle receives the original
operand. ANDI/ANDNI share an opcode: hardware computes `Rd & ~encoded_IL`,
and the source-level ANDI alias stores the complemented IL. Their fixtures
have distinct coverage identifiers despite that shared encoding. MOVI clears
V and preserves C; logical operations change only Z; CMPI preserves Rd.
All probes compare full ST and A0..A3, including preserved operands.

`ver/timing/immediate_cases.py` supplies 2,828 programs: 2,736 mathematical
boundary/literal fixtures, 72 additional warm word-alignment fixtures and
20 first/second-extension cache misses. The arithmetic matrix varies
zero/signed endpoints, carry/overflow/borrow, dense/mixed immediate halves,
initial flags/IE and ignored field parameters, targeting A0/A1/A2. Twenty-four
selected TI examples independently anchor the result/flag model. Warm
fixtures cover all four instruction-word offsets. Cold fixtures place the
opcode or first extension at the resident subsegment's end; the following
extension forces four reads with IAQ high. The expected penalty is nine
states, in addition to the 2/3 intrinsic states: 88/96 INCLK before waits.

The scheduler applies the 2/3 intrinsic budgets to cached instructions.
Externally returned extensions finish their processing state before the
next microinstruction. SUBI/CMPI complement decoding is folded into operand
capture, sharing the existing ALU and avoiding a separate inversion step.
After an extension cache fill, the scheduler preserves the remaining one/two
intrinsic word states before final architectural writeback and next-opcode
fetch. The cache response rebases that remaining work budget after the fill. The existing independent bus-event checks
remain active alongside total duration.

The historical [baseline](../ver/timing/baseline-immediate-1c10d69.json)
records unchanged `1c10d698f` with the original fixed-layout 2,736 fixtures:
2,341 timing failures, zero architectural failures. Cached short ADDI took
13 rather than 16 INCLK; cached long ADDI took 18 rather than 24; long CD
forms took 88 rather than 96. Short CD forms happened to match 64. The file
retains 24 form/cache representatives and verified source hashes; it is
never read by the oracle or used as an expected-failure allowlist.

Four additional actual RTL mutations must be rejected with correct final
registers/ST: a short-form budget of one state, missing extension processing,
lost intrinsic work after an extension miss, and IAQ high on CD extension
reads. Checker/model tests separately reject missing per-word wait costs,
reversed data halves and early bus allocation even with a correct total.

```sh
python3 modules/jttms10/ver/timing/run.py --case immediate --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case immediate --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case extension_miss --traces immediate-traces
```

These tests do not prove timed register-file B/shared SP behavior, interrupts
between extension fetches, ACK during a CPU-enable pause, contention, cache
replacement/prefetch or the remaining ISA and graphics contracts. Those and
final fitted area/STA/NARC checks remain required for #144. The complete
coverage gate intentionally remains failing for untested forms.
