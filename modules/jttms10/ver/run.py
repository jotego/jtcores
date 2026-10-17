#!/usr/bin/env python3
"""Compile and run each TMS34010 YAML program against jttms10.

Generate the microcode RTL first (the module build script owns that step),
then run `python3 ver/run.py` from any directory. Requires PyYAML, Icarus
Verilog, and vvp. `--case NAME` runs one vector.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

sys.dont_write_bytecode = True
from vectors import HERE, load_cases, memory_init, sv_checks, validate_case, vector_init


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", help="run only this YAML case")
    parser.add_argument("--vectors", type=Path, default=HERE / "tests.yaml",
                        help="YAML/JSON vector file (default: ver/tests.yaml)")
    parser.add_argument("--rtl", action="append", type=Path, default=[],
                        help="extra generated RTL source (repeatable)")
    args = parser.parse_args()
    cases = load_cases(yaml.safe_load(args.vectors.read_text()))
    for case in cases:
        validate_case(case)
    selected = [case for case in cases if args.case in (None, case["name"])]
    if not selected:
        parser.error(f"unknown case {args.case!r}")
    hdl = HERE.parent / "hdl"
    build = HERE / "build"
    if not (build / "tms10_param.vh").exists() or not (build / "tms10.vh").exists():
        parser.error("generated microcode headers are missing; run ver/build.sh first")
    if (HERE.parent / "ucode/gfx.yaml").exists() and not (build / "tms10_gfx.uc").exists():
        parser.error("generated graphics microcode is missing; run ver/build.sh first")
    sources = sorted(hdl.glob("*.v")) + sorted(hdl.glob("*.sv")) + args.rtl
    if not any(path.stem == "jttms10" for path in sources):
        parser.error("jttms10 RTL is missing; run the module build first")

    for case in selected:
        with tempfile.TemporaryDirectory(prefix=f"jttms10-{case['name']}-") as temp:
            work = Path(temp)
            (work / "program.mem").write_text(
                "".join(f"{word:04x}\n" for word in case["words"])
            )
            (work / "memory_init.txt").write_text(memory_init(case))
            (work / "vector_init.txt").write_text(vector_init(case))
            (work / "expected.svh").write_text(sv_checks(case))
            shutil.copyfile(build / "tms10.uc", work / "tms10.uc")
            if (build / "tms10_gfx.uc").exists():
                shutil.copyfile(build / "tms10_gfx.uc", work / "tms10_gfx.uc")
            shutil.copyfile(build / "tms10_dispatch.hex", work / "tms10_dispatch.hex")
            binary = work / "sim.vvp"
            compile_cmd = ["iverilog", "-g2012", "-s", "test", "-I", str(work),
                           "-I", str(hdl), "-I", str(build),
                           "-o", str(binary), str(HERE / "test.sv")]
            compile_cmd.extend(str(source.resolve()) for source in sources)
            subprocess.run(compile_cmd, check=True, cwd=work)
            result = subprocess.run(["vvp", str(binary)], cwd=work,
                                    capture_output=True, text=True)
            if result.returncode or "TEST_RESULT: PASS" not in result.stdout:
                print(f"{case['name']}: FAIL\n{result.stdout}{result.stderr}")
                raise SystemExit(1)
            print(f"{case['name']}: PASS")


if __name__ == "__main__":
    main()
