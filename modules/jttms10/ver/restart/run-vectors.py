#!/usr/bin/env python3
"""Run selected unchanged jttms10/ver/tests.yaml programs with Verilator.

This adapts the existing architectural bench to the current scalar cache ports
without changing its testbench, YAML, or generated expectations in place.
Each selected case gets an isolated source/build directory under --out.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

sys.dont_write_bytecode = True
VER_DIR = Path(__file__).resolve().parents[1]
MODULE_DIR = VER_DIR.parent
REPO_DIR = MODULE_DIR.parents[1]
sys.path.insert(0, str(VER_DIR))
from vectors import load_cases, memory_init, sv_checks, validate_case, vector_init


def adapt_bench(source: str) -> str:
    replacements = [
        (".rst(rst), .clk(clk), .cen(cen),",
         ".rst(rst), .clk(clk), .cen(cen), .cache_flush(1'b0),"),
        (".mem_rdata(mem_rdata), .mem_ack(mem_ack),",
         ".mem_rdata(mem_rdata), .mem_ack(mem_ack),\n"
         "        .peek_req(), .peek_consume(), .peek_ack(1'b0),\n"
         "        .peek_hit(1'b0), .peek_data(16'd0),"),
    ]
    for old, new in replacements:
        if source.count(old) != 1:
            raise ValueError(f"expected one adapter point: {old!r}")
        source = source.replace(old, new)
    return source


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", help="case from unchanged tests.yaml; repeatable")
    parser.add_argument("--out", type=Path,
                        default=Path(os.environ.get("TMPDIR", "/tmp")) / "jttms10-restart-vectors")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    out = args.out.resolve()

    source_yaml = VER_DIR / "tests.yaml"
    cases = load_cases(yaml.safe_load(source_yaml.read_text()))
    names = [case["name"] for case in cases]
    if len(names) != len(set(names)):
        parser.error("tests.yaml contains duplicate case names")
    for case in cases:
        validate_case(case)
    selected_names = args.case or ["illegal_opcode_traps_to_vector_thirty"]
    selected = [case for case in cases if case["name"] in selected_names]
    missing = set(selected_names) - {case["name"] for case in selected}
    if missing:
        parser.error(f"unknown case(s): {', '.join(sorted(missing))}")

    env = os.environ.copy()
    env["JTROOT"] = str(REPO_DIR)
    env["MODULES"] = str(REPO_DIR / "modules")
    generated = out / "generated"
    subprocess.run([str(MODULE_DIR / "ver" / "build.sh"), str(generated)],
                   cwd=REPO_DIR, env=env, check=True)

    rtl = MODULE_DIR / "hdl"
    sources = sorted(rtl.glob("*.v")) + sorted(rtl.glob("*.sv"))
    original_bench = VER_DIR / "test.sv"
    adapted = adapt_bench(original_bench.read_text())
    results = []
    for case in selected:
        work = out / case["name"]
        work.mkdir(parents=True, exist_ok=True)
        (work / "program.mem").write_text("".join(f"{word:04x}\n" for word in case["words"]))
        (work / "memory_init.txt").write_text(memory_init(case))
        (work / "vector_init.txt").write_text(vector_init(case))
        (work / "expected.svh").write_text(sv_checks(case))
        (work / "test.sv").write_text(adapted)
        for name in ("tms10.uc", "tms10_gfx.uc", "tms10_dispatch.hex"):
            path = generated / name
            if path.exists():
                shutil.copyfile(path, work / name)
        obj = work / "obj_dir"
        command = ["verilator", "--quiet", "--binary", "--timing", "--top-module", "test",
                   "-Wno-fatal", f"-I{work}", f"-I{rtl}", f"-I{generated}", "--Mdir", str(obj),
                   str(work / "test.sv"), *(str(path) for path in sources)]
        compiled = subprocess.run(command, cwd=work, text=True, capture_output=True)
        (work / "build.log").write_text(compiled.stdout + compiled.stderr)
        if compiled.returncode:
            print(f"{case['name']}: COMPILE_FAIL (see {work / 'build.log'})")
            return compiled.returncode
        result = subprocess.run([str(obj / "Vtest")], cwd=work, text=True, capture_output=True)
        output = result.stdout + result.stderr
        (work / "run.log").write_text(output)
        passed = result.returncode == 0 and "TEST_RESULT: PASS" in result.stdout
        results.append({
            "case": case["name"], "passed": passed,
            "cli_exit_status": result.returncode,
            "source_yaml_sha256": sha256(source_yaml),
            "source_bench_sha256": sha256(original_bench),
            "adapted_bench_sha256": sha256(work / "test.sv"),
            "generated_rom_sha256": {name: sha256(generated / name)
                                     for name in ("tms10.uc", "tms10_gfx.uc", "tms10_dispatch.hex")
                                     if (generated / name).exists()},
            "command": command,
        })
        print(f"{case['name']}: {'PASS' if passed else 'FAIL'}")
        if not passed:
            print(output)
            break

    result_path = out / "result.json"
    result_path.write_text(json.dumps({
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO_DIR,
                                                    text=True).strip(),
        "cases": results,
    }, indent=2) + "\n")
    return 0 if len(results) == len(selected) and all(item["passed"] for item in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
