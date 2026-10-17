# LINE instruction contract

Primary source: *TMS34010 User's Guide*, printed pp. 12-99–104 (LINE),
pp. 7-12–16 (plane mask and pixel processing), and pp. 7-25–28 (window
checking). The encoded instruction is `DF1A` for LINE 0 and `DF9A` for LINE 1;
bit 7 selects the tie rule.

LINE draws `B10` pixels, starting at XY pointer `B2`. Register `B0` holds the
signed 32-bit decision value `d`; `B7` holds minor dimension `b` in its high
half and major dimension `a` in its low half. Each iteration decrements `B10`,
processes the current pixel, then advances the decision and XY pointer:

| Mode | Diagonal condition | Diagonal update | Otherwise |
| --- | --- | --- | --- |
| LINE 0 | `d > 0` | `d += 2b − 2a`, `B2 += B11` | `d += 2b`, `B2 += B12` |
| LINE 1 | `d >= 0` | `d += 2b − 2a`, `B2 += B11` | `d += 2b`, `B2 += B12` |

The X and Y halves of `B2` wrap independently. Software normally initializes
`d = 2b − a`, `B10 = a + 1`, and `B13 = FFFFFFFF`. The guide marks `B13` and
`B14` as changed but does not specify final values; tests initialize them and
do not assert their post-values. `B0`, `B2`, and `B10` write back their final
decision, next pixel address, and remaining count. `COUNT=0` draws nothing.

For window mode W=0, every pixel is processed and V is unaffected. W=1
calculates without drawing and aborts at the first inside pixel, setting WVP
and clearing V; if no pixel is inside, it completes with V set and WVP clear.
W=2 draws inside pixels and aborts at the first outside pixel, setting V and
WVP; an entirely inside line completes with V clear. W=3 traverses the whole
line, draws only inside pixels, and leaves V equal to whether the last pixel
was outside. COLOR1 is a register source and bypasses source plane masking;
the destination is masked before PPOP, and the result is masked before
transparency detection. N, C, and Z are undefined after LINE.

An interrupt may be recognized after each nonfinal pixel. For a continuing
LINE, the pushed PC points back to the LINE opcode (next PC minus 16), and PBX
is clear; RETI executes LINE again using the published B-file context. A LINE
aborted by W=1 or W=2 does not rewind its PC. The interrupted routine must
restore any B-file registers it changes before RETI.

`ver/line/programs.py` computes expected pixels and B-file writebacks in
Python without importing the HDL helpers. Its generated corpus covers COUNT
zero, both `d=0` tie outcomes, all eight signed direction octants, W=1/2/3,
and PPOP/PMASK/transparency. Run it through `ver/run.py --vectors` and
`ver/reference.py --vectors`; the pinned reference is the untouched
`modules/tms34010` core at `29bcb384ec3d`.

`ver/line/interrupt.sv` compares uninterrupted and IRQ-resumed destination
streams with delayed acknowledgements and nested ISR FILL under
MMTM/MMFM B0–B14. It checks the published decision/pointer/count, stacked
opcode PC and PBX=0, then one opcode refetch and exact final memory. A
separate first-pixel checkpoint starts COUNT at `00010001` and requires
`00010000` at IRQ entry, protecting full 32-bit count storage without a
65,537-pixel simulation.
