#!/usr/bin/env python3
"""Render the short stageB test program from the frozen TI timing fixtures."""
import hashlib
import importlib
import json
import os
import subprocess
import sys
from pathlib import Path


ORACLE_REV = "9a17778b941dce89328316ee3e8f7f0a4bd14923"
MASK32 = (1 << 32) - 1
INITIAL_ST = 0xD0000810


def frozen_module(repo: Path, revision: str, path: str, out: Path) -> tuple[Path, str]:
    source = subprocess.check_output(["git", "-C", str(repo), "show", f"{revision}:{path}"])
    target = out / "frozen-oracle" / Path(path).name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source)
    return target, hashlib.sha256(source).hexdigest()


def selected_cases(scalar):
    shifts = list(scalar.shift_cases())
    names = [
        "sll_k_mixed_n00_hit", "sll_k_mixed_n01_hit", "sll_k_mixed_n31_hit",
        "sra_k_mixed_n00_hit", "sra_k_mixed_n01_hit", "sra_k_mixed_n31_hit",
        "srl_k_mixed_n00_hit", "srl_k_mixed_n01_hit", "srl_k_mixed_n31_hit",
        "rl_k_mixed_n00_hit", "rl_k_mixed_n01_hit", "rl_k_mixed_n31_hit",
        "sll_rr_alias_n01_hit", "sra_rr_alias_n31_hit",
        "sla_k_guide_cccccccc_n03_hit",
    ]
    by_name = {case["name"]: case for case in shifts}
    selected = [by_name[name] for name in names]
    lmo = {case["name"]: case for case in scalar.lmo_cases()}
    selected.extend(lmo[name] for name in (
        "lmo_separate_80000000_hit", "lmo_separate_00000001_hit",
        "lmo_separate_00000000_hit"))
    return selected


def render(repo: Path, out: Path) -> dict:
    oracle_file, oracle_sha = frozen_module(
        repo, ORACLE_REV, "modules/jttms10/ver/timing/oracle.py", out)
    cases_file, cases_sha = frozen_module(
        repo, ORACLE_REV, "modules/jttms10/ver/timing/scalar_cases.py", out)
    sys.path.insert(0, str(oracle_file.parent))
    oracle = importlib.import_module("oracle")
    scalar = importlib.import_module("scalar_cases")
    selected = selected_cases(scalar)
    if len(selected) != 18:
        raise RuntimeError(f"expected 18 directed cases, got {len(selected)}")

    # TI's published SLA example is a literal check on the copied fixture.
    guide = (0xCCCCCCCC, 3, 0x66666660, 0x1)
    if guide not in scalar.TI_SLA_EXAMPLES:
        raise RuntimeError("frozen scalar oracle no longer contains TI SLA p.12-239 example")

    words: dict[int, int] = {}
    index = 0x100

    def emit(value: int) -> int:
        nonlocal index
        at = index
        words[index] = value & 0xFFFF
        index += 1
        return at

    def movi_long(reg: int, value: int):
        emit(0x09E0 | reg)  # MOVI IL Rd
        emit(value & 0xFFFF)
        emit((value >> 16) & 0xFFFF)

    # One register per destination keeps all tested results independently
    # inspectable. LMO source registers use B2..B4 and are checked unchanged.
    dest_regs = list(range(15))
    source_regs = [18, 19, 20]
    initial_values = {}
    case_info = []
    running_st = INITIAL_ST
    lmo_index = 0

    for n, case in enumerate(selected):
        name = case["name"]
        if case["coverage_id"] == "LMO_RR":
            dest = 23 + lmo_index  # B7..B9; keep source and destination in B file.
            src = source_regs[lmo_index]
            lmo_index += 1
            value = case["conditions"]["value"]
            initial_values[dest] = case["regs"][0]
            initial_values[src] = value
            opcode = ((case["opcode"] & ~0x01FF) |
                      ((src & 0x0F) << 5) | 0x10 | (dest & 0x0F))
            result = 32 - value.bit_length() if value else 0
            expected_st = (running_st & ~(1 << 29)) | ((1 << 29) if value == 0 else 0)
            states = 1  # TI TMS34010 User's Guide, p.12-108.
        else:
            dest = dest_regs[n]
            src = dest if case["conditions"]["form"] == "RR" else None
            value = case["regs"][0]
            initial_values[dest] = value
            if src is None:
                opcode = (case["opcode"] & ~0x1F) | dest
            else:
                opcode = ((case["opcode"] & ~0x01FF) |
                          ((src & 0x0F) << 5) | (dest & 0x10) | (dest & 0x0F))
            operation = case["conditions"]["operation"]
            count = case["conditions"]["count"]
            result, expected_st = scalar.shift_result(operation, value, count, running_st)
            if name == "sla_k_guide_cccccccc_n03_hit":
                result = guide[2]
                expected_st = (guide[3] << 28) | (running_st & 0x0FFFFFFF)
                if result != scalar.shift_result(operation, value, count, running_st)[0]:
                    raise RuntimeError("TI SLA literal disagrees with independent arithmetic model")
            states = oracle.shift_states(operation, count=count, cache_disabled=False)

        entry = {
            "case_id": name,
            "opcode": opcode,
            "instruction_pc": 0,
            "retire_pc": 0,
            "states": states,
            "expected_inclks": states * oracle.INPUT_CLOCKS_PER_STATE,
            "dest_reg": dest,
            "source_reg": src,
            "input": value,
            "expected_result": result & MASK32,
            "expected_st": expected_st & MASK32,
            "reference": case["citation"],
        }
        case_info.append(entry)
        running_st = expected_st & MASK32

    # Seed status from B10, initialize tested registers, then install the
    # status after setup MOVIs have finished.
    movi_long(26, INITIAL_ST)  # B10 is a stable scratch source for PUTST.
    for reg, value in sorted(initial_values.items()):
        movi_long(reg, value)
    emit(0x01BA)  # PUTST B10
    emit(0x0300)  # Resident NOP lead-in; its retirement starts the interval.
    stream_start_index = index
    for entry in case_info:
        entry["instruction_pc"] = emit(entry["opcode"]) << 4
        entry["retire_pc"] = entry["instruction_pc"] + 0x10
    branch_pc_index = index
    branch_delta = 0x100 - (branch_pc_index + 1)  # JRUC uses post-instruction PC.
    branch_opcode = 0xCF00 | (branch_delta & 0xFF)
    emit(branch_opcode)
    stream_start = stream_start_index << 4

    header = [
        f"stageb_case_count={len(case_info)};",
        f"stageb_stream_pc=32'h{stream_start:08x};",
        "stageb_setup_pc=32'h00001000;",
        "stageb_timer_nop_ir=16'h0300;",
        f"stageb_branch_pc=32'h{branch_pc_index << 4:08x};",
        f"stageb_branch_ir=16'h{branch_opcode:04x};",
    ]
    for address, value in sorted(words.items()):
        header.append(f"mem['h{address:03x}]=16'h{value:04x};")
    for i, entry in enumerate(case_info):
        header.extend([
            f"expected_pc[{i}]=32'h{entry['retire_pc']:08x};",
            f"expected_ir[{i}]=16'h{entry['opcode']:04x};",
            f"expected_cycles[{i}]={entry['expected_inclks']};",
            f"expected_src[{i}]=6'd{entry['source_reg'] if entry['source_reg'] is not None and entry['source_reg'] != entry['dest_reg'] else 63};",
            f"expected_dest[{i}]=6'd{entry['dest_reg']};",
            f"expected_src_value[{i}]=32'h{entry['input']:08x};",
            f"expected_result[{i}]=32'h{entry['expected_result']:08x};",
            f"expected_st[{i}]=32'h{entry['expected_st']:08x};",
        ])

    (out / "stageb_vectors.svh").write_text("\n".join(header) + "\n")
    provenance = {
        "oracle_revision": ORACLE_REV,
        "oracle_sha256": oracle_sha,
        "scalar_cases_sha256": cases_sha,
        "input_clocks_per_state": oracle.INPUT_CLOCKS_PER_STATE,
        "timing_rule_source": "frozen 9a17778 modules/jttms10/ver/timing/oracle.py; TI SPVU001A §1.3.1.5 p.1-7",
        "shift_states": "frozen shift_states(): SLA=3, others=1 for all counts; printed operation pages 12-234..246",
        "lmo_states": "TI SPVU001A printed p.12-108; one state as recorded by frozen scalar_cases.py",
        "sla_literal": "TI SPVU001A printed p.12-239: CCCCCCCC shifted left 3 -> 66666660, NCZV=0001",
        "cases": case_info,
    }
    (out / "stageb-cases.json").write_text(json.dumps(provenance, indent=2) + "\n")
    return provenance


def main():
    repo = Path(__file__).resolve().parents[4]
    out = Path(os.environ["STAGEB_OUT"]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    render(repo, out)


if __name__ == "__main__":
    main()
