#!/usr/bin/env python3
"""Strictly compare all measured instruction outcomes with the HMOS manual."""
from collections import defaultdict
import csv
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent

with (HERE / "oracle.csv").open(newline="") as stream:
    oracle_rows = list(csv.DictReader(stream))
manual = {
    int(row["opcode"], 16): int(row["hmos_cycles"])
    for row in oracle_rows
    if row["scope"] == "HMOS+CMOS"
}
if len(manual) != 207:
    raise SystemExit(f"strict HMOS gate: expected 207 manual opcodes, found {len(manual)}")

with (HERE / "timing_results.csv").open(newline="") as stream:
    rows = list(csv.DictReader(stream))
if len(rows) != 237:
    raise SystemExit(f"strict HMOS gate: expected 237 measured outcomes, found {len(rows)}")

deviations = defaultdict(list)
for row in rows:
    code = int(row["opcode"], 16)
    observed = int(row["observed"])
    if code not in manual:
        raise SystemExit(f"strict HMOS gate: unexpected opcode {code:02X}")
    if observed != manual[code]:
        deviations[code].append((row["path"], manual[code], observed))

cases = sum(len(paths) for paths in deviations.values())
if cases:
    print(f"STRICT-HMOS-FAIL: {cases} of {len(rows)} timing outcomes differ from the original HMOS oracle across {len(deviations)} encodings")
    for code, outcomes in sorted(deviations.items()):
        path_text = ",".join(f"path={path}: expected {expected}, observed {actual} E" for path, expected, actual in outcomes)
        print(f"  {code:02X}: {path_text}")
    sys.exit(1)

print("STRICT-HMOS-PASS: all measured outcomes match the original HMOS oracle")
