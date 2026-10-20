#!/usr/bin/env python3
"""Compile and run each TMS34010 YAML program against jttms10.

Generate the microcode RTL first (the module build script owns that step),
then run `python3 ver/run.py` from any directory. Requires PyYAML, Verilator
and a C++ compiler. Compile one model and use a fresh process for each case.
`--case NAME` runs one vector.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

sys.dont_write_bytecode = True
from vectors import HERE, load_cases, memory_init, sv_checks, validate_case, vector_init


def suite_checks(cases, core="u_cpu"):
    """Select unchanged per-vector assertions/configuration at process startup."""
    configs = {}
    tasks = []
    for identifier, case in enumerate(cases):
        header, task = sv_checks(case, core).split("task automatic check_retire", 1)
        for line in header.splitlines():
            match = re.fullmatch(r"localparam (.+?) (\w+) = (.+);", line)
            if match is None:
                raise ValueError(f"unexpected vector declaration: {line!r}")
            kind, name, value = match.groups()
            if name not in configs:
                configs[name] = (kind, [])
            assert configs[name][0] == kind
            configs[name][1].append(value)
        tasks.append(f"task automatic check_retire_{identifier}" + task)
    lines = ["function automatic integer selected_case();",
             "  integer identifier;",
             '  if (!$value$plusargs("VECTOR=%d", identifier))',
             '    $fatal(1, "missing vector identifier");',
             f"  if (identifier<0 || identifier>={len(cases)})",
             '    $fatal(1, "invalid vector identifier %0d", identifier);',
             "  return identifier;", "endfunction"]
    for name, (kind, values) in configs.items():
        lines += [f"function automatic {kind} config_{name}(input integer identifier);",
                  "  case (identifier)"]
        lines += [f"    {i}: return {v};" for i, v in enumerate(values)]
        lines += ['    default: $fatal(1, "invalid vector configuration");',
                  "  endcase", "endfunction",
                  f"{kind} {name} = config_{name}(selected_case());"]
    lines += tasks
    lines += ["task automatic check_retire(input integer step);",
              "  case (selected_case())"]
    lines += [f"    {i}: check_retire_{i}(step);" for i in range(len(cases))]
    lines += ['    default: $fatal(1, "invalid vector check");',
              "  endcase", "endtask", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", help="run only this YAML case")
    parser.add_argument("--vectors", type=Path, default=HERE / "tests.yaml",
                        help="YAML/JSON vector file (default: ver/tests.yaml)")
    parser.add_argument("--rtl", action="append", type=Path, default=[],
                        help="extra generated RTL source (repeatable)")
    parser.add_argument("--timed-word", action="store_true",
                        help="use TIMED_PROGRAM=1 and the physical word/bus wrapper")
    parser.add_argument("--hold-after-write", action="store_true",
                        help="also repeat each timed word case with HOLD after a pixel write")
    parser.add_argument("--simulator", choices=("verilator", "iverilog"), default="verilator",
                        help="simulation engine (default: verilator)")
    args = parser.parse_args()
    cases = load_cases(yaml.safe_load(args.vectors.read_text()))
    for case in cases:
        validate_case(case)
    selected = [case for case in cases if args.case in (None, case["name"])]
    if not selected:
        parser.error(f"unknown case {args.case!r}")
    if args.timed_word and any(case.get("expected_requests", -1) >= 0 for case in selected):
        parser.error("expected_requests counts raw fields; it cannot check physical word cycles")
    if args.hold_after_write and not args.timed_word:
        parser.error("--hold-after-write requires --timed-word")
    core = "u_cpu.u_core" if args.timed_word else "u_cpu"
    defines = ["-DJTTMS10_TIMED_WORD"] if args.timed_word else []
    hdl = HERE.parent / "hdl"
    build = HERE / "build"
    if not (build / "tms10_param.vh").exists() or not (build / "tms10.vh").exists():
        parser.error("generated microcode headers are missing; run ver/build.sh first")
    if (HERE.parent / "ucode/gfx.yaml").exists() and not (build / "tms10_gfx.uc").exists():
        parser.error("generated graphics microcode is missing; run ver/build.sh first")
    sources = sorted(hdl.glob("*.v")) + sorted(hdl.glob("*.sv")) + args.rtl
    if not any(path.stem == "jttms10" for path in sources):
        parser.error("jttms10 RTL is missing; run the module build first")

    with tempfile.TemporaryDirectory(prefix="jttms10-vectors-") as temp:
        work = Path(temp)
        for name in ("tms10.uc", "tms10_gfx.uc", "tms10_dispatch.hex"):
            if (build / name).exists():
                shutil.copyfile(build / name, work / name)
        executable = None
        if args.simulator == "verilator":
            (work / "expected.svh").write_text(suite_checks(selected, core))
            command = ["verilator", "--binary", "--timing", "--top-module", "test",
                       "--timescale-override", "1ns/1ps", "-Wno-EOFNEWLINE", "-j", "4",
                       "--Mdir", str(work / "obj"), "-I"+str(work),
                       "-I"+str(hdl), "-I"+str(build), "-I"+str(HERE), *defines, str(HERE / "test.sv"),
                       *[str(source.resolve()) for source in sources]]
            result = subprocess.run(command, cwd=work, capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            executable = [str(work / "obj/Vtest")]
        for identifier, case in enumerate(selected):
            (work / "program.mem").write_text(
                "".join(f"{word:04x}\n" for word in case["words"]))
            (work / "memory_init.txt").write_text(memory_init(case))
            (work / "vector_init.txt").write_text(vector_init(case))
            if args.simulator == "iverilog":
                (work / "expected.svh").write_text(sv_checks(case, core))
                binary = work / "sim.vvp"
                compile_cmd = ["iverilog", "-g2012", "-s", "test", "-I", str(work),
                               "-I", str(hdl), "-I", str(build), "-I", str(HERE),
                               *defines, "-o", str(binary), str(HERE / "test.sv")]
                compile_cmd.extend(str(source.resolve()) for source in sources)
                subprocess.run(compile_cmd, check=True, cwd=work)
                executable = ["vvp", str(binary)]
            for hold in ((False, True) if args.hold_after_write else (False,)):
                hold_args = ["+HOLD_AFTER_WRITE=1"] if hold else []
                tag = case['name'] + (' HOLD' if hold else '')
                result = subprocess.run([*executable, f"+VECTOR={identifier}", *hold_args], cwd=work,
                                        capture_output=True, text=True, timeout=30)
                if result.returncode or "TEST_RESULT: PASS" not in result.stdout:
                    print(f"{tag}: FAIL\n{result.stdout}{result.stderr}")
                    raise SystemExit(1)
                print(f"{tag}: PASS", flush=True)



if __name__ == "__main__":
    main()
