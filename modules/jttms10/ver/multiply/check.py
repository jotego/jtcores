#!/usr/bin/env python3
"""Seeded architectural MPYS/MPYU cross-check against Python integers.

Run from any directory: python3 modules/jttms10/ver/multiply/check.py
The 320 products are independent of the CPU's shift/add implementation.
Each of 16 field widths produces one short program covering signed and
unsigned, odd and even destinations, zero, boundary, and random operands.
The ordinary YAML runner checks every retirement; generated JSON uses the
same vector schema and is discarded after the run.
"""

import argparse
import json
import random
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
VER = HERE.parent
SEED = 0x34010
WIDTHS = range(2, 33, 2)
MASK32 = (1 << 32) - 1
MASK64 = (1 << 64) - 1
STATUS = 0xD0000010  # N/C/V=1, Z=0; FS0=16, FS1=0.
REGS = ("A0", "A1", "A2")


def signed32(value):
    return value - (1 << 32) if value & (1 << 31) else value


def product(src, dst, width, signed):
    multiplier = src & ((1 << width) - 1)
    if signed and multiplier & (1 << (width - 1)):
        multiplier -= 1 << width
    multiplicand = signed32(dst) if signed else dst
    return (multiplier * multiplicand) & MASK64


def sample(rng, width, slot):
    if slot == 0:
        return 0, 0
    if slot == 1:
        return MASK32, MASK32
    if slot == 2:
        # The selected field's sign bit is set, regardless of upper bits.
        return ((1 << (width - 1)) | (rng.getrandbits(32) & ~((1 << width) - 1))), 0x80000000
    return rng.getrandbits(32), rng.getrandbits(32)


def one_case(rng, width):
    words = []
    checks = []
    pc = 0x1000
    for signed in (True, False):
        for even in (True, False):
            for slot in range(5):
                src, dst = sample(rng, width, slot)
                # Even destinations use A0:A1. Odd destinations use A1.
                # Include Rs=Rd, Rs=Rd+1, and a separate source A2.
                source_idx = (2, 0, 1, 2, 1)[slot] if even else (2, 1, 0, 2, 1)[slot]
                dest_idx = 0 if even else 1
                before = [rng.getrandbits(32) for _ in REGS]
                before[dest_idx] = dst
                before[source_idx] = dst if source_idx == dest_idx else src
                src = before[source_idx]
                dst = before[dest_idx]

                for idx, value in enumerate(before):
                    words.extend((0x09E0 | idx, value & 0xFFFF, value >> 16))
                    checks.append({"after": pc, "pc": pc + 0x30,
                                   "regs": {REGS[idx]: value}})
                    pc += 0x30
                words.extend((0x09E3, STATUS & 0xFFFF, STATUS >> 16))
                checks.append({"after": pc, "pc": pc + 0x30,
                               "regs": {"A3": STATUS}})
                pc += 0x30
                words.append(0x01A3)  # PUTST A3
                checks.append({"after": pc, "pc": pc + 0x10, "st": STATUS})
                pc += 0x10
                words.append(0x055F)  # SETF 31,0,F0; must not select multiplier width
                checks.append({"after": pc, "pc": pc + 0x10, "st": 0xD000001F})
                pc += 0x10
                fe1 = (slot + int(signed)) & 1
                words.append(0x0740 | (fe1 << 5) | (width & 31))
                pre_st = 0xD000001F | (fe1 << 11) | ((width & 31) << 6)
                checks.append({"after": pc, "pc": pc + 0x10, "st": pre_st})
                pc += 0x10

                opcode = (0x5C00 if signed else 0x5E00) | (source_idx << 5) | dest_idx
                words.append(opcode)
                result = product(src, dst, width, signed)
                low = result & MASK32
                stored = result if even else low
                after = before[:]
                if even:
                    after[0] = result >> 32
                    after[1] = low
                else:
                    after[1] = low
                post_st = pre_st & ~(1 << 29)  # Z is always updated.
                if stored == 0:
                    post_st |= 1 << 29
                if signed:
                    post_st &= ~(1 << 31)
                    if stored & (1 << (63 if even else 31)):
                        post_st |= 1 << 31
                checks.append({"after": pc, "pc": pc + 0x10, "st": post_st,
                               "regs": {**dict(zip(REGS, after)), "A3": STATUS}})
                pc += 0x10

    return {"name": f"multiply_fs{width:02d}", "entry": 0x1000,
            "words": words, "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda text: int(text, 0), default=SEED,
                        help="PRNG seed, decimal or 0x-prefixed (default: 0x34010)")
    args = parser.parse_args()
    rng = random.Random(args.seed)
    cases = [one_case(rng, width) for width in WIDTHS]
    count = len(WIDTHS) * 2 * 2 * 5
    print(f"MPYS/MPYU seed={args.seed:#x}, products={count}, "
          f"widths=2..32 even, programs={len(cases)}", flush=True)
    with tempfile.TemporaryDirectory(prefix="jttms10-multiply-") as temp:
        source = Path(temp) / "vectors.json"
        source.write_text(json.dumps({"cases": cases}))
        subprocess.run([sys.executable, str(VER / "run.py"), "--vectors", str(source)],
                       check=True)


if __name__ == "__main__":
    main()
