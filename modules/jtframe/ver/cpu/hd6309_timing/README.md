# HD6309 instruction timing

This simunit checks cycle counts, register results, and selected memory bus
sequences for HD6309 instructions in emulation and native modes. Its timing
oracle is Darren Atkinson's *Motorola 6809 and Hitachi 6309 Programmer's
Reference*. It covers INCE, ADDR, INCD, DECW, TFR, EXG, LDE/LDF immediate,
direct and indexed addressing, STE/STF extended stores, LDW immediate and
STW direct/extended, AIM/OIM/EIM/TIM direct/indexed/extended addressing,
LDA indexed E,X, F,X, W,X, `,W`, and extended-indirect forms, SEXW,
PSHSW/PULSW/PSHUW/PULUW, inherited LDA direct/extended/indexed timing, and
ABX. Direct page-10/page-11 anchors include ADDW, SUBW, EORD, CMPU, CMPS,
CMPU immediate, and LDQ. Interrupt tests cover native FIRQ short/full frames,
IRQ/RTI, SWI/SWI2/SWI3, and CWAI/IRQ/RTI. Emulation-mode timing gates cover
SWI/SWI2/SWI3 at 19/20/20 E cycles, CWAI at 22 E cycles, full/short RTI at
15/6 E cycles, and SYNC's documented minimum of four E cycles; native CWAI
is 20 E cycles and native SYNC's minimum is three. Native timing gates cover
SWI/SWI2/SWI3 at 21/22/22 E cycles and full-frame RTI at 17 E cycles. Interrupt
tests also check frame length, byte order, vector reads, stacked CC.E, saved
PC, E/F, and restored registers. Page-11 bit operations check
all eight direct forms in both modes; the emulation-mode matrix covers all
three register selectors, source/destination bit positions, and both memory
bit values. TFM
checks all four address update forms, W=0/1/2, X/Y/D/U/S selectors, cycles
`6+3n`, pointer updates, W depletion, and transferred bytes. For same-register
`TFM X+,X+`, the test asserts that two transfers read `$40` and `$42`, write the
source bytes at `$41` and `$43`, and advance X to `$44`. This follows the original-device
bus capture in [Hoglet's 6809Decoder HD6309 behavior notes](https://github.com/hoglet67/6809Decoder/wiki/Undocumented-6309-Behaviours#tfm).
The decrementing same-register case remains a functional check without a
strict write-address oracle. Normal TFM completion sets CC.Z; interrupted
transfers and invalid TFM selectors clear it before stacking. The tracked [coverage manifest](coverage.md) maps
each opcode, addressing form, and mode to the timing source and current
validation status.
The exception checks use the production `GHOST` illegal-opcode policy and
assert the HD illegal/divide-by-zero MD bits and actual `$FFF0/$FFF1` vector
bus reads. They include a page-11 illegal opcode, an invalid TFM selector, and
DIVD/DIVQ divide-by-zero. Immediate and memory forms assert the saved CC,
preserved dividend, MD.DZ, and original-device stack/vector/handler phases.
Reserved illegal and divide-zero traps preserve the prior I/F mask bits in the
stacked CC and live handler CC, as observed by the original-device decoder.
A TFM interrupt restart check verifies that the interrupted transfer resumes
after RTI without an early destination write and sets Z on completion.
Immediate DIVD/DIVQ divide-by-zero checks now cover both MD modes. They assert
the 6809Decoder schedule from opcode fetch: handler at 23/24 E in emulation
and 25/26 E in native, first stack write at 7/8 E, and reserved-vector high
read at 20/21 E in emulation or 22/23 E in native. The schedule comes from
the original-device bus samples modeled by
[6809Decoder's `interrupt_helper`](https://github.com/hoglet67/6809Decoder/blob/master/src/em_6809.c).
Memory DIVD/DIVQ zero traps are checked for direct, extended, and indexed `,X`
forms in both modes, including the final divisor-byte read. Their handler
totals are DIVD 25/26, 26/27, and 25/27 E (emulation/native) for direct,
extended, and indexed forms; DIVQ totals are 26/27, 27/28, and 26/28 E.
Saved CC is `$85` for DIVD and `$8D` for DIVQ, with D/W preserved.
MULD, DIVD and DIVQ have integrated CPU checks for immediate and direct,
indexed and extended addressing in both MD modes, with published cycle counts,
signed results, and hard-overflow dividend-magnitude results. MULD also checks
V and C preservation. DIVD and DIVQ check signed minimum/just-outside
quotient bounds, including truncated results and N/Z/V/C behavior.
The signed timing matrix covers all four dividend/divisor sign pairs for
DIVD and DIVQ (+1 E per negative operand) and MULD (+2 E if either operand is
negative), across all four addressing forms and both MD modes: 96 cases total.
Negative-dividend divide-by-zero cases assert that the physical-device
zero-divisor path receives no sign correction. These operand-dependent timing
rules follow the original-device measurements in
[Hoglet's 6809Decoder behavior notes](https://github.com/hoglet67/6809Decoder/wiki/Undocumented-6309-Behaviours#divd).
Additional divider boundary cases cover |DIVD quotient|=127/128/255/256 and
|DIVQ quotient|=32767/32768/65535/65536 for positive and negative dividends,
in immediate/direct/indexed/extended forms and both MD modes. They assert that
soft overflow returns the quotient magnitude, uses the physical-device N/V/C
rules, and applies the documented timing correction; hard overflow returns
the absolute dividend magnitude and derives N from the original dividend.
Hard overflow cases above the exact boundaries also test nonzero remainders.
MULD checks preserve both V and C while updating N/Z. The original-device
decoder and Atkinson's individual MULD entry preserve C; Atkinson's consolidated
table says C=0, so the individual entry and physical-device result are used.

Memory-immediate operations use the published 6/7/7 E-cycle counts for
direct/indexed/extended forms in both modes. AIM/OIM/EIM verify the resulting
memory byte; TIM verifies that it leaves memory unchanged. LDA using E,X, F,X,
or W,X adds the documented one indexed-postbyte cycle to the indexed base;
`,W` adds none. Each variant checks the fetched value as well as its cycle
interval. Indexed postbyte increments and sources are listed in
[coverage.md](coverage.md).

The inherited-opcode matrix compares emulation and native counts for NOP, DAA,
MUL, NEGA, PSHS and RTS, plus ADDD immediate/direct/indexed/extended and LDA
with 16-bit and D-register indexed offsets. The W-indexed cases cover `n,W`,
`[n,W]`, `,W++`, `[,W++]`, `,--W`, and `[,--W]` in both modes, checking distinct
effective data and W updates against the indexed-postbyte table.

The original Hitachi HD63C09E data sheet scan in
`tasks/jtcores-142/artifacts/hd63c09e-datasheet.pdf` provides an independent
base-opcode cross-check (printed pages 301–306, PDF pages 25–30). The scan
does not give separate native-mode counts or the 6309-only extensions, so the
Atkinson timing pairs are the oracle for those cases. In particular, indexed
entries with `+` use the indexed postbyte increment: `,X` adds zero cycles.

Each case selects mode with `LDMD`, initializes E/F/S, then measures from the
target opcode fetch through the next opcode fetch. E edges are sampled on
rising `clk` edges when `cen_E` is high. The opening fetch edge is excluded
and the closing fetch edge is included. The test checks architectural state
and `MD` through `RegData6309`; PSHSW/PULSW also check write/read address order
and stored bytes. PSHU uses a one-byte CC mask so Atkinson note 4's one-cycle-
per-selected-byte adjustment is explicit. CWAI and SYNC are measured from the
opcode fetch to wait-state entry; their minimum counts exclude later interrupt
wait time. SWI-family timing ends at the vector-handler fetch, while RTI timing
ends at the restored-PC fetch. The global watchdog allows the complete set of
independently reset test programs to run before reporting a timeout.

Run from the repository root:

```sh
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/hd6309_timing
```

## Opcode and indexed timing sweep

The separate `sweep/` harness generates generic legal instruction vectors in
both MD modes. It checks 70 opcode/mode relative-branch rows, expanded to 140
taken/not-taken scenarios (72 taken and 68 not-taken), the eight
register-postbyte arithmetic opcodes with the E,F selector, and the full
cross-product of 85 fixed-count indexed opcode rows and all 38 documented
indexed postbytes. DIVD and DIVQ indexed rows are excluded because their counts
depend on operands and overflow conditions; directed tests cover their
documented cases. The sweep also checks scalar straight-line forms. Run it from
the repository root with:

```sh
modules/jtframe/ver/cpu/hd6309_timing/sweep/run.sh
```

Pass `--keep /tmp/hd6309-sweep` to preserve generated vectors, exclusions, and
measured CSV output for audit. A successful generation creates 7,162 vectors
and records 92 unsupported or specialized cases separately. Each run updates
the `Sweep E` and `Sweep N` cells in [coverage.md](coverage.md): `P` means the
measured cycle count and checked control-flow endpoint matched the Atkinson
oracle, `X` means a timing, dispatch, or flow check failed, and `U` means the
timing oracle is unresolved. The generic sweep does not check architectural
results or bus transactions; the directed simunit covers those behaviors.
