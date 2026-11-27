#!/usr/bin/env python3
"""Strictly check runtime MC6802 cycle rows against the independent manual CSV."""
import csv
import re
import sys
from pathlib import Path


ROW_RE = re.compile(
    r"^CYCLE_ROW opcode=([0-9a-fA-F]{2}) expected=(\d+) actual=(\d+|NA) status=([a-z-]+)$"
)


def load_manual():
    rows = list(csv.DictReader((Path(__file__).parent / "manual-opcodes.csv").open()))
    ops = [int(row["opcode"], 16) for row in rows]
    if len(rows) != 197 or len(set(ops)) != 197:
        raise ValueError(
            f"expected 197 unique documented opcode encodings, got {len(rows)} rows / {len(set(ops))} unique"
        )
    manual_cycles = {}
    for row in rows:
        if not row["mnemonic"] or not row["addressing_mode"]:
            raise ValueError("manifest contains an incomplete mnemonic or addressing mode")
        cycles = int(row["manual_cycles"])
        if not 1 <= cycles <= 12:
            raise ValueError(f"invalid manual cycle count for opcode ${row['opcode']}")
        manual_cycles[int(row["opcode"], 16)] = cycles
    compat = {0x21, 0x9D}
    immediate_stores = {0x87, 0x8F, 0xC7, 0xCF}
    if compat.intersection(ops) or immediate_stores.intersection(ops):
        raise ValueError("manifest includes a compatibility opcode or non-operative immediate store")
    return manual_cycles


def check_log(log_path, manual_cycles):
    log = Path(log_path).read_text(errors="replace")
    raw_rows = [line for line in log.splitlines() if line.startswith("CYCLE_ROW")]

    seen = {}
    for line_number, line in enumerate(log.splitlines(), 1):
        if not line.startswith("CYCLE_ROW"):
            continue
        match = ROW_RE.fullmatch(line)
        if not match:
            raise ValueError(f"malformed runtime cycle row at line {line_number}: {line}")
        op = int(match.group(1), 16)
        expected = int(match.group(2))
        actual_text = match.group(3)
        status = match.group(4)
        if op in seen:
            raise ValueError(f"duplicate runtime cycle row for opcode ${op:02X}")
        if op not in manual_cycles:
            raise ValueError(f"runtime cycle row contains undocumented opcode ${op:02X}")
        if expected % 4:
            raise ValueError(f"expected master ticks for opcode ${op:02X} are not a multiple of four: {expected}")
        manual_ticks = manual_cycles[op] * 4
        if expected != manual_ticks:
            raise ValueError(
                f"expected ticks for opcode ${op:02X} are {expected}; manual CSV requires exactly {manual_ticks}"
            )
        if status != "pass":
            raise ValueError(f"runtime cycle row for opcode ${op:02X} has status={status}, expected pass")
        if actual_text == "NA":
            raise ValueError(f"runtime cycle row for opcode ${op:02X} has no measured boundary")
        actual = int(actual_text)
        if actual != expected:
            raise ValueError(f"runtime timing mismatch for opcode ${op:02X}: actual {actual}, expected {expected}")
        seen[op] = actual

    missing = sorted(set(manual_cycles) - set(seen))
    if missing:
        raise ValueError(f"missing runtime cycle rows for {len(missing)} documented opcodes: {missing[:12]}")
    if len(raw_rows) != 197:
        raise ValueError(f"expected exactly 197 runtime cycle rows, found {len(raw_rows)}")
    if re.search(r"^FAIL(?:[: \t]|$)", log, re.M):
        raise ValueError("simulation log contains a FAIL record")
    if not re.search(r"^PASS: MC6802 documented opcode timing and architecture fixture$", log, re.M):
        raise ValueError("simulation log lacks the final MC6802 opcode fixture PASS marker")
    return len(seen)


def main(argv):
    try:
        manual_cycles = load_manual()
        print("MANIFEST VERIFIED: 197 unique documented opcode bytes and 197 fixed manual cycle entries")
        if len(argv) > 2:
            raise ValueError("usage: verify_manifest.py [simunit-log]")
        if len(argv) == 2:
            count = check_log(argv[1], manual_cycles)
            print(f"RUNTIME VERIFIED: {count}/197 unique opcode rows match manual cycles and measured timing")
    except (OSError, ValueError) as exc:
        print(f"MANIFEST VERIFICATION FAILED: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
