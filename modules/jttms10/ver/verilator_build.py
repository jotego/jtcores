#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a timed Verilator bench without relaxing its warnings."""
import argparse
from pathlib import Path
import re
import subprocess


def build_model(output, sources, *, top="test", includes=(), parameters=()):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(["verilator", "--version"], check=True,
                             capture_output=True, text=True).stdout
    match = re.search(r"Verilator (\d+)\.(\d+)", version)
    quiet = ["--quiet"] if match and tuple(map(int, match.groups())) >= (5, 24) else []
    command = ["verilator", "--binary", "--timing", *quiet, "--top-module", top,
               "--timescale-override", "1ns/1ps", "-Wno-EOFNEWLINE", "-j", "4",
               "--Mdir", str(output),
               *["-I"+str(Path(p).resolve()) for p in includes],
               *["-G"+p for p in parameters],
               *[str(Path(p).resolve()) for p in sources]]
    result = subprocess.run(command, capture_output=True, text=True)
    (output / "build.log").write_text(version + result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return output / ("V"+top)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--top", default="test")
    parser.add_argument("--include", type=Path, action="append", default=[])
    parser.add_argument("--parameter", action="append", default=[])
    parser.add_argument("sources", type=Path, nargs="+")
    args = parser.parse_args()
    build_model(args.output, args.sources, top=args.top,
                includes=args.include, parameters=args.parameter)


if __name__ == "__main__":
    main()
