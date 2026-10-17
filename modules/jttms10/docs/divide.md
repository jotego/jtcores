# Shared-adder divide and modulus

The primary instruction references are TI's 1988 *TMS34010 User's Guide*,
printed pages 12-63–66 (DIVS), 12-69 (DIVU), 12-113 (MODS), and 12-114
(MODU). Opcode bases are `5800`, `5A00`, `6C00`, and `6E00`, respectively,
plus source/file/destination fields. FS/FE do not select operand width.

DIV with an even destination reads the 64-bit dividend from Rd:Rd+1, then
writes the quotient to Rd and remainder to Rd+1. An odd destination divides
its 32-bit value and keeps only the quotient. MOD always uses a 32-bit
dividend and stores the remainder in Rd. Signed division truncates toward
zero and gives the remainder the dividend's sign. Both source and dividend
are captured before any result write, including divisor aliases and the
B14/shared-SP pair.

The microcode normalizes signed magnitudes through the shared ALU, then
calls one restoring-division helper for 32 steps. A 32-bit subtraction and
its borrow choose the next remainder and quotient bit. The existing a/b/md
registers hold divisor, remainder, and quotient; the multiply counter is
reused. Signed results are negated afterward through that same ALU. There
is no HDL division/remainder operator or separate wide arithmetic block.

| Family | Updated flags | Preserved flags |
| --- | --- | --- |
| DIVS | N, Z, V | C |
| DIVU | Z, V | N, C |
| MODS/MODU | Z, V | N, C |

Zero divisor or an unsigned magnitude quotient exceeding 32 bits takes an
early overflow path. DIV preserves its destination register(s), sets V,
clears Z, and DIVS clears N. A later signed-range overflow also preserves
DIV's destinations; DIVS follows TI's N rule for a negative quotient or the
`80000000` magnitude case. Normal Z comes from the quotient.

MOD with a zero divisor preserves the destination and old Z while setting
V. Otherwise Z comes from the stored remainder. The guide's MOD flag prose
says "quotient", but its worked examples explicitly set Z for `8 mod 4 = 0`
and clear it for `7 mod 4 = 3`. The tests use those examples and the stored
remainder. MODS still stores a valid remainder on signed quotient overflow:
`80000000 mod FFFFFFFF` stores zero, sets Z/V, and preserves N/C.

Six durable programs cover both DIV widths, signs, remainders, zero quotient,
zero divisor, early/signed-range overflow, minimum integers, flag masks,
divisor aliases, and a B14/SP pair. All match the pinned old CPU.
An independent Python model uses integer magnitude division and explicit
truncation toward zero, rather than Python's signed floor division. It runs
240 normal divisions per seed through twelve temporary architectural programs:

```sh
bash modules/jttms10/ver/build.sh
python3 modules/jttms10/ver/divide/check.py
python3 modules/jttms10/ver/divide/check.py --seed 0x141d17e
```

The seeded runs cover signed/unsigned even and odd DIV plus both MOD forms;
exceptional cases belong to the durable YAML programs. These checks do not
establish silicon instruction timing, which still requires validation.
