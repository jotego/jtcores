#!/usr/bin/env python3
"""Generate reproducible architectural PIXT/PPOP register-store programs.

The expected word is calculated with Python integer pixel equations, not the
RTL pixel helper. Run the generated YAML with ver/run.py --vectors and
ver/reference.py --vectors after the ordinary module build.
"""

import argparse
import random
from pathlib import Path

import yaml


def operation(code, source, dest, mask):
    """TI guide §7.7 truth table and unsigned color arithmetic."""
    table = (
        lambda s, d: s,
        lambda s, d: s & d,
        lambda s, d: s & ~d,
        lambda s, d: 0,
        lambda s, d: s | ~d,
        lambda s, d: ~(s ^ d),
        lambda s, d: ~d,
        lambda s, d: ~(s | d),
        lambda s, d: s | d,
        lambda s, d: d,
        lambda s, d: s ^ d,
        lambda s, d: ~s & d,
        lambda s, d: mask,
        lambda s, d: ~s | d,
        lambda s, d: ~(s & d),
        lambda s, d: ~s,
        lambda s, d: s + d,
        lambda s, d: min(mask, s + d),
        lambda s, d: d - s,
        lambda s, d: max(0, d - s),
        lambda s, d: max(s, d),
        lambda s, d: min(s, d),
    )
    return table[code](source, dest) & mask


def make_case(code, sample, rng):
    size = (1, 2, 4, 8, 16)[(code + sample) % 5] if code < 16 else (4, 8, 16)[(code + sample) % 3]
    mask = (1 << size) - 1
    lane = rng.randrange(16 // size) * size
    if sample == 0:
        source = rng.randrange(mask + 1)
        dest = rng.randrange(mask + 1)
    else:
        source = (mask - 1) if code in (16, 17, 20) else (mask if code in (18, 19, 21) else rng.randrange(mask + 1))
        dest = 3 if code in (16, 17) else (1 if code in (18, 19) else rng.randrange(mask + 1))
        source &= mask
        dest &= mask
    source_word = source | (rng.getrandbits(16) << 16)
    initial = rng.getrandbits(16)
    initial = (initial & ~(mask << lane)) | (dest << lane)
    result = operation(code, source, dest, mask)
    final = (initial & ~(mask << lane)) | (result << lane)
    pointer = 0x0200 + lane
    name = f"pixel_ppop_{code:02d}_sample_{sample}"
    return {
        "name": name,
        "entry": 0x1000,
        "pixel_size": size,
        "control": code << 10,
        "pmask": 0,
        "mem": [{"at": 0x0200, "words": [initial]}],
        "words": [
            0x09C0, pointer,  # MOVI IW pointer,A0
            0x09E1, source_word & 0xFFFF, source_word >> 16,  # MOVI IL source,A1
            0x09E2, 0x0010, 0xF000,  # MOVI IL status sentinel,A2
            0x01A2,  # PUTST A2
            0xF820,  # PIXT A1,*A0
        ],
        "checks": [
            {"after": 0x1000, "pc": 0x1020, "regs": {"A0": pointer}},
            {"after": 0x1020, "pc": 0x1050, "regs": {"A1": source_word}},
            {"after": 0x1050, "pc": 0x1080, "regs": {"A2": 0xF0000010}},
            {"after": 0x1080, "pc": 0x1090, "st": 0xF0000010},
            {"after": 0x1090, "pc": 0x10A0, "st": 0xF0000010,
             "regs": {"A0": pointer, "A1": source_word},
             "mem": [{"addr": 0x0200, "size": 16, "value": final}]},
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=34010)
    parser.add_argument("--samples", type=int, default=2,
                        help="independent operand samples per PPOP code")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    rng = random.Random(args.seed)
    cases = [make_case(code, sample, rng)
             for code in range(22) for sample in range(args.samples)]
    args.out.write_text(yaml.safe_dump(
        {"pixel_program_seed": args.seed, "cases": cases},
        sort_keys=False,
    ))
    print(f"wrote {len(cases)} PIXT programs (seed {args.seed}) to {args.out}")


if __name__ == "__main__":
    main()
