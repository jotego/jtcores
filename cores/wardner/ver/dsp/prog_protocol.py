#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""A DSP program that exercises the Toaplan host handshake the way the real
code does: take the interrupt, open a window onto each of the three host RAMs
in turn, read operands, compute, write results, then arm the release and drop
the host's HALT line.

Data RAM layout used:
   0  0x70 scratch      4  window pointer    8  running total
   1  low byte scratch  5  operand           9  constant 0
   2  0xff scratch      6  product high     10  0xffff
   3  window pointer    7  loop counter
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asm32010 import assemble, write_hex

P = []
A = P.append

A(("B", "main"))
A(("B", "isr"))

A("main:")
A(("ZAC",))
A(("SACL", 8))              # running total = 0
A(("EINT",))
A("mloop:")
A(("B", "mloop"))           # idle until the host wakes us

A("isr:")
# ---- build 0xffff and 0x0000 constants in data RAM
A(("LACK", 0xff))
A(("SACL", 2))              # 0x00ff
A(("LAC", 2, 8))            # 0xff00
A(("ADD", 2, 0))            # 0xffff
A(("SACL", 10))
A(("ZAC",))
A(("SACL", 9))              # 0x0000

# ---- open the transaction: 0xffff to port 3 clears BIO
A(("OUT", 10, 3))
A(("BIOZ", "bad"))          # BIO is clear now, so this must fall through

# ---- point the window at host work RAM word 0x010  (0x7000 | 0x010)
A(("LACK", 0x70))
A(("SACL", 0))
A(("LAC", 0, 8))            # 0x7000
A(("SACL", 3))
A(("LACK", 0x10))
A(("SACL", 1))
A(("LAC", 3, 0))
A(("ADD", 1, 0))            # 0x7010
A(("SACL", 4))
A(("OUT", 4, 0))

# ---- read four consecutive words, summing them, bumping the pointer each time
A(("LARK", 0, 3))           # AR0 = loop count 3  (four passes)
A(("ZAC",))
A(("SACL", 8))
A("rloop:")
A(("IN", 5, 1))             # operand <- host memory
A(("LAC", 8, 0))
A(("ADDS", 5))
A(("SACL", 8))              # total += operand
A(("LAC", 4, 0))
A(("LACK", 1))
A(("SACL", 1))
A(("LAC", 4, 0))
A(("ADD", 1, 0))            # pointer += 1 word
A(("SACL", 4))
A(("OUT", 4, 0))
A(("BANZ", "rloop"))

# ---- multiply the total by 3 and write it into sprite RAM at 0x8000|0x004
A(("LT", 8))
A(("MPYK", 3))
A(("PAC",))
A(("SACL", 6))
A(("LACK", 0x80))
A(("SACL", 0))
A(("LAC", 0, 8))            # 0x8000
A(("SACL", 1))
A(("LACK", 0x04))
A(("SACL", 2))
A(("LAC", 1, 0))
A(("ADD", 2, 0))            # 0x8004
A(("SACL", 4))
A(("OUT", 4, 0))
A(("OUT", 6, 1))

# ---- write a marker into palette RAM at 0xa000|0x002
A(("LACK", 0xa0))
A(("SACL", 0))
A(("LAC", 0, 8))            # 0xa000
A(("SACL", 1))
A(("LACK", 0x02))
A(("SACL", 2))
A(("LAC", 1, 0))
A(("ADD", 2, 0))            # 0xa002
A(("SACL", 4))
A(("OUT", 4, 0))
A(("LACK", 0x5a))
A(("SACL", 6))
A(("OUT", 6, 1))

# ---- touch the top of the window so every offset bit is exercised: read
#      work RAM word 0x400 and write back to word 0x7ff
A(("LACK", 0x74)); A(("SACL", 0))
A(("LAC", 0, 8))            # 0x7400 -> work RAM word 0x400
A(("SACL", 4))
A(("OUT", 4, 0))
A(("IN", 5, 1))
A(("LACK", 0x77)); A(("SACL", 0))
A(("LAC", 0, 8))
A(("SACL", 1))
A(("LACK", 0xff)); A(("SACL", 2))
A(("LAC", 1, 0)); A(("ADD", 2, 0))   # 0x77ff -> work RAM word 0x7ff
A(("SACL", 4))
A(("OUT", 4, 0))
A(("OUT", 5, 1))

# ---- arm the release: a zero into work RAM word 0
A(("LAC", 3, 0))            # 0x7000, word 0
A(("SACL", 4))
A(("OUT", 4, 0))
A(("OUT", 9, 1))            # write 0x0000 there -> arms execute

# ---- close the transaction: 0x0000 to port 3 drops the host's HALT
A(("OUT", 9, 3))
A(("BIOZ", "done"))         # BIO is set now, so this must branch
A("bad:")
A(("B", "bad"))             # only reached if the BIO handshake misbehaved
A("done:")
A(("EINT",))
A(("RET",))

if __name__ == "__main__":
    write_hex(assemble(P), sys.argv[1] if len(sys.argv) > 1 else "dsp.hex")
    print("assembled %d instructions" % len(P))
