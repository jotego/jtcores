# Iterative shifts and rotates

Primary source: TI *TMS34010 User's Guide* (1988), printed pages 12-234–235
(RL), 12-239–240 (SLA), 12-241–242 (SLL), 12-243–244 (SRA), and
12-245–246 (SRL). The K opcode bases are `2000`, `2400`, `2800`, `2C00`,
and `3000`; register-count bases are `6000`, `6200`, `6400`, `6600`, and
`6800`. Both forms include the A/B-file selector and a destination register.

All ten forms share the same one-bit ALU microcode helper. A five-bit
counter controls repetition; zero count skips the helper. The register-count
form captures the low five source bits before any destination write, including
when Rs and Rd alias. Left shift and rotate counts are direct. For SRA/SRL,
the raw five-bit value is the two's complement of the desired count, so raw
31 shifts right once and raw 1 shifts right 31 times. Raw zero means zero.

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

The one-bit loop avoids a combinational barrel shifter but uses a ROM-prime
and execution phase for each bit. It does not match TI's one-state timing for
most shifts or three-state SLA timing. Timing and integrated workload
performance remain acceptance work; architectural agreement alone does not
establish either.
