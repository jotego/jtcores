# Bounded shifts and rotates

Primary source: TI *TMS34010 User's Guide* (1988), printed pages 12-234–235
(RL), 12-239–240 (SLA), 12-241–242 (SLL), 12-243–244 (SRA), and
12-245–246 (SRL). The K opcode bases are `2000`, `2400`, `2800`, `2C00`,
and `3000`; register-count bases are `6000`, `6200`, `6400`, `6600`, and
`6800`. Both forms include the A/B-file selector and a destination register.

The current #149 implementation uses a shared bounded two-stage shift path,
not the earlier one-bit-per-iteration loop. [`jttms10.v`](../hdl/jttms10.v)
computes the low 0–7-bit stage and the upper multiple-of-eight stage; the
control ROM enables those stages on separate microsteps. LMO uses a shared
leading-zero network. [`control.yaml`](../ucode/control.yaml) schedules
SLL/SRA/SRL/RL and LMO in four YAML words (8 INCLK). SLA uses twelve words
(24 INCLK), including eight explicit empty
words to match its three-state timing. The RTL contains no instruction timer;
the instruction sequence and delay remain in YAML.

K counts are direct for left shifts and rotate. For SRA/SRL the raw five-bit
count is the two's complement of the desired shift amount, so raw 31 shifts
right once and raw 1 shifts right 31 times. Raw zero means zero. The
register-count form uses the low five source bits and captures them before a
destination write, including when Rs and Rd alias.

| Family | Updated flags | Other flags |
| --- | --- | --- |
| SLA | N, C, Z, V | — |
| SRA | N, C, Z | Preserve V |
| SLL, SRL, RL | C, Z | Preserve N and V |

C is the last bit shifted out, or zero for a zero count. Z reflects the final
32-bit result even for a zero count. SLA overflow accumulates every sign-bit
transition, so a later transition back does not clear V. SLA zero count clears
V. SRA replicates the sign; logical shifts insert zero; RL feeds the high bit
back into the low bit without involving incoming C.

YAML cases cover both encodings of each family, counts 0/1/31, source values
32/33, complemented right counts, signed/logical behavior, flag preservation,
SLA overflow after two sign transitions, and the shared SP through B15. The
independent short timing fixture checks 18 TI-derived shift/LMO cases, including
aliases, SLA's printed example, and LMO top/bottom/zero. Those directed cases
pass with eight-INCLK intervals except SLA at 24 INCLK. This is example
coverage, not full flag/alias or instruction-family timing signoff; see the
[restart status](timing-restart.md).

The loaded FPGA image subsequently passed 1,853 selected positive shift/LMO
cases in each of BASE, W1P7 and W3. Across the scalar and shift/LMO inventories
there are 15 unique coverage IDs and 10 mnemonics; NOP is listed in both, so
each profile executed 2,510 cases with 2,509 distinct case names. This board
matrix is a separate result from the limited exact-Verilator comparison and
does not qualify every condition or the complete shift-family timing matrix.

The original one-bit loop avoided a combinational barrel shifter but required
a ROM-prime and execution phase per bit. It is historical #141 implementation
context and does not describe the current source. The current bounded path has
a measured complete-NARC mean of 3,128 ALMs and 53.2275 MHz across four fits;
the wider CPU condition matrix and final acceptance gates remain open.
