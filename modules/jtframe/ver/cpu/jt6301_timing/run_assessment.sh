#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../../../.." && pwd)"
cd "$root"
source ./setprj.sh
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$JTFRAME/bin/simunit.sh" --run "$here" 2>&1 | tee "$log"
python3 "$here/verify_coverage.py" "$log"
