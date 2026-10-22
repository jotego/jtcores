#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../../../.." && pwd)"
cd "$root"
source setprj.sh
for spec in \
    'NEGATIVE_RESULT|A=bc expected bd' \
    'NEGATIVE_TIMING|used 8 crystal enables, manual expects 3 E cycles' \
    'NEGATIVE_VECTOR|manual vector target 0201; PC=0200' \
    'STRICT_SPEC|STRICT_SPEC: MC6801 WAI failed'; do
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
