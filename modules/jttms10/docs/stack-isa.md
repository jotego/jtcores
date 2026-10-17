# Stack, control, and unary ISA notes

Primary source: TI, *TMS34010 User's Guide* (1988, SPVU001A), printed chapter
12 pages below. The existing CPU remains an unchanged architectural comparison
at `29bcb384ec3dba892ea54db2ee92b38ae395d575`; its instruction timing is not
used as proof for the new microcode.

| Instructions | Encoding | TI pages | Implemented behavior |
| --- | --- | --- | --- |
| CALL Rs | `0920` + R/Rs | 12-48 | Capture original register target, push next PC, align destination |
| CALLA | `0D5F`, low/high address | 12-49 | Push PC after both extension words, align absolute destination |
| CALLR | `0D3F`, signed word offset | 12-50 | Push next PC, add signed offset multiplied by 16 |
| PUSHST / POPST | `01E0` / `01C0` | 12-228 / 12-227 | Force 32-bit stack access, predecrement/postincrement SP by 32 |
| RETS N | `0960` + N | 12-232 | Pop PC, add `32 + 16*N` to SP, preserve ST |
| RETI | `0940` | 12-230–231 | Pop ST then PC; increment SP by 32 for each |
| TRAP N | `0900` + N | 12-253–254 | Push next PC then ST, reset ST to `00000010`, read vector `FFFFFFE0 - 32*N` |
| ABS / NEG / NEGB / NOT | `0380` / `03A0` / `03C0` / `03E0` + R/Rd | 12-35, 12-168–169, 12-171 | Shared unary ALU, instruction-specific flag masks |
| ANDI/ANDNI / ORI / XORI | `0B80` / `0BA0` / `0BC0` + R/Rd, low/high immediate | 12-43, 12-45, 12-173, 12-256 | Logical immediate operations, Z only |

CALL through SP uses the original SP as its destination, even though the
push updates SP. All stack transfers support unaligned SP and
preserve neighboring field bits. TRAP zero is a separate microcode path:
it does not push PC/ST or update SP. Nonzero traps use two 32-bit pushes;
RETI restores them in the inverse order. The tests initialize independent
high-address trap vectors rather than silently aliasing them to the program.
The reference bench separately accommodates its existing memory-model alias.

ABS sets N from `0 - original Rd`, not from the stored absolute value.
Thus `ABS 1` returns 1 with N set, while `ABS FFFFFFFF` returns 1 with N clear.
Zero sets Z; `80000000` stays unchanged and sets V. C is preserved.
NEG/NEGB update N/C/Z/V, with NEGB subtracting incoming C as a borrow.
NOT changes only Z. ANDI and ANDNI share a hardware opcode, which computes
`Rd & ~encoded_immediate`; the assembler complements the extension for the
source-level ANDI mnemonic. ORI/XORI use the encoded immediate directly.

## Physical and system behavior

TI p. 12-253 requires PC and ST to be pushed MSW first, predecrementing SP
before each word. The shared push helper performs two 16-bit predecrements
and writes the high half before the low half. Physical word-bus assertions
cover PUSHST, CALLA and TRAP; the final memory field remains little-endian.
Unaligned halfword writes use the field adapter's preservation/RMW rules.

RETI's PBX-controlled resumption of interrupted PIXBLT/FILL (p. 12-230) is
tested with published B-register context, cached binary source bits and
nested ISR graphics. LINE uses ordinary opcode-PC restart with PBX clear.
Boundary interrupts observe the ST restored by RETI
before another instruction fetch. Reserved-opcode TRAP 30, NMI and maskable
interrupt entry share the stack helper; see [interrupt notes](interrupts.md).
Instruction and bus timing still require validation.
