#!/usr/bin/env python3
"""Run TMS34010 architectural fixtures on one Verilator-compiled bench.

Run `ver/build.sh` first, then use `python3 ver/run.py [--case NAME]`.
The executable and runtime fixture files remain in `ver/build` for debugging.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import yaml

sys.dont_write_bytecode = True
from vectors import HERE, load_cases, memory_init, validate_case, vector_init
from runtime import runtime_case


def write_case(work, case):
    (work / "program.mem").write_text(
        "".join(f"{word:04x}\n" for word in case["words"])
    )
    (work / "memory_init.txt").write_text(memory_init(case))
    (work / "vector_init.txt").write_text(vector_init(case))
    (work / "case.cfg").write_text(runtime_case(case))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append",
                        help="run this YAML case (repeat to select several)")
    parser.add_argument("--vectors", type=Path, default=HERE / "tests.yaml",
                        help="YAML/JSON vector file (default: ver/tests.yaml)")
    parser.add_argument("--rtl", action="append", type=Path, default=[],
                        help="extra generated RTL source (repeatable)")
    parser.add_argument("--timeout", type=float, default=60,
                        help="wall-clock timeout per fixture in seconds")
    args = parser.parse_args()
    cases = load_cases(yaml.safe_load(args.vectors.read_text()))
    for case in cases:
        validate_case(case)
    case_names = [case["name"] for case in cases]
    if len(case_names) != len(set(case_names)):
        parser.error("duplicate case names in vector file")
    names = set(case_names)
    unknown = sorted(set(args.case or []) - names)
    if unknown:
        parser.error(f"unknown case {', '.join(unknown)}")
    requested = set(args.case or [])
    selected = [case for case in cases if not requested or case["name"] in requested]
    if not selected:
        parser.error("no architectural cases selected")
    hdl = HERE.parent / "hdl"
    build = HERE / "build"
    if not (build / "tms10_param.vh").exists() or not (build / "tms10.vh").exists():
        parser.error("generated microcode headers are missing; run ver/build.sh first")
    if (HERE.parent / "ucode/gfx.yaml").exists() and not (build / "tms10_gfx.uc").exists():
        parser.error("generated graphics microcode is missing; run ver/build.sh first")
    sources = sorted(hdl.glob("*.v")) + sorted(hdl.glob("*.sv")) + args.rtl
    if not any(path.stem == "jttms10" for path in sources):
        parser.error("jttms10 RTL is missing; run the module build first")

    binary = build / "obj_fixture" / "Vtest"
    compile_cmd = [
        "verilator", "--quiet", "--binary", "--timing", "--assert", "--top-module", "test",
        "-Wno-fatal", "-I" + str(build), "-I" + str(hdl),
        "--Mdir", str(binary.parent), "-o", binary.name, str(HERE / "test.sv"),
    ]
    compile_cmd.extend(str(source.resolve()) for source in sources)
    subprocess.run(compile_cmd, check=True, cwd=build)

    passed = 0
    for case in selected:
        write_case(build, case)
        try:
            result = subprocess.run([str(binary)], cwd=build, capture_output=True,
                                    text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            print(f"{case['name']}: FAIL (wall-clock timeout after {args.timeout}s)")
            if error.stdout:
                print(error.stdout)
            if error.stderr:
                print(error.stderr, file=sys.stderr)
            raise SystemExit(1)
        output = result.stdout + result.stderr
        if result.returncode or "TEST_RESULT: PASS" not in output:
            print(f"{case['name']}: FAIL (exit {result.returncode})\n{output}")
            raise SystemExit(result.returncode or 1)
        print(f"{case['name']}: PASS")
        passed += 1
    print(f"Verilator architectural fixtures: {passed}/{len(selected)} passed")


if __name__ == "__main__":
    main()
