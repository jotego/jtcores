# Shared-adder multiplication

MPYS and MPYU follow TI's 1988 *TMS34010 User's Guide*, printed pages
12-164–167. Opcode bases are `5C00` and `5E00`, plus source register,
file, and destination. Both multiply full-width Rd by the low FS1-bit field
of Rs. FS1 zero means 32; TI defines even field widths 2 through 32.
MPYS sign extends that field and MPYU zero extends it, independently of FE1
and FS0.

Even Rd stores the complete product: high 32 bits in Rd, low 32 bits in
Rd+1. Odd Rd stores only the low word in Rd. Both operands are captured
before either result write, including when Rs aliases Rd or Rd+1. The
B14/B15 result pair writes the shared SP correctly.

The YAML calls one shared helper for 32 right-shift/add iterations. It uses
the existing 32-bit ALU and carry bit, with a zero addend when the current
multiplier bit is clear. Existing b/md registers hold the 64-bit partial
product; a/tmp retain the original operands. Signed multiplication corrects
the final high word using two conditional subtractions through that same
ALU. There is no HDL multiplication operator, separate 64-bit adder, or
multiplier block. One register-file port writes the two result words in
successive microsteps.

MPYS sets N/Z from the stored result width: all 64 bits for an even
destination, only the retained low 32 for an odd destination. MPYU sets Z
using that same width and preserves N. Both preserve C/V. The microcode
control groups for shifts, scans, lists, and multiplication encode mutually
exclusive steps to keep the current ROM word at 64 bits.

Four durable YAML programs cover sign and minimum-integer cases, truncated
results, full nonzero products with a zero low word, FS1 2/16/32, FE1/FS0
independence, operand aliases, register files, shared SP, and flags. They
also pass the pinned old CPU.

An independent Python arbitrary-precision model generates 320 products over
all defined even FS1 widths, with signed/unsigned and even/odd destinations,
boundary/random operands, aliases, unchanged register checks, and full ST
assertions. Reproduce it after generating microcode:

```sh
bash modules/jttms10/ver/build.sh
python3 modules/jttms10/ver/multiply/check.py
python3 modules/jttms10/ver/multiply/check.py --seed 0x14134010
```

Each seed runs 16 temporary programs through the ordinary YAML runner. Its
`--vectors PATH` option accepts additional YAML or JSON programs without
changing the default suite. This proves architectural arithmetic results;
the fixed 32-iteration loop does not implement TI's field-size-dependent
machine-state count. Integrated timing remains to be measured.
