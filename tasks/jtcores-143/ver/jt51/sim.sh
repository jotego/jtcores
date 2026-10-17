#!/bin/bash
set -euo pipefail

main() {
    local src output csv samples
    local trace_args=()
    local args=()
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output="$src/../../artifacts/jt51-build"
    if [[ ${1:-} == --keep ]]; then
        trace_args=(--trace-fst -CFLAGS -DTRACE)
        shift
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
    mkdir -p "$output"
    verilator --quiet --cc --exe --build -j 4 --top-module jt51 \
        --timescale 1ns/1ps --Mdir "$output" "${trace_args[@]}" \
        -F "$JTROOT/modules/jt51/hdl/jt51.f" "$src/test.cpp" \
        > "$output/build.log" 2>&1
    cd "$(dirname "$csv")"
    "$output/Vjt51" "${args[@]}"
}

usage() {
    echo "Usage: $0 [--keep] PROGRAM CSV [SAMPLES]" >&2
    echo "       $0 [--keep] --event INIT EVENT CSV [SAMPLES]" >&2
}

main "$@"
