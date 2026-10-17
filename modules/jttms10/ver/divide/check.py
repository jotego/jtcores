#!/usr/bin/env python3
"""Seeded DIVS/DIVU/MODS/MODU architectural check using Python integers.

Run: python3 modules/jttms10/ver/divide/check.py [--seed 0xd17e]
Twelve generated programs cover 240 nonexceptional divisions. Division
rounds toward zero for signed operands, with remainder signed like the
dividend. Exceptional zero-divisor/range-overflow behavior is covered by
the durable tests.yaml programs instead.
"""

import argparse
import json
import random
import subprocess
import sys
import tempfile
from pathlib import Path


VER = Path(__file__).resolve().parents[1]
MASK32 = (1 << 32) - 1
MASK64 = (1 << 64) - 1
SEED = 0xD17E
MODES = ("divs_even", "divs_odd", "divu_even", "divu_odd", "mods", "modu")


def signed(value, bits):
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def trunc_divmod(dividend, divisor):
    quotient = abs(dividend) // abs(divisor)
    if (dividend < 0) != (divisor < 0):
        quotient = -quotient
    return quotient, dividend - quotient * divisor


def operands(rng, mode, slot):
    is_signed = mode in ("divs_even", "divs_odd", "mods")
    is_even = mode.endswith("even")
    while True:
        raw_divisor = rng.getrandbits(32)
        divisor = signed(raw_divisor, 32) if is_signed else raw_divisor
        if divisor == 0:
            continue
        if slot == 0:
            dividend = 0
        elif slot == 1:
            # Exact quotient, zero remainder. Limit q so the constructed
            # dividend always fits the selected 32/64-bit register width.
            q = rng.randrange(1, 1 << (10 if is_even else 4))
            if is_signed and rng.getrandbits(1):
                q = -q
            dividend = divisor * q
        elif slot == 2:
            # Nonzero remainder with a zero quotient.
            dividend = (1 if divisor > 0 else -1) if abs(divisor) > 1 else 0
        else:
            bits = 64 if is_even else 32
            raw = rng.getrandbits(bits)
            dividend = signed(raw, bits) if is_signed else raw
        bits = 64 if is_even else 32
        fits = (-(1 << (bits - 1)) <= dividend < (1 << (bits - 1))) if is_signed else (0 <= dividend <= (1 << bits) - 1)
        if not fits:
            continue
        quotient, remainder = trunc_divmod(dividend, divisor)
        if is_signed and not -(1 << 31) <= quotient < (1 << 31):
            continue
        if not is_signed and not 0 <= quotient <= MASK32:
            continue
        raw_dividend = dividend & ((1 << bits) - 1)
        high = (raw_dividend >> 32) & MASK32 if is_even else rng.getrandbits(32)
        low = raw_dividend & MASK32
        return high, low, raw_divisor, quotient & MASK32, remainder & MASK32


def one_case(rng, mode, number):
    words = []
    checks = []
    pc = 0x1000
    is_div = mode.startswith("div")
    is_signed = mode in ("divs_even", "divs_odd", "mods")
    is_even = mode.endswith("even")
    opcode_base = {"divs_even": 0x5800, "divs_odd": 0x5800,
                   "divu_even": 0x5A00, "divu_odd": 0x5A00,
                   "mods": 0x6C00, "modu": 0x6E00}[mode]
    for i in range(20):
        high, low, divisor, quotient, remainder = operands(rng, mode, i % 4)
        before = (high, low, divisor)
        status = 0x50000010 if i & 1 else 0xD0000010  # vary original N.
        for idx, value in enumerate(before):
            words.extend((0x09E0 | idx, value & 0xFFFF, value >> 16))
            checks.append({"after": pc, "pc": pc + 0x30,
                           "regs": {f"A{idx}": value}})
            pc += 0x30
        words.extend((0x09E3, status & 0xFFFF, status >> 16))
        checks.append({"after": pc, "pc": pc + 0x30, "regs": {"A3": status}})
        pc += 0x30
        words.append(0x01A3)  # PUTST A3
        checks.append({"after": pc, "pc": pc + 0x10, "st": status})
        pc += 0x10

        dest_idx = 0 if is_even else 1
        words.append(opcode_base | (2 << 5) | dest_idx)
        post = [*before]
        if is_div:
            post[dest_idx] = quotient
            if is_even:
                post[1] = remainder
            result = quotient
        else:
            post[1] = remainder
            result = remainder
        post_st = status & ~((1 << 29) | (1 << 28))  # Z updated; V=0.
        if result == 0:
            post_st |= 1 << 29
        if is_signed and is_div:
            post_st = (post_st & ~(1 << 31)) | (result & (1 << 31))
        checks.append({"after": pc, "pc": pc + 0x10, "st": post_st,
                       "regs": {"A0": post[0], "A1": post[1],
                                "A2": post[2], "A3": status}})
        pc += 0x10
    return {"name": f"seeded_{mode}_{number}", "entry": 0x1000,
            "words": words, "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=SEED)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    cases = [one_case(rng, mode, number)
             for mode in MODES for number in range(2)]
    print(f"DIV/MOD seed={args.seed:#x}, divisions={len(cases) * 20}, "
          f"programs={len(cases)}", flush=True)
    with tempfile.TemporaryDirectory(prefix="jttms10-divide-") as temp:
        source = Path(temp) / "vectors.json"
        source.write_text(json.dumps({"cases": cases}))
        subprocess.run([sys.executable, str(VER / "run.py"), "--vectors", str(source)],
                       check=True)


if __name__ == "__main__":
    main()
