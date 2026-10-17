#!/usr/bin/env python3
"""Emit or verify the coarse dispatch ROM from the controller decode function."""
import argparse
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("controller", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--check", type=Path,
                        help="fail if the checked-in ROM differs from the generated image")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    bench = Path(__file__).with_name("dump.sv")
    binary = out / "dispatch_dump.vvp"
    subprocess.run([
        "iverilog", "-g2012", "-DTMS10_DISPATCH_GENERATE", "-s", "test", "-I" + str(out),
        "-o", str(binary), str(args.controller.resolve()), str(bench)
    ], check=True)
    subprocess.run(["vvp", str(binary), "+output=" + str(out / "tms10_dispatch.hex")],
                   cwd=out, check=True, stdout=subprocess.DEVNULL)
    words = (out / "tms10_dispatch.hex").read_text().splitlines()
    if len(words) != 2048 or any(len(word) != 2 for word in words):
        raise RuntimeError("dispatch ROM must have 2048 eight-bit entries")
    if args.check and (args.check.read_text().splitlines() != words):
        raise SystemExit(f"stale dispatch ROM: {args.check}")


if __name__ == "__main__":
    main()
