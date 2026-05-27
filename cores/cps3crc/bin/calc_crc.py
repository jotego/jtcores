#!/usr/bin/env python3
"""Calculate CPS3CRC reference CRC values from jtutil sdram_bank files."""

import argparse
import binascii
from pathlib import Path


DEFAULT_ROOT = Path(__file__).resolve().parents[3] / "cores/cps3/ver"
ROUNDS = [
    ("8KB", [0x2000] * 4),
    ("64KB", [0x10000] * 4),
    ("256KB", [0x40000] * 4),
    ("FULL", [0x880000, 0x1000000, 0x1000000, 0x400000]),
]


def main() -> None:
    args = parse_args()
    setnames = args.setname or ["sfiiin", "redearthn"]
    rounds = [(f"{args.window:#x}", [args.window] * 4)] if args.window else ROUNDS

    for round_name, windows in rounds:
        print(round_name)
        for setname in setnames:
            base = args.root / setname
            print(setname)
            for bank, window in enumerate(windows):
                data = read_bank(base, bank, window)
                print(f"bank{bank} {crc32(data):08X}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Calculate the CRC-32 values used by the cps3crc firmware. "
            "Bytes are processed in the 16-bit word-swapped order seen "
            "through the SDRAM cache. Without --window, all firmware rounds "
            "are printed."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Directory containing per-setname sdram_bank*.bin files.",
    )
    parser.add_argument(
        "--setname",
        action="append",
        default=None,
        help="Setname to calculate. May be passed more than once.",
    )
    parser.add_argument(
        "--window",
        type=lambda value: int(value, 0),
        default=None,
        help="Override all banks with one byte window instead of printing firmware rounds.",
    )
    return parser.parse_args()


def read_bank(base: Path, bank: int, window: int) -> bytes:
    raw = (base / f"sdram_bank{bank}.bin").read_bytes()[:window]
    return b"".join(raw[offset : offset + 2][::-1] for offset in range(0, len(raw), 2))


def crc32(data: bytes) -> int:
    return binascii.crc32(data) & 0xFFFFFFFF


if __name__ == "__main__":
    main()
