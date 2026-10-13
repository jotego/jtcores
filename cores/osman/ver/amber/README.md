# Amber instruction regression

Run `./run.sh` with Icarus Verilog installed. The CPU runs at one enable every
eight system clocks, using a target that returns read data only with ack and
pull-ups otherwise, matching the relevant JTFRAME bus behavior. Five response
latencies exercise completion before and after the next CPU enable.

The program checks word and byte transfers, multiple-register transfers,
rotated/unrotated immediate carry, logical overflow preservation, unique
writes, warm reset status, and re-execution after warm reset.
The separate `swap.hex` program also checks word/byte SWP read-modify-write
sequences, which keep the Wishbone cycle exclusive between their two halves.

`program.hex` is the little-endian ARM word encoding of `program.s`; it is
checked in so tests need no ARM assembler. Its 50 words can be regenerated
with an ARM-capable assembler and extracted from the object's `.text` section.
No ROMs or game-specific state are used.

For comparison with an earlier CPU, set `AMBER_HDL` to a folder containing
its `amber/` source directory. The unpatched CPU fails the unique-write check.
