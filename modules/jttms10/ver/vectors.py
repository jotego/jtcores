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
MEMORY_BITS = 1024 * 16


def load_cases(source):
    """Expand the short-branch truth table into independent YAML programs."""
    cases = list(source["cases"])
    seen_codes = set()
    for row in source.get("short_branch_conditions", []):
        code = row["code"]
        if not isinstance(code, int) or not 1 <= code <= 15 or code in seen_codes:
            raise ValueError(f"invalid/repeated short branch condition {code!r}")
        seen_codes.add(code)
        name = f"short_branch_{row['mnemonic'].lower()}"
        taken, not_taken = row["taken_st"], row["not_st"]
        check_uint(taken, 32, f"{name}.taken_st")
        check_uint(not_taken, 32, f"{name}.not_st")
        branch = 0xC002 | (code << 8)
        cases.append({
            "name": name, "entry": 0x1000,
            "words": [0x09E0, taken & 0xFFFF, taken >> 16, 0x01A0,
                      branch, 0x1BE1, 0x1BC1,
                      0x09E0, not_taken & 0xFFFF, not_taken >> 16,
                      0x01A0, branch, 0x1821],
            "checks": [
                {"after": 0x1000, "pc": 0x1030, "regs": {"A0": taken}},
                {"after": 0x1030, "pc": 0x1040, "st": taken},
                {"after": 0x1040, "pc": 0x1070, "st": taken},
                {"after": 0x1070, "pc": 0x10A0, "regs": {"A0": not_taken}},
                {"after": 0x10A0, "pc": 0x10B0, "st": not_taken},
                {"after": 0x10B0, "pc": 0x10C0, "st": not_taken},
                {"after": 0x10C0, "pc": 0x10D0,
                 "regs": {"A1": 1}, "st": not_taken},
            ],
        })
    return cases


def check_uint(value, bits, where):
    if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value < 1 << bits:
        raise ValueError(f"{where}: expected unsigned {bits}-bit integer, got {value!r}")


def opcode_at(case, address):
    """Opcode word from the program or a separately initialized code block."""
    for block in [{"at": case["entry"], "words": case["words"]},
                  *case.get("mem", [])]:
        offset = address - block["at"]
        if offset >= 0 and offset % 16 == 0 and offset // 16 < len(block["words"]):
            return block["words"][offset // 16]
    raise ValueError(f"{case['name']}: no opcode word at {address:#x}")


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
    if entry + 16 * len(words) > MEMORY_BITS:
        raise ValueError(f"{name}.words exceed test memory")
    for number, target in case.get("vectors", {}).items():
        if not isinstance(number, int) or isinstance(number, bool) or not 1 <= number <= 31:
            raise ValueError(f"{name}.vectors: trap number must be 1..31 (0 is reset)")
        check_uint(target, 32, f"{name}.vectors[{number}]")
        if (target & ~15) + 16 > MEMORY_BITS:
            raise ValueError(f"{name}.vectors[{number}] target outside test memory")
    for i, block in enumerate(case.get("mem", [])):
        tag = f"{name}.mem[{i}]"
        at = block["at"]
        check_uint(at, 32, f"{tag}.at")
        if at & 15:
            raise ValueError(f"{tag}.at must be 16-bit-word aligned")
        data = block["words"]
        if not isinstance(data, list) or not data or at + 16 * len(data) > MEMORY_BITS:
            raise ValueError(f"{tag}.words must fit test memory")
        if at < entry + 16 * len(words) and at + 16 * len(data) > entry:
            raise ValueError(f"{tag} overlaps program words")
        for j, word in enumerate(data):
            check_uint(word, 16, f"{tag}.words[{j}]")
    # The pinned reference memory target aliases nonzero high trap vectors
    # into its top 62 low-memory words. Reject low-memory overlap so both
    # benches observe the same independent vector contents.
    regions = [(entry, entry + 16 * len(words))] + [
        (block["at"], block["at"] + 16 * len(block["words"]))
        for block in case.get("mem", [])
    ]
    for number in case.get("vectors", {}):
        low_alias = (0xFFFFFFE0 - 32 * number) & (MEMORY_BITS - 1)
        if any(start < low_alias + 32 and low_alias < end
               for start, end in regions):
            raise ValueError(f"{name}.vectors[{number}] overlaps reference low-memory alias")
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
        try:
            opcode_at(case, check["after"])
        except ValueError as error:
            raise ValueError(f"{tag}.after is outside loaded memory") from error
        if check["after"] in seen:
            raise ValueError(f"{tag}.after repeats an opcode address")
        seen.add(check["after"])
        if not any(field in check for field in ("regs", "flags", "st", "mem")):
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
        for j, field in enumerate(check.get("mem", [])):
            mtag = f"{tag}.mem[{j}]"
            address = field["addr"]
            size = field["size"]
            check_uint(address, 32, f"{mtag}.addr")
            if not isinstance(size, int) or isinstance(size, bool) or not 1 <= size <= 32:
                raise ValueError(f"{mtag}.size must be 1..32 bits")
            if address + size > MEMORY_BITS:
                raise ValueError(f"{mtag} exceeds test memory")
            check_uint(field["value"], size, f"{mtag}.value")
    if case.get("expect_fault"):
        check_uint(case["fault_ir"], 16, f"{name}.fault_ir")
    if "pause_on_ack" in case and not isinstance(case["pause_on_ack"], bool):
        raise ValueError(f"{name}.pause_on_ack must be a boolean")
    if "expected_requests" in case:
        check_uint(case["expected_requests"], 16, f"{name}.expected_requests")
    if "pixel_size" in case:
        if isinstance(case["pixel_size"], bool) or case["pixel_size"] not in (1, 2, 4, 8, 16):
            raise ValueError(f"{name}.pixel_size must be 1, 2, 4, 8 or 16")
    if "convdp" in case:
        check_uint(case["convdp"], 16, f"{name}.convdp")
    if "reference_checks" in case or "reference_divergence" in case:
        reason = case.get("reference_divergence")
        alternate = case.get("reference_checks")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"{name}: reference_checks require a divergence reason")
        if not isinstance(alternate, list) or len(alternate) != len(checks):
            raise ValueError(f"{name}: reference_checks must cover every retire")
        if alternate == checks:
            raise ValueError(f"{name}: reference_checks contain no divergence")
        if [step["after"] for step in alternate] != [step["after"] for step in checks]:
            raise ValueError(f"{name}: reference_checks must follow the primary opcode stream")
        reference_case = {key: value for key, value in case.items()
                          if key not in ("reference_checks", "reference_divergence")}
        reference_case["checks"] = alternate
        validate_case(reference_case)


def sv_checks(case):
    """Generate only assertions; the bench owns bus timing and reset."""
    lines = [f"localparam logic [31:0] ENTRY = 32'h{case['entry']:08x};",
             f"localparam int EXPECTED_RETIRES = {len(case['checks'])};",
             f"localparam bit EXPECT_FAULT = 1'b{int(bool(case.get('expect_fault')))};",
             f"localparam logic [15:0] FAULT_IR = 16'h{case.get('fault_ir', 0):04x};",
             f"localparam bit PAUSE_ON_ACK = 1'b{int(bool(case.get('pause_on_ack')))};",
             f"localparam int EXPECTED_REQUESTS = {case.get('expected_requests', -1)};",
             f"localparam logic [15:0] PIXEL_SIZE = 16'h{case.get('pixel_size', 16):04x};",
             f"localparam logic [15:0] CONVDP = 16'h{case.get('convdp', 0x14):04x};",
             "task automatic check_retire(input integer step);",
             "  case (step)"]
    for i, check in enumerate(case["checks"]):
        tag = f"{case['name']} step {i} opcode @{check['after']:08x}"
        word = opcode_at(case, check["after"])
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
        for field in check.get("mem", []):
            lines.append(
                f"      if (read_field(32'h{field['addr']:08x}, 6'd{field['size']}) "
                f"!== 32'h{field['value']:08x}) "
                f"$fatal(1, \"{tag}: memory @{field['addr']:08x} size {field['size']} %h\", "
                f"read_field(32'h{field['addr']:08x}, 6'd{field['size']}));"
            )
        lines.append("    end")
    lines.extend(["    default: $fatal(1, \"unexpected retire step %0d\", step);",
                  "  endcase", "endtask", ""])
    return "\n".join(lines)


def memory_init(case):
    """ASCII input for both benches: block address/count followed by words."""
    return "".join(
        f"{block['at']:08x} {len(block['words'])} "
        + " ".join(f"{word:04x}" for word in block["words"]) + "\n"
        for block in case.get("mem", [])
    )


def vector_init(case):
    """Trap-number/target pairs; trap zero shares the reset vector."""
    return "".join(f"{number} {target:08x}\n"
                   for number, target in sorted(case.get("vectors", {}).items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", nargs="?", help="one case name; default: all")
    parser.add_argument("--out", type=Path, help="write .mem and .json files here")
    args = parser.parse_args()
    source = yaml.safe_load((HERE / "tests.yaml").read_text())
    cases = load_cases(source)
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
            base.with_suffix(".data").write_text(memory_init(case))
            base.with_suffix(".vectors").write_text(vector_init(case))
            base.with_suffix(".json").write_text(json.dumps({
                "entry": case["entry"], "reset_vector_addr": 0xFFFFFFE0,
                "mem": case.get("mem", []),
                "vectors": case.get("vectors", {}),
                "checks": case["checks"],
                "reference_checks": case.get("reference_checks"),
                "reference_divergence": case.get("reference_divergence"),
                "expect_fault": case.get("expect_fault", False),
                "fault_ir": case.get("fault_ir"),
                "pause_on_ack": case.get("pause_on_ack", False),
                "expected_requests": case.get("expected_requests")
            }, indent=2) + "\n")
            base.with_suffix(".svh").write_text(sv_checks(case))
    print("validated:", ", ".join(case["name"] for case in selected))


if __name__ == "__main__":
    main()
