#!/usr/bin/env python3
"""Check the manually transcribed Motorola inventory against the active decode."""
from pathlib import Path
import csv
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--oracle", default="oracle.csv", help="generated manual inventory CSV")
parser.add_argument("--yaml", default=None, help="active JT6805 decode source")
args = parser.parse_args()

ROOT = Path("../../../../..")
yaml = Path(args.yaml) if args.yaml else ROOT / "modules/jt680x/ucode/6805.yaml"
if not yaml.is_file():
    raise SystemExit(f"cannot locate active decode source {yaml}")

source = yaml.read_text()
ops = source.split("\nucode:", 1)[0]
lines = [line for line in ops.splitlines() if re.match(r"^\s*-\s*\{", line)]
parsed = []
for number, line in enumerate(lines, 1):
    name = re.search(r"\bname:\s*([A-Z0-9]+)", line)
    code = re.search(r"\bop:\s*0x([0-9a-fA-F]{2})\b", line)
    cycles = re.search(r"\bcycles:\s*(\d+)\b", line)
    if not (name and code and cycles):
        raise SystemExit(f"malformed active decode row {number}: {line}")
    parsed.append((int(code.group(1), 16), name.group(1), int(cycles.group(1))))
if len(parsed) != len(lines) or not parsed:
    raise SystemExit(f"active decode parse failed: matched {len(parsed)} of {len(lines)} rows")

with Path(args.oracle).open(newline="") as f:
    reader = csv.DictReader(f)
    required = ["opcode","mnemonic","mode","hmos_cycles","cmos_cycles","bytes","scope","manual_ref","source_conflict"]
    if reader.fieldnames != required:
        raise SystemExit(f"manual inventory schema mismatch: {reader.fieldnames}")
    records = list(reader)
if not records:
    raise SystemExit("empty manual inventory")
manual = {}
for row in records:
    try:
        code = int(row["opcode"], 16)
        length = int(row["bytes"])
        if not 1 <= length <= 3 or row["scope"] not in ("HMOS+CMOS", "CMOS-only"):
            raise ValueError
        if row["scope"] == "HMOS+CMOS" and not row["hmos_cycles"].isdigit():
            raise ValueError
        if not row["cmos_cycles"].isdigit():
            raise ValueError
    except (TypeError, ValueError):
        raise SystemExit(f"invalid manual inventory row: {row}")
    if code in manual:
        raise SystemExit(f"duplicate manual opcode {code:02X}")
    manual[code] = row

active = {}
for code, name, cycles in parsed:
    if code in active:
        raise SystemExit(f"duplicate active decode opcode {code:02X}")
    active[code] = (name, cycles)
if len(manual) != 209 or len(active) != 209:
    raise SystemExit(f"encoding row count manual/active = {len(manual)}/{len(active)}, expected 209/209")
if len([r for r in records if r["scope"] == "HMOS+CMOS"]) != 207:
    raise SystemExit("manual inventory must classify exactly 207 HMOS forms")
if len([r for r in records if r["scope"] == "CMOS-only"]) != 2:
    raise SystemExit("manual inventory must classify exactly 2 CMOS-only forms")
missing = sorted(set(manual) - set(active))
extra = sorted(set(active) - set(manual))
if missing or extra:
    raise SystemExit(f"manual/decode code mismatch: missing={[f'{x:02X}' for x in missing]} extra={[f'{x:02X}' for x in extra]}")
wrong_name = [(code, row["mnemonic"], active[code][0]) for code,row in manual.items()
              if row["mnemonic"] != active[code][0]]
if wrong_name:
    raise SystemExit(f"manual/decode mnemonic mismatch: {wrong_name[:8]}")

hmos_match = cmos_match = neither = 0
for code,row in manual.items():
    cycles = active[code][1]
    hmos_match += row["hmos_cycles"].isdigit() and cycles == int(row["hmos_cycles"])
    cmos_match += cycles == int(row["cmos_cycles"])
    neither += (not row["hmos_cycles"].isdigit() or cycles != int(row["hmos_cycles"])) and cycles != int(row["cmos_cycles"])
print(f"Inventory gate: 207 HMOS forms + 2 CMOS-only extensions reconcile; 47 encodings remain reserved/unsupported")
print(f"JT YAML cycle declarations compare as HMOS={hmos_match}, CMOS={cmos_match}, neither={neither}; declarations are metadata only")
