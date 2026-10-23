#!/usr/bin/env python3
"""Reconcile the manifest against a separate UM0080 documented-key inventory."""
import csv
from pathlib import Path

HERE = Path(__file__).resolve().parent


def key(encoded):
    code = bytes.fromhex(encoded)
    if code[0] in (0xDD, 0xFD) and code[1] == 0xCB:
        return (code[0], 0xCB, code[3])
    if code[0] in (0xCB, 0xED, 0xDD, 0xFD):
        return tuple(code[:2])
    return (code[0],)


expected = {(op,) for op in range(256) if op not in (0xCB, 0xED, 0xDD, 0xFD)}
expected |= {(0xCB, op) for op in range(256) if op not in range(0x30, 0x38)}
ed = (0x40,0x48,0x50,0x58,0x60,0x68,0x78, 0x41,0x49,0x51,0x59,0x61,0x69,0x79,
      0x42,0x52,0x62,0x72,0x4a,0x5a,0x6a,0x7a, 0x43,0x53,0x63,0x73,0x4b,0x5b,0x6b,0x7b,
      0x44,0x45,0x4d,0x46,0x56,0x5e,0x47,0x4f,0x57,0x5f,0x67,0x6f,
      0xa0,0xa8,0xa1,0xa9,0xa2,0xaa,0xa3,0xab,0xb0,0xb8,0xb1,0xb9,0xb2,0xba,0xb3,0xbb)
expected |= {(0xed, op) for op in ed}
for prefix in (0xdd, 0xfd):
    ix = [0x21,0x22,0x2a,0x23,0x2b,0x09,0x19,0x29,0x39,0xe5,0xe1,0xe9,0xf9,0xe3,0x34,0x35,0x36]
    ix += [op for op in range(0x40,0x80) if op != 0x76 and (op & 7 == 6 or (op >> 3) & 7 == 6)]
    ix += [op for op in range(0x80,0xc0) if op & 7 == 6]
    expected |= {(prefix, op) for op in ix}
    expected |= {(prefix,0xcb,op) for op in range(256) if op & 7 == 6 and op not in range(0x30,0x38)}

rows = list(csv.DictReader((HERE / "manifest.csv").open()))
actual = {key(row["bytes"]) for row in rows}
labeled = {key(row["bytes"]) for row in rows if row["oracle_status"] == "documented"}
# Vector-emitted groups are actually scheduled by the `vectors.hex` runner.
# The excluded directed encodings and all variable paths must be explicitly
# present in the testbench's directed-case schedule below.
vector_groups = {"fixed", "cb", "indexed_cb", "alias"}
directed_exclusions = {"RETN", "RETI", "JP (HL)", "IX form $E9", "IY form $E9"}
executed = {key(row["bytes"]) for row in rows
            if row["oracle_status"] == "documented" and
            (row["run_group"] in vector_groups or
             (row["run_group"] == "directed" and row["instruction"] not in directed_exclusions))}
custom = {(0xE9,), (0xDD,0xE9), (0xFD,0xE9), (0xED,0x45), (0xED,0x4D), (0x76,)}
for row in rows:
    if row["oracle_status"] == "documented" and row["run_group"] in {"flow","branch","djnz","repeat","halt"}:
        custom.add(key(row["bytes"]))
executed |= custom
test = (HERE / "test.v").read_text()
required_schedule = (
    "run_flow_case(8'hc3", "run_flow_case(8'hcd", "run_flow_case(8'hc9",
    "run_flow_case(8'he9", "run_index_jump(8'hdd)", "run_index_jump(8'hfd)",
    "for(j=0;j<8;j=j+1) run_flow_case", "run_jr_unconditional();", "run_halt();",
    "run_return_from_nmi(8'h45)", "run_return_from_nmi(8'h4d)",
    "run_condition_case(0,j,0)", "run_condition_case(0,j,1)",
    "run_condition_case(i,j,0)", "run_condition_case(i,j,1)",
    "run_djnz(8'h00,1,8'hff)", "run_djnz(8'h01,0,8'h00)", "run_djnz(8'h02,1,8'h01)",
    "observe_repeat(8'hb0", "observe_repeat(8'hb8", "observe_repeat(8'hb1",
    "observe_repeat(8'hb9", "observe_repeat(8'hb2", "observe_repeat(8'hba",
    "observe_repeat(8'hb3", "observe_repeat(8'hbb",
    "observe_repeat(8'hb1,16'h0001,8'h55,0)", "observe_repeat(8'hb9,16'h0001,8'h66,0)")
missing_schedule = [token for token in required_schedule if token not in test]
missing = expected - actual
misclassified_missing = expected - labeled
misclassified_extra = labeled - expected
not_executed = expected - executed
if (len(expected), len(missing), len(misclassified_missing), len(misclassified_extra), len(not_executed),len(missing_schedule)) != (698, 0, 0, 0, 0, 0):
    raise SystemExit(f"UM0080 inventory mismatch: expected=698 missing={sorted(missing)} undocumented_labeled={sorted(misclassified_extra)} undocumented_expected_labeled_as_alias={sorted(misclassified_missing)} not_scheduled={sorted(not_executed)} missing_schedule={missing_schedule}")
print("UM0080 documented inventory matches: 698 distinct keys (252 base, 248 CB, 58 ED, 39 DD, 39 FD, 31 DD-CB, 31 FD-CB)")
