#!/usr/bin/env python3
"""Run the YAML scalar programs against the pre-existing TMS34010 core.

The reference is the untouched modules/tms34010 submodule at the pinned
commit below. Comparison is at architectural retirement, not by clock cycle.
The expected illegal-opcode and clock-enable protocol cases are excluded.
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

sys.dont_write_bytecode = True
from vectors import HERE, load_cases, memory_init, opcode_at, validate_case, vector_init


REFERENCE_SHA = "29bcb384ec3dba892ea54db2ee92b38ae395d575"
REFERENCE = HERE.parents[1] / "tms34010"


def check_line(check, case):
    opcode = opcode_at(case, check["after"])
    mask = 0
    value = 0
    if "st" in check:
        mask = 0xFFFFFFFF
        value = check["st"]
    for flag, bit in {"N": 31, "C": 30, "Z": 29, "V": 28}.items():
        if flag in check.get("flags", {}):
            mask |= 1 << bit
            value = (value & ~(1 << bit)) | (check["flags"][flag] << bit)
    regs = {}
    for reg, reg_value in check.get("regs", {}).items():
        index = int(reg[1:])
        physical = 15 if index == 15 else (16 if reg[0] == "B" else 0) + index
        regs[physical] = reg_value
    memory = check.get("mem", [])
    fields = [f"{check['after']:08x}", f"{check['pc']:08x}",
              f"{opcode:04x}", f"{mask:08x}", f"{value:08x}",
              str(len(regs)), str(len(memory))]
    for physical, reg_value in sorted(regs.items()):
        fields.extend([str(physical), f"{reg_value:08x}"])
    for field in memory:
        fields.extend([f"{field['addr']:08x}", str(field["size"]),
                       f"{field['value']:08x}"])
    return " ".join(fields) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", help="run one scalar case")
    args = parser.parse_args()
    actual_sha = subprocess.check_output(
        ["git", "-C", str(REFERENCE), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual_sha != REFERENCE_SHA:
        parser.error(f"reference submodule is {actual_sha}, expected {REFERENCE_SHA}")
    dirty = subprocess.check_output(
        ["git", "-C", str(REFERENCE), "status", "--porcelain"], text=True
    ).strip()
    if dirty:
        parser.error("reference submodule has local changes; pinned comparison requires a clean tree")
    cases = load_cases(yaml.safe_load((HERE / "tests.yaml").read_text()))
    for case in cases:
        validate_case(case)
    scalar = [case for case in cases
              if not case.get("expect_fault") and not case.get("pause_on_ack")]
    selected = [case for case in scalar if args.case in (None, case["name"])]
    if not selected:
        parser.error("case is unknown or specific to illegal-opcode/clock-enable testing")

    rtl = REFERENCE / "rtl"
    sources = [rtl / "tms34010_pkg.sv"]
    sources.extend(source for source in sorted(rtl.rglob("*.sv"))
                   if source != sources[0])
    sources.extend(sorted((REFERENCE / "sim" / "models").glob("*.sv")))
    sources.append(HERE / "reference_test.sv")

    with tempfile.TemporaryDirectory(prefix="jttms10-reference-") as temp:
        work = Path(temp)
        obj = work / "obj"
        subprocess.run(["verilator", "--binary", "--timing", "--quiet-build",
                        "-Wno-fatal", "-Wno-TIMESCALEMOD", "--top-module",
                        "reference_test", "--Mdir", str(obj),
                        *(str(source) for source in sources)],
                       check=True, cwd=work)
        for case in selected:
            checks = case.get("reference_checks", case["checks"])
            (work / "program.mem").write_text(
                "".join(f"{word:04x}\n" for word in case["words"])
            )
            (work / "memory_init.txt").write_text(memory_init(case))
            (work / "vector_init.txt").write_text(vector_init(case))
            (work / "checks.txt").write_text(
                "".join(check_line(check, case)
                        for check in checks)
            )
            result = subprocess.run(
                [str(obj / "Vreference_test"), f"+entry={case['entry']:x}",
                 f"+count={len(checks)}"], cwd=work,
                capture_output=True, text=True
            )
            if result.returncode or "TEST_RESULT: PASS" not in result.stdout:
                print(f"{case['name']}: FAIL\n{result.stdout}{result.stderr}")
                raise SystemExit(1)
            if "reference_divergence" in case:
                print(f"{case['name']}: KNOWN REFERENCE DIVERGENCE "
                      f"({REFERENCE_SHA[:12]}): {case['reference_divergence']}")
            else:
                print(f"{case['name']}: PASS (reference {REFERENCE_SHA[:12]})")


if __name__ == "__main__":
    main()
