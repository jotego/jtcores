#!/bin/bash -e

BETA_FILE="$JTROOT/.beta.yaml"

main() {
    check_requirements
    local beta_cores="$(get_beta_cores)"
    local missing_cores="$(printf '%s\n' "$beta_cores" | is_missing)"
    local beta_msg_cores="$(find_beta_msg_cores)"
    local missing_beta_refs="$(printf '%s\n' "$beta_msg_cores" | not_in_list "$beta_cores")"
    report "$missing_cores" "$missing_beta_refs"
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

find_beta_msg_cores() {
    local msg
    for msg in "$CORES"/*/cfg/msg; do
        if [ ! -f "$msg" ]; then continue; fi
        if grep -qi 'beta' "$msg"; then
            local core_dir="$(dirname "$msg")"
            local core="$(basename "$(dirname "$core_dir")")"
            echo "$core"
        fi
    done
}

not_in_list() {
    local allowed="$1"
    local item
    while IFS= read -r item; do
        if [ -z "$item" ]; then continue; fi
        if ! printf '%s\n' "$allowed" | grep -Fxq "$item"; then
            echo "$item"
        fi
    done
}

report() {
    local missing_cores="$1"
    local missing_beta_refs="$2"
    if [ -z "$missing_cores" ] && [ -z "$missing_beta_refs" ]; then
        return
    fi
    if [ -n "$missing_cores" ]; then
        echo "The following cores in $(basename "$BETA_FILE") do not exist:"
        echo "$missing_cores"
    fi
    if [ -n "$missing_beta_refs" ]; then
        if [ -n "$missing_cores" ]; then echo; fi
        echo "The following cores mention beta in cfg/msg but are missing from $(basename "$BETA_FILE"):"
        echo "$missing_beta_refs"
    fi
    exit 1
}

main "$@"
