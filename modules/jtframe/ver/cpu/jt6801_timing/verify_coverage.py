#!/usr/bin/env python3
"""Reconcile runtime opcode/timing events with this folder's manual inventory."""
import csv
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} simunit-output.log")
log = Path(sys.argv[1]).read_text(errors="replace")
manifest = Path(__file__).with_name("manual-opcodes.csv")
manual = {int(row["opcode"], 16): row for row in csv.DictReader(manifest.open())}
rows = re.findall(r"^COVERAGE opcode=([0-9a-fA-F]{2}) executed=(\d+) timed=(\d+)$", log, re.M)
if len(rows) != 256 or {int(row[0], 16) for row in rows} != set(range(256)):
    raise SystemExit(f"runtime coverage dump incomplete or duplicated: {len(rows)} rows")
runtime = {int(op, 16): (int(executed), int(timed)) for op, executed, timed in rows}
want_exec = {op for op, row in manual.items() if row["status"] == "defined"}
want_timed = {op for op, row in manual.items() if row["timing_checked"] == "yes"}
got_exec = {op for op, counts in runtime.items() if counts[0]}
got_timed = {op for op, counts in runtime.items() if counts[1]}
for label, got, want in (("executed", got_exec, want_exec), ("timed", got_timed, want_timed)):
    missing, extra = sorted(want - got), sorted(got - want)
    if missing or extra:
        show = lambda values: ",".join(f"{op:02X}" for op in values) or "none"
        raise SystemExit(f"{label} opcode key mismatch; missing={show(missing)} extra={show(extra)}")
blocked_timing = want_exec - want_timed
print(f"RUNTIME COVERAGE VERIFIED: {len(got_exec)}/{len(want_exec)} documented opcodes executed; "
      f"{len(got_timed)}/{len(want_exec)} documented opcodes with cycle checks "
      f"({len(blocked_timing)} blocked: {','.join(f'{op:02X}' for op in sorted(blocked_timing)) or 'none'}); "
      f"{sum(v[0] for v in runtime.values())} dispatches / {sum(v[1] for v in runtime.values())} timing assertions")
service_oracle = list(csv.DictReader(Path(__file__).with_name("manual-interrupt-timing.csv").open()))
want_service = {"IRQ": int(service_oracle[0]["manual_cycles"])*4, "NMI": int(service_oracle[1]["manual_cycles"])*4}
matches = re.findall(r"CHECKED: (?:MC6801|HD6301) (IRQ|NMI) C70.*?12E", log)
if set(matches) != set(want_service) or len(matches) != 2:
    raise SystemExit(f"interrupt service must match the manual exactly once per kind; matches={matches}")
observed = {kind: (want_service[kind], want_service[kind]) for kind in matches}
if set(observed) != set(want_service):
    raise SystemExit(f"interrupt service coverage incomplete/duplicated: {observed}")
for kind, (measured, expected) in observed.items():
    if expected != want_service[kind] or measured != expected:
        raise SystemExit(f"{kind} service interval unexpected: measured={measured} manual={expected}")
print("INTERRUPT SERVICE VERIFIED: IRQ and NMI measured at calibrated C70-to-U860 boundaries; manual source expects 12E; "
      + ", ".join(f"{kind}={value[0]}CEN" for kind, value in sorted(observed.items())))
