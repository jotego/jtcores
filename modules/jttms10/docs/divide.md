# Shared-adder divide and modulus

The primary instruction references are TI's 1988 *TMS34010 User's Guide*,
printed pages 12-63–64 (DIVS), 12-65–66 (DIVU), 12-113 (MODS), and 12-114
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
exceptional cases belong to the durable YAML programs.

## Instruction timing probes (#144)

The independent timing suite adds 902 DIV/MOD programs covering both cache
modes, DIV destination parities, zero divisors, early paired overflow,
late signed-range overflow, quotient/remainder boundaries and source aliases
to either destination half. It also runs 24 literal TI examples in each
cache mode, with full ST and A0–A3 checks. The count oracle uses mathematical
operands rather than the RTL's restoring-loop state. FS/FE vary because they
must not change division operand width or duration.

| Rule | Warm hit states | Cache disabled states | TI printed page |
|---|---:|---:|---|
| DIVS normal, odd Rd | 39 | 42 | 12-63 |
| DIVS normal, even Rd | 40 | 43 | 12-63 |
| DIVS quotient candidate magnitude `80000000`, either parity | 41 | 44 | 12-63 |
| DIVS zero divisor or early paired overflow | 7 | 10 | 12-63 |
| DIVU normal, either parity | 37 | 40 | 12-65 |
| DIVU zero divisor or early paired overflow | 5 | 8 | 12-65 |
| MODS normal | 40 | 43 | 12-113 |
| MODS quotient candidate magnitude `80000000` | 41 | 44 | 12-113; interpretation below |
| MODU normal | 35 | 38 | 12-114 |
| MODS/MODU zero divisor | 3 | 6 | 12-113/114 |

TI's DIVS table explicitly gives **41 states for both parities**, verified
against the scanned table. The pinned old core's normal count plus one
would give 40 for odd Rd; the new oracle and mutation regression follow
the primary table's 41. A signed quotient that fits in 32 magnitude bits
but exceeds signed range takes the normal/special full path, rather than
the early paired-overflow path.

Two wording interpretations are recorded explicitly. MOD Z uses the stored
remainder, following the literal examples above. MODS's extra-state condition
says “result = 80000000”; a signed remainder cannot reach that magnitude
because its absolute value is strictly less than the divisor's, whose
maximum magnitude is `80000000`. The timing suite interprets that condition
as the division quotient candidate magnitude, testing both minimum/+1 and
minimum/-1. Those fixtures include this note in their reports; this is an
explicit interpretation, not an omission of the special condition.

The schedule begins with the normal budget. Its operand check removes the
states omitted by an early exit. At the end of division, the signed minimum
candidate adds two states for odd DIVS and one for even DIVS/MODS. The
arithmetic loop and its state/flag rules remain shared with the existing ALU.
The suite independently checks next-read start and ACK duration, and adds
an early CEN pause plus a directed pause during a normal division loop.
These probes do not establish arbitrary bus phases, file-B/shared-SP timing,
interrupt/HOLD acceptance or full ISA timing signoff; see [timing.md](timing.md).
