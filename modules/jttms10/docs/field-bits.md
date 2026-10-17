# Scalar field and bit instructions

The primary references are printed instruction pages in TI's 1988
*TMS34010 User's Guide*, not PDF page numbers.

| Instruction | Opcode | TI page | Result and flags |
| --- | --- | --- | --- |
| SETF FS,FE,F | `0540` + F/FE/FS | 12-237 | Replace selected six-bit FS/FE pair; preserve other status bits |
| SEXT Rd,F | `0500` + F/R/Rd | 12-238 | Sign extend low FS bits; update N/Z only |
| ZEXT Rd,F | `0520` + F/R/Rd | 12-257 | Zero extend low FS bits; update Z only |
| EXGF Rd,F | `D500` + F/R/Rd | 12-78 | Exchange Rd low six bits with selected FS/FE pair; zero Rd upper bits; preserve flags |
| BTST K,Rd | `1C00` + complemented K/R/Rd | 12-46 | Z is the inverse of the selected bit; preserve N/C/V and Rd |
| BTST Rs,Rd | `4A00` + Rs/R/Rd | 12-47 | Same operation, index from Rs low five bits |
| LMO Rs,Rd | `6A00` + Rs/R/Rd | 12-108 | Count leading zeros for nonzero source; zero result for zero source; Z reflects source zero |

F is instruction bit 9 and R is bit 4. Encoded FS zero means 32 bits.
SEXT and ZEXT use the selected size independently of FE. EXGF captures the
old field definition and old register value on the same microstep, including
when Rd is A15/B15 (the shared SP).

BTST's constant encoding is one's complement: a source-level bit zero uses
encoded K=31, and bit 31 uses encoded K=0. The register form does not complement
its index. These distinctions are explicit in the YAML programs.

LMO uses a one-bit left-shift scan through the existing ALU, with a five-bit
count. It stops when the high bit is set, or immediately when the source is
zero. A nonzero source with its MSB set returns count zero with Z clear;
a zero source returns zero with Z set. No priority encoder was added.
As with iterative shifts, this functional implementation takes more clocks
than TI's one-machine-state LMO timing.

Five directed YAML cases check both fields, sizes 1/31/32, FE-independent
extension, preservation of the other field and flags, EXGF upper-bit clearing
and SP alias, BTST indexes 0/31 and source truncation, and all five published
LMO examples. Their architectural assertions also pass on the pinned old CPU.
