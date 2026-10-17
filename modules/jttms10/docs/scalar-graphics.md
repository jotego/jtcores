# Scalar graphics instructions

The 1988 TI *TMS34010 User's Guide* gives the CPW encoding and behavior on
printed pages 12-57–12-58 and CVXYL on pages 12-59–12-60. The programs in
`ver/tests.yaml` use bit addresses and 16-bit instruction words.

| Instruction | Opcode word | Operands | Status |
| --- | --- | --- | --- |
| CPW Rs,Rd | `E600 | (Rs << 5) | (R << 4) | Rd` | Same-file Rs/Rd; B5=WSTART and B6=WEND are implied | V is 1 outside the window; N/C/Z unchanged |
| CVXYL Rs,Rd | `E800 | (Rs << 5) | (R << 4) | Rd` | Same-file Rs/Rd; B4=OFFSET, I/O CONVDP and PSIZE are implied | N/C/Z/V unchanged |

`R=0` selects file A and `R=1` file B. Register 15 is the shared SP in either
file. A source/destination alias must use the original source value; writing
B4 as CVXYL's destination must use its original OFFSET value.

CPW treats both halves of the point and the window corners as signed 16-bit
coordinates. WSTART and WEND are inclusive. Their coordinates must be
positive; TI calls negative window coordinates unpredictable. The destination
contains only the four result bits: bit 5 means `point.X < WSTART.X`, bit 6
means `point.X > WEND.X`, bit 7 means `point.Y < WSTART.Y`, and bit 8 means
`point.Y > WEND.Y`. For WSTART=(5,5), WEND=(10,10), the guide's points (4,4),
(5,5), (10,10), and (11,11) produce `0xA0`, zero, zero, and `0x140`.

CVXYL reads a positive signed X from Rs[15:0] and a signed Y from Rs[31:16].
It computes `((Y << (31 - CONVDP[4:0])) | (X << log2(PSIZE))) + B4`, modulo
32 bits. PSIZE is a valid power of two from 1 to 16; CONVDP values `0x13`,
`0x14`, and `0x15` correspond to pitches of 4096, 2048, and 1024 bits. The
guide's `(X,Y)=(0x30,0x40)`, PSIZE=16, CONVDP=0x14, OFFSET=0 example yields
`0x00020300`. Signed negative Y and nonzero OFFSET exercise the sign-extension
and final addition; an X value outside the documented positive range is not
used as an expected-result test.
