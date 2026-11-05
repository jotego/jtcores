# 052591 Thunder Cross program regression

Run from the repository root:

```sh
source setprj.sh
simunit.sh --run cores/aliens/ver/jt052591_program
```

This test uploads both real Thunder Cross programs through the CPU interface,
using five low-byte-first writes per instruction and a locked entry point of
1. External memory is a synchronous `jtframe_dual_ram`; all initialization and
result inspection use the CPU interface. Neither the expected-results model
nor the test accesses processor internals.

The two checked-in hexadecimal fixtures reproduce the 64-instruction startup
program listings in MAME's `src/mame/konami/thunderx.cpp`, headed “This is the
052591 PMC code loaded at startup” (local source inspected 2026-09-24). Each
line contains five bytes in host upload order. The last four/common or
three/alternate instructions are the original unused trailing data. The
common listing also matches SiliconRE's
`Konami/052591/thunderx.bin.txt`. Fixture provenance:

- https://github.com/mamedev/mame/blob/master/src/mame/konami/thunderx.cpp
- https://github.com/furrtek/SiliconRE/tree/master/Konami/052591

There is no runtime dependency on either external repository or on game ROMs.

The independent object-level model follows the actual decoded microcode,
including details that differ from MAME's high-level approximation:

- Coordinate distances must be strictly less than the sum of half widths or
  heights: equality is rejected by the subtraction carry branch.
- Width and height addition has 16-bit precision, without 8-bit wraparound.
- Coordinates are unsigned bytes; their difference is signed and then made
  absolute, without coordinate wraparound.
- Set 1's final object address is inclusive; the set 0 end address is exclusive.
- Object 1 keeps bits selected by `0x9f`, and object 0 by `0x9b`; bit 4 is
  set and object 1's bit 2 propagates to object 0.
- Object 0 flags remain protected when its address plus four is below `0xe6`
  (common) or `0x136` (alternate); equality allows the write.
- Each object 0 stops at its first eligible collision.

Each program runs 24 directed fixtures and 56 reproducible randomized
fixtures. Directed fixtures exercise exact boundaries, adjacent coordinates,
large width/height sums, extreme coordinates, masks, zero-sized boxes,
protected and writable flags, the final set 1 entry, and first-hit exit.
Randomized fixtures include four objects against five candidates, testing
nested loops and big-endian set 0 endpoints. All 512 bytes are compared after
every run, detecting unintended writes to flags, object fields or unrelated
memory. Holding each CPU write for multiple clock enables checks upload
transaction handling. Repeated runs reuse the uploaded program and entry
point; OUT0 completion and recovery on STOP are checked with a watchdog.

Before the game fixtures, host-control checks verify external RAM reads with
BK=1 and an undriven CPU bus (modeled as `0xff`) with BK=0, blocked CPU RAM
writes during START, and ignored configuration
and program writes during START (using an unlocked PC and a completion sentinel
at the attempted replacement entry point). A separate two-instruction program
uploads across slot 63 to slot 0, starts at slot 63, and ignores nonzero upper
nibbles in the fifth instruction bytes.

The BK read expectation follows sheet 3 of SiliconRE's
`Konami/052591/052591_schematics.pdf`: BK=0 blocks the external RAM read path.
This deliberately differs from that directory's prose README, which claims
that reads always select external RAM independently of BK.
