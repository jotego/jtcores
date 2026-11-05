#!/bin/bash
set -euo pipefail

main() {
    local src output external csv samples
    local args=()
    local stride_args=()
    local probe_args=()
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output="$src/../../artifacts/opm-reference/build"
    external=${NUKED_OPM_ROOT:-/nobackup/jtmisc/reverse/Nuked-OPM}
    while [[ ${1:-} == --public-bus || ${1:-} == --keyon-phase ]]; do
        if [[ $1 == --public-bus ]]; then
            probe_args+=("$1")
            shift
        else
            [[ $# -ge 2 ]] || { usage; exit 2; }
            probe_args+=("$1" "$2")
            shift 2
        fi
    done
    if [[ ${1:-} == --stride ]]; then
        [[ $# -ge 2 ]] || { usage; exit 2; }
        stride_args=(--stride "$2")
        shift 2
    fi
    if [[ ${1:-} == --event ]]; then
        [[ $# -ge 4 && $# -le 5 ]] || { usage; exit 2; }
        args=(--event "$(realpath "$2")" "$(realpath "$3")")
        csv=$(realpath -m "$4")
        samples=${5:-16384}
    else
        [[ $# -ge 2 && $# -le 3 ]] || { usage; exit 2; }
        args=("$(realpath "$1")")
        csv=$(realpath -m "$2")
        samples=${3:-16384}
    fi
    args+=("$csv" "$samples")
    [[ -f "$external/opm.c" && -f "$external/opm.h" ]] || {
        echo "NUKED_OPM_ROOT must point to an existing external Nuked-OPM checkout" >&2
        exit 2
    }
    mkdir -p "$output"
    cc -std=c99 -O2 -Wall -Wextra -I "$external" -c "$external/opm.c" \
        -o "$output/opm.o" > "$output/build.log" 2>&1
    c++ -std=c++17 -O2 -Wall -Wextra -Werror -I "$external" \
        "$src/test.cpp" "$output/opm.o" -o "$output/opm-oracle" \
        >> "$output/build.log" 2>&1
    "$output/opm-oracle" "${probe_args[@]}" "${stride_args[@]}" "${args[@]}"
}

usage() {
    echo "Usage: $0 [--public-bus] [--keyon-phase P] [--stride N] PROGRAM CSV [SAMPLES]" >&2
    echo "       $0 [--public-bus] [--keyon-phase P] [--stride N] --event INIT EVENT CSV [SAMPLES]" >&2
}

main "$@"
