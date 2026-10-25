#!/usr/bin/env python3
"""Prove the strict runtime verifier rejects common mutated-log failures."""
import re
import subprocess
import sys
import tempfile
from pathlib import Path


if len(sys.argv) != 2:
    raise SystemExit("usage: verify_manifest_negative.py passing-simunit-log")

source = Path(sys.argv[1]).read_text(errors="replace")
row_re = re.compile(r"^CYCLE_ROW opcode=([0-9a-fA-F]{2}) expected=(\d+) actual=(\d+) status=pass$", re.M)
match = row_re.search(source)
if not match:
    raise SystemExit("source log has no passing runtime cycle row")
row = match.group(0)
op, expected, actual = match.group(1), int(match.group(2)), int(match.group(3))
verifier = Path(__file__).with_name("verify_manifest.py")

mutants = {
    "actual-mismatch": (source.replace(row, row.replace(f"actual={actual}", f"actual={actual + 4}"), 1), "runtime timing mismatch"),
    "wrong-expected": (source.replace(row, row.replace(f"expected={expected}", f"expected={expected + 4}"), 1), "manual CSV requires exactly"),
    "nonmultiple-expected": (source.replace(row, row.replace(f"expected={expected}", f"expected={expected + 1}").replace(f"actual={actual}", f"actual={actual + 1}"), 1), "not a multiple of four"),
    "failed-status": (source.replace(row, row.replace("status=pass", "status=delta"), 1), "status=delta"),
    "missing-row": (source.replace(row + "\n", "", 1), "missing runtime cycle rows"),
    "duplicate-row": (source + "\n" + row + "\n", "duplicate runtime cycle row"),
}

with tempfile.TemporaryDirectory(prefix="jt6802-manifest-mutants-") as temp:
    for name, (mutated, expected_message) in mutants.items():
        mutant_log = Path(temp) / f"{name}.log"
        mutant_log.write_text(mutated)
        result = subprocess.run(
            [sys.executable, str(verifier), str(mutant_log)],
            capture_output=True,
            text=True,
            check=False,
        )
        output = result.stdout + result.stderr
        if result.returncode == 0 or expected_message not in output:
            raise SystemExit(
                f"NEGATIVE CONTROL FAILED {name}: rc={result.returncode}, expected message={expected_message!r}\n{output}"
            )
        print(f"NEGATIVE CONTROL PASS {name}: verifier rejected mutation ({expected_message})")

print("PASS: strict cycle verifier rejects all six mutated-log controls")
