#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Fill a 4096-word TMS320C10 program image with random *legal* instruction
# words. Every word is legal, so execution can fall into an operand word or a
# branch can land anywhere without hitting an illegal opcode, and both the C
# reference model and the RTL will still agree on what happens.
import random, sys

def legal_words(rng):
    hi = []
    hi += list(range(0x00, 0x30))          # ADD / SUB / LAC, shift in the low nibble
    hi += [0x30, 0x31, 0x38, 0x39]         # SAR / LAR
    hi += list(range(0x40, 0x50))          # IN / OUT
    hi += [0x50]                           # SACL
    hi += list(range(0x58, 0x60))          # SACH
    hi += list(range(0x60, 0x72))          # ADDH..LARK  (0x72-0x77 are illegal)
    hi += list(range(0x78, 0x7f))          # XOR..LACK
    hi += list(range(0x80, 0xa0))          # MPYK
    hi += [0xf4, 0xf5, 0xf6]               # BANZ / BV / BIOZ
    hi += list(range(0xf8, 0x100))         # CALL / BR / conditional branches
    ext = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0a, 0x0b,
           0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x1c, 0x1d]

    h = rng.choice(hi + [0x7f] * 12)       # weight the 0x7f group up a little
    if h == 0x7f:
        return 0x7f00 | 0x80 | rng.choice(ext)
    return (h << 8) | rng.randrange(0x100)

def main():
    seed  = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    out   = sys.argv[2] if len(sys.argv) > 2 else "prog.hex"
    rng   = random.Random(seed)
    words = [legal_words(rng) for _ in range(4096)]
    with open(out, "w") as f:
        for w in words:
            f.write("%04x\n" % w)

main()
