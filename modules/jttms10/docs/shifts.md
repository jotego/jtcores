# DSP shifts and rotates

Primary source: TI *TMS34010 User's Guide* (1988), printed pages 12-234–235
(RL), 12-239–240 (SLA), 12-241–242 (SLL), 12-243–244 (SRA), and
12-245–246 (SRL). The K opcode bases are `2000`, `2400`, `2800`, `2C00`,
and `3000`; register-count bases are `6000`, `6200`, `6400`, `6600`, and
`6800`. Both forms include the A/B-file selector and a destination register.

All ten forms share the multiplier used by MPYS/MPYU. The first YAML word
captures Rd in `a` and a one-hot count operand in `tmp`; the second writes
the selected product bits and flags. The register-count form captures the
low five source bits before any destination write, including when Rs and Rd
alias. Left shift and rotate counts are direct. For SRA/SRL,
the raw five-bit value is the two's complement of the desired count, so raw
31 shifts right once and raw 1 shifts right 31 times. Raw zero means zero.

The unsigned 64-bit product's low half supplies a left shift, its high half
supplies a right shift, and ORing both halves supplies rotate-left. Right
encodings already contain `32-count`, so the same one-hot decoder serves
both directions. SRA fills sign bits using the one-hot operand minus one.
Zero count bypasses the product. No second multiplier or general variable
barrel shifter is introduced.

| Family | Updated flags | Other flags |
| --- | --- | --- |
| SLA | N, C, Z, V | — |
| SRA | N, C, Z | Preserve V |
| SLL, SRL, RL | C, Z | Preserve N and V |

C is the last bit shifted out, or zero for a zero count. Z reflects the final
32-bit result even for a zero count. SLA overflow accumulates every sign-bit
transition, so a later transition back does not clear V. SLA zero count clears
V. SRA replicates the sign; logical shifts insert zero; RL feeds the high bit
back into the low bit without involving the incoming C.

YAML cases cover both encodings of each family, counts 0/1/31, source values
32/33, complemented right counts, signed/logical behavior, flag preservation,
SLA overflow after two sign transitions, and the shared SP through B15. These
architectural assertions pass on both CPUs.

SLA overflow checks whether the exact signed product fits in 32 bits; this
detects a sign transition even when the final sign returns to its old value.
The instruction scheduler enforces the constant published latency: SLA is
3/6 machine states (cache hit/off), while the other four families are 1/4.
This applies to all 32 counts, including zero.

The permanent [timing suite](timing.md) has 850 shift/rotate programs across
both encodings and cache modes: all counts, zero/minimum/positive/mixed
operands, ignored high count bits, aliases and flag preservation. Forty
programs use TI's ten literal SLA examples (p.12-239) as direct result/NCZV
goldens; the mathematical model is independently checked against them.
The standard runner also tests external waits and early CEN pauses.
The matched synthesis map still uses three DSP blocks for the complete CPU;
fitted area and FPGA timing closure remain acceptance work.
