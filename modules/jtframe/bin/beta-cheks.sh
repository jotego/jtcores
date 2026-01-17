#!/bin/bash -e

BETA_FILE="$JTROOT/.beta.yaml"

main() {
    check_requirements
    local missing_cores="$(get_beta_cores | is_missing)"
    report $missing_cores
}

check_requirements() {
    test -n "$JTROOT"    || fail "JTROOT is not set."
    test -n "$CORES"     || fail "CORES is not set."
    test -f "$BETA_FILE" || fail "$BETA_FILE not found."
    test -d "$CORES"     || fail "$CORES not found."
    command -v yq >/dev/null 2>&1 || fail "yq not found in PATH."
}

fail() {
    echo "Error: $*" >&2
    exit 2
}

get_beta_cores() {
    yq -r 'keys | .[]' "$BETA_FILE"
}

is_missing() {
    local corename
    while IFS= read -r corename; do
        if [ -z "$corename" ]; then continue; fi
        if [ ! -d "$CORES/$corename" ]; then
            echo "$corename"
        fi
    done
}

report() {
    local cores="$*"
    if [ -z "$cores" ]; then return; fi
    echo "The following cores in $(basename $BETA_FILE) do not exist:"
    echo "$cores"
    exit 1
}

main "$@"
