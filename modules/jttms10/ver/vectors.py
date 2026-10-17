#!/usr/bin/env python3
"""Validate bring-up vectors and emit memory/checkpoint files for a CPU bench.

Usage: python3 vectors.py [case-name] [--out DIR]
Requires PyYAML. Addresses in the YAML and output JSON are TMS34010 bit
addresses; each line of a .mem file is one 16-bit instruction word.
"""

import argparse
import json
import re
from pathlib import Path

import yaml


HERE = Path(__file__).resolve().parent
REG = re.compile(r"[AB](?:[0-9]|1[0-5])\Z")
FLAGS = {"N", "C", "Z", "V"}


def check_uint(value, bits, where):
    if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value < 1 << bits:
        raise ValueError(f"{where}: expected unsigned {bits}-bit integer, got {value!r}")


def validate_case(case):
    name = case["name"]
    if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
        raise ValueError(f"invalid case name: {name!r}")
    entry = case["entry"]
    check_uint(entry, 32, f"{name}.entry")
    if entry & 15:
        raise ValueError(f"{name}.entry must be instruction-word aligned")
    words = case["words"]
    if not isinstance(words, list) or not words:
        raise ValueError(f"{name}.words must be a nonempty list")
    for i, word in enumerate(words):
        check_uint(word, 16, f"{name}.words[{i}]")
    checks = case["checks"]
    if not isinstance(checks, list) or not checks:
        raise ValueError(f"{name}.checks must be a nonempty list")
    seen = set()
    for i, check in enumerate(checks):
        tag = f"{name}.checks[{i}]"
        for key in ("after", "pc"):
            check_uint(check[key], 32, f"{tag}.{key}")
            if check[key] & 15:
                raise ValueError(f"{tag}.{key} must be instruction-word aligned")
        if check["after"] not in range(entry, entry + 16 * len(words), 16):
            raise ValueError(f"{tag}.after is outside the loaded program")
        if check["after"] in seen:
            raise ValueError(f"{tag}.after repeats an opcode address")
        seen.add(check["after"])
        if "regs" not in check and "flags" not in check and "st" not in check:
            raise ValueError(f"{tag} has no architectural assertion")
        for reg, value in check.get("regs", {}).items():
            if not REG.fullmatch(reg):
                raise ValueError(f"{tag}: invalid register {reg!r}")
            check_uint(value, 32, f"{tag}.regs.{reg}")
        for flag, value in check.get("flags", {}).items():
            if flag not in FLAGS or value not in (0, 1):
                raise ValueError(f"{tag}: invalid flag/value {flag}={value!r}")
        if "st" in check:
            check_uint(check["st"], 32, f"{tag}.st")
    if case.get("expect_fault"):
        check_uint(case["fault_ir"], 16, f"{name}.fault_ir")
    if "pause_on_ack" in case and not isinstance(case["pause_on_ack"], bool):
        raise ValueError(f"{name}.pause_on_ack must be a boolean")
    if "expected_requests" in case:
        check_uint(case["expected_requests"], 16, f"{name}.expected_requests")


def sv_checks(case):
    """Generate only assertions; the bench owns bus timing and reset."""
    lines = [f"localparam logic [31:0] ENTRY = 32'h{case['entry']:08x};",
             f"localparam int EXPECTED_RETIRES = {len(case['checks'])};",
             f"localparam bit EXPECT_FAULT = 1'b{int(bool(case.get('expect_fault')))};",
             f"localparam logic [15:0] FAULT_IR = 16'h{case.get('fault_ir', 0):04x};",
             f"localparam bit PAUSE_ON_ACK = 1'b{int(bool(case.get('pause_on_ack')))};",
             f"localparam int EXPECTED_REQUESTS = {case.get('expected_requests', -1)};",
             "task automatic check_retire(input integer step);",
             "  case (step)"]
    for i, check in enumerate(case["checks"]):
        tag = f"{case['name']} step {i} opcode @{check['after']:08x}"
        word = case["words"][(check["after"] - case["entry"]) // 16]
        lines.extend([f"    {i}: begin",
                      f"      if (ir !== 16'h{word:04x}) $fatal(1, \"{tag}: IR %h\", ir);",
                      f"      if (pc !== 32'h{check['pc']:08x}) $fatal(1, \"{tag}: PC %h\", pc);"])
        for reg, value in check.get("regs", {}).items():
            index = int(reg[1:])
            physical = 15 if index == 15 else (16 if reg[0] == "B" else 0) + index
            lines.append(
                f"      if (u_cpu.u_regs.ram0[{physical}] !== 32'h{value:08x}) "
                f"$fatal(1, \"{tag}: {reg} %h\", u_cpu.u_regs.ram0[{physical}]);"
            )
        for flag, value in check.get("flags", {}).items():
            bit = {"N": 31, "C": 30, "Z": 29, "V": 28}[flag]
            lines.append(
                f"      if (st[{bit}] !== 1'b{value}) "
                f"$fatal(1, \"{tag}: {flag} %b\", st[{bit}]);"
            )
        if "st" in check:
            lines.append(
                f"      if (st !== 32'h{check['st']:08x}) "
                f"$fatal(1, \"{tag}: ST %h\", st);"
            )
        lines.append("    end")
    lines.extend(["    default: $fatal(1, \"unexpected retire step %0d\", step);",
                  "  endcase", "endtask", ""])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", nargs="?", help="one case name; default: all")
    parser.add_argument("--out", type=Path, help="write .mem and .json files here")
    args = parser.parse_args()
    source = yaml.safe_load((HERE / "tests.yaml").read_text())
    cases = source["cases"]
    names = [case["name"] for case in cases]
    if len(names) != len(set(names)):
        raise ValueError("duplicate case names")
    for case in cases:
        validate_case(case)
    selected = [case for case in cases if args.case in (None, case["name"])]
    if not selected:
        parser.error(f"unknown case {args.case!r}; choose one of {', '.join(names)}")
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        for case in selected:
            base = args.out / case["name"]
            base.with_suffix(".mem").write_text(
                "".join(f"{word:04x}\n" for word in case["words"])
            )
            base.with_suffix(".json").write_text(json.dumps({
                "entry": case["entry"], "reset_vector_addr": 0xFFFFFFE0,
                "checks": case["checks"],
                "expect_fault": case.get("expect_fault", False),
                "fault_ir": case.get("fault_ir"),
                "pause_on_ack": case.get("pause_on_ack", False),
                "expected_requests": case.get("expected_requests")
            }, indent=2) + "\n")
            base.with_suffix(".svh").write_text(sv_checks(case))
    print("validated:", ", ".join(case["name"] for case in selected))


if __name__ == "__main__":
    main()
