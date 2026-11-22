#!/bin/bash
# Copies each cores/<core>/ver/<setname>/reg.cab to <dir>/<setname>.cab
# Usage: reg-cabs.sh [-o <dir>] [core...]
# The default <dir> is release/cab in the repository that holds this script.

main() {
    set -euo pipefail
    find_root
    parse_args "$@"
    list_cabs
    check_duplicates
    check_stale
    copy_cabs
}

find_root() {
    ROOT=$(cd -- "$(dirname -- "$(realpath -- "$0")")/../../.." && pwd)
    OUT=$ROOT/release/cab
    CORES=()
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -o)
                [ $# -gt 1 ] || fail "-o needs a folder"
                OUT=$2
                shift;;
            -h|--help)
                sed -n '2,4s/^# //p' "$0"
                exit 0;;
            -*)
                fail "unknown option $1";;
            *)
                [ -d "$ROOT/cores/$1" ] || fail "unknown core $1"
                CORES+=("$1");;
        esac
        shift
    done
}

list_cabs() {
    local core
    shopt -s nullglob
    CABS=()
    if [ ${#CORES[@]} = 0 ]; then
        CABS=("$ROOT"/cores/*/ver/*/reg.cab)
    else
        for core in "${CORES[@]}"; do
            CABS+=("$ROOT/cores/$core/ver/"*/reg.cab)
        done
    fi
}

setname() {
    basename "$(dirname "$1")"
}

check_duplicates() {
    local dup
    [ ${#CABS[@]} = 0 ] && return
    dup=$(for cab in "${CABS[@]}"; do setname "$cab"; done | sort | uniq -d)
    [ -z "$dup" ] || fail "duplicated setname: $(echo "$dup" | xargs)"
}

# A leftover .cab would add a game to the regression list, but -o may point at
# hand-written files, so stop rather than delete them
check_stale() {
    local cab name stale=()
    declare -A written=()
    for cab in "${CABS[@]}"; do written[$(setname "$cab").cab]=1; done
    for cab in "$OUT"/*.cab; do
        name=$(basename "$cab")
        [ -n "${written[$name]:-}" ] || stale+=("$name")
    done
    [ ${#stale[@]} = 0 ] || fail "$OUT holds .cab files without a reg.cab: ${stale[*]}. Use an empty folder"
}

copy_cabs() {
    local cab
    mkdir -p "$OUT"
    for cab in "${CABS[@]}"; do
        cp "$cab" "$OUT/$(setname "$cab").cab"
    done
    echo "${#CABS[@]} CAB files copied to $OUT"
}

fail() {
    echo "reg-cabs.sh: $*" >&2
    exit 1
}

main "$@"
