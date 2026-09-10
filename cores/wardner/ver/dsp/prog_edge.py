#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Negative test for the host-release interlock.

The host is only allowed to restart when the DSP writes a *zero* into word 0
or 1 of *work* RAM and then writes zero to port 3. This program tries every
near miss first - the right value at the wrong address, the wrong value at the
right address, an address in the wrong RAM, and a window pointing at no RAM at
all - and only then does the real thing. Each near miss is followed by a port 3
zero, so a decode that is too generous releases the host early and the log
diverges immediately.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asm32010 import assemble, write_hex

P = []
A = P.append

# data RAM: 0 scratch hi, 1 scratch lo, 2 pointer, 3 zero, 4 0xffff, 5 nonzero,
#           6 read-back
A(("B", "main"))
A(("B", "isr"))

A("main:")
A(("EINT",))
A("mloop:")
A(("B", "mloop"))

def point(hi, lo):
    """window <- (hi<<8)|lo, via port 0"""
    A(("LACK", hi)); A(("SACL", 0))
    A(("LAC", 0, 8))
    A(("SACL", 2))
    A(("LACK", lo)); A(("SACL", 1))
    A(("LAC", 2, 0)); A(("ADD", 1, 0))
    A(("SACL", 2))
    A(("OUT", 2, 0))

A("isr:")
A(("ZAC",)); A(("SACL", 3))                 # 0x0000
A(("LACK", 0xff)); A(("SACL", 0))
A(("LAC", 0, 8)); A(("ADD", 0, 0)); A(("SACL", 4))   # 0xffff
A(("LACK", 0x77)); A(("SACL", 5))           # a non-zero payload

A(("OUT", 4, 3))                            # 0xffff -> clear BIO, open

# near miss 1: zero, but work RAM word 5
point(0x70, 0x05)
A(("OUT", 3, 1))
A(("OUT", 3, 3))                            # must NOT release

# near miss 2: zero, but sprite RAM word 0
point(0x80, 0x00)
A(("OUT", 3, 1))
A(("OUT", 3, 3))                            # must NOT release

# near miss 3: work RAM word 0, but a non-zero value
point(0x70, 0x00)
A(("OUT", 5, 1))
A(("OUT", 3, 3))                            # must NOT release

# near miss 4: a window pointing at no host RAM at all
point(0x00, 0x00)
A(("OUT", 5, 1))                            # write must be dropped
A(("IN", 6, 1))                             # read must come back zero
A(("OUT", 3, 3))                            # must NOT release

# the real thing: zero into work RAM word 1
point(0x70, 0x01)
A(("OUT", 3, 1))
A(("OUT", 3, 3))                            # releases the host here

A(("EINT",))
A(("RET",))

if __name__ == "__main__":
    write_hex(assemble(P), sys.argv[1] if len(sys.argv) > 1 else "edge.hex")
    print("assembled %d instructions" % len(P))
