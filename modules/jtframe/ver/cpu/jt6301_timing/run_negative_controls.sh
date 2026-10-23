#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../../../.." && pwd)"
cd "$root"
source ./setprj.sh
for spec in \
    'NEGATIVE_RESULT|A=bc expected bd' \
    'NEGATIVE_TIMING|used 8 crystal enables, manual expects 3 E cycles' \
    'NEGATIVE_VECTOR|manual vector target 0201; PC=0200' \
    'NEGATIVE_WAI_OMIT_CC_LOAD|stale-ALU CCR regression: expected old omitted-load value 2b'; do
    macro="${spec%%|*}"
    expected="${spec#*|}"
    log="$(mktemp)"
    if "$JTFRAME/bin/simunit.sh" --macros "$macro" --run "$here" >"$log" 2>&1; then
        rm -f "$log"
        echo "FAIL: $macro unexpectedly passed" >&2
        exit 1
    fi
    if ! grep -Fq "$expected" "$log"; then
        cat "$log" >&2
        rm -f "$log"
        echo "FAIL: $macro failed without expected diagnostic: $expected" >&2
        exit 1
    fi
    echo "NEGATIVE CONTROL VERIFIED: $macro rejected the mutated expectation / strict fidelity failure"
    rm -f "$log"
done
log="$(mktemp)"
if "$JTFRAME/bin/simunit.sh" --macros STRICT_SPEC --run "$here" >"$log" 2>&1 && grep -Fq 'PASS: HD6301 full directed assessment sequence completed' "$log"; then
    echo "STRICT SPEC VERIFIED: HD6301 timing and effect assertions match the selected manual profile"
else
    cat "$log" >&2
    rm -f "$log"
    echo "FAIL: strict HD6301 specification run did not complete" >&2
    exit 1
fi
rm -f "$log"
