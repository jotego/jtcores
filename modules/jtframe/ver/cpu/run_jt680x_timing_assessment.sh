#!/usr/bin/env bash
set -euo pipefail
strict_profile=""
if [[ "${1:-}" == "--strict-hmos" || "${1:-}" == "--strict-wdc" ]]; then
    strict_profile="${1#--strict-}"
elif [[ $# -ne 0 ]]; then
    echo "usage: $0 [--strict-hmos | --strict-wdc]" >&2
    exit 2
fi
cd "$(dirname "$0")/../../../.."
source setprj.sh
cpu_dir="$JTROOT/modules/jtframe/ver/cpu"
for suite in \
    jt6801_timing \
    jt6301_timing \
    jt6805_timing \
    jt65c02_timing \
    jtdeco222_timing; do
    if [[ "$suite" == jt6801_timing || "$suite" == jt6301_timing ]]; then
        bash "$cpu_dir/$suite/run_assessment.sh"
    else
        "$JTFRAME/bin/simunit.sh" --run "$cpu_dir/$suite"
    fi
    if [[ "$suite" == jt6801_timing || "$suite" == jt6301_timing ]]; then
        bash "$cpu_dir/$suite/run_negative_controls.sh"
    fi
done

python3 "$cpu_dir/jt6805_timing/negative_controls.py"

if [[ "$strict_profile" == hmos ]]; then
    # The current implementation has documented HMOS deviations; strict mode
    # intentionally returns the oracle's nonzero result after listing them.
    python3 "$cpu_dir/jt6805_timing/strict_hmos.py"
elif [[ "$strict_profile" == wdc ]]; then
    # STRICT_SPEC intentionally returns nonzero while WDC-relative findings remain.
    "$JTFRAME/bin/simunit.sh" --macros STRICT_SPEC --run "$cpu_dir/jt65c02_timing"
fi
