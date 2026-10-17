# Decrement branches and packed XY operations

Primary source: TI's 1988 *TMS34010 User's Guide*. The instructions below
use existing shared-ALU and synchronous-register-RAM paths.

DSJ, DSJEQ, and DSJNE (`0D80`, `0DA0`, `0DC0` plus file/register) fetch a
signed 16-bit word displacement. DSJ always decrements Rd; DSJEQ does so
only when original Z is set, and DSJNE only when original Z is clear. The
extension is consumed even when the gate is false. An enabled decrement
branches only when its result is nonzero, relative to PC after the extension.
DSJS uses opcode `3800` plus direction, five-bit offset, file, and register;
its unsigned offset 0..31 is added or subtracted from the next PC in word
units. All forms preserve the entire status register. Zero Rd wraps to
`FFFFFFFF` on an enabled decrement.

MOVX/MOVY (`EC00`/`EE00` plus register fields) copy the selected low/high
16-bit half of Rs into Rd and preserve the other half and all ST bits. They
work with aliases, both files, and the shared SP.

ADDXY, SUBXY, and CMPXY (`E000`, `E200`, `E400` plus register fields) operate
on X=low16 and Y=high16 independently. Two microsteps feed those halves into
the existing ALU; X carry or borrow never enters Y. ADDXY/SUBXY assemble the
two results in MD before one destination write; CMPXY writes no register.

| Instruction | N | V | Z | C |
| --- | --- | --- | --- | --- |
| ADDXY | X sum is zero | X sum sign | Y sum is zero | Y sum sign |
| SUBXY | X operands equal | signed Rs.X > Rd.X | Y operands equal | signed Rs.Y > Rd.Y |
| CMPXY | X difference is zero | X difference sign | Y difference is zero | Y difference sign |

CMPXY uses the wrapped 16-bit difference signs. SUBXY uses signed coordinate
comparisons, which differ at overflow boundaries. Tests explicitly distinguish
these rules with `8000` destination halves and `7FFF` source halves.
All status bits outside N/C/Z/V are preserved.

Six YAML programs cover both register files, aliases/SP, untouched halves,
independent half carries, signed-coordinate boundaries, nondestructive
comparison, long branch directions, original-Z gating, consumed extensions,
counter wrap, and short offsets 0/1/31. They pass both CPUs. The relevant
printed pages are ADDXY 12-41, CMPXY 12-56, MOVX/MOVY 12-162–163,
SUBXY 12-252, and the DSJ family 12-70–75. Timing remains unverified.
