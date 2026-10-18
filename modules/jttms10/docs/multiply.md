# DSP multiplication

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

The YAML captures operands, performs one inferred unsigned 32×32 multiply,
corrects the signed high word, sets flags, and writes the result in seven
microinstructions. The HDL product has `multstyle="dsp"`. Existing b/md
registers hold the full product and a/tmp retain the original operands.
Signed multiplication corrects the high word with two conditional
subtractions through the shared 32-bit ALU. One register-file port writes
the two result words in successive microsteps. The divider retains its
separate restoring loop and iteration counter.

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
changing the default suite. This proves architectural arithmetic results.

The DSP change removes the old 32-iteration loop's minimum-latency obstacle.
The instruction scheduler now holds final writeback for TI's FS1-dependent
machine states and adds MPYU's source-field-sign state. The permanent
[timing suite](timing.md) checks all defined widths with both signs and
destination parities, cache hit/off, physical read timing and stalls.
Those scalar probes pass; interrupt/memory contention and full-ISA timing
acceptance remain open under #144.

The isolated matched `quartus_map` comparison attached to #144 reports three
DSP blocks and 2,859 estimated ALMs, versus zero DSPs and 2,761 estimated
ALMs for the old loop. Both use 1,523 registers and 542,720 block-RAM bits.
These are Analysis & Synthesis estimates, separate from #141's 2,746 fitted
ALMs. This combinational DSP product uses the existing operand/product
registers; final FPGA setup/hold closure and fitted area remain to be
revalidated after the timing implementation is complete.
