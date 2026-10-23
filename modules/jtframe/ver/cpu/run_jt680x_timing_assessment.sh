#!/usr/bin/env bash
set -euo pipefail
strict_profile=""
if [[ $# -gt 1 ]]; then
    echo "usage: $0 [--strict-hmos | --strict-rockwell]" >&2
    exit 2
elif [[ "${1:-}" == "--strict-wdc" ]]; then
    echo "error: --strict-wdc is unsupported; the available 65C02 simulator targets original Rockwell R65C02. WDC data is retained as historical comparison only." >&2
    echo "usage: $0 [--strict-hmos | --strict-rockwell]" >&2
    exit 2
elif [[ "${1:-}" == "--strict-hmos" || "${1:-}" == "--strict-rockwell" ]]; then
    strict_profile="${1#--strict-}"
elif [[ $# -ne 0 ]]; then
    echo "usage: $0 [--strict-hmos | --strict-rockwell]" >&2
    exit 2
fi
cd "$(dirname "$0")/../../../.."
set --
source ./setprj.sh
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
    # Compare measured results with the selected HMOS source inventory.
    python3 "$cpu_dir/jt6805_timing/strict_hmos.py"
elif [[ "$strict_profile" == rockwell ]]; then
    # The selected target is the original Rockwell R65C02, distinct from WDC.
    "$JTFRAME/bin/simunit.sh" --macros STRICT_ROCKWELL --run "$cpu_dir/jt65c02_timing"
fi
