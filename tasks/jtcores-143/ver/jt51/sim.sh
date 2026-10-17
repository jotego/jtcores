#!/bin/bash
set -euo pipefail

main() {
    local src output program csv samples
    local trace_args=()
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output="$src/../../artifacts/jt51-build"
    if [[ ${1:-} == --keep ]]; then
        trace_args=(--trace-fst -CFLAGS -DTRACE)
        shift
    fi
    [[ $# -ge 2 && $# -le 3 ]] || {
        echo "Usage: $0 [--keep] PROGRAM CSV [SAMPLES]" >&2; exit 2;
    }
    program=$(realpath "$1")
    csv=$(realpath -m "$2")
    samples=${3:-16384}
    mkdir -p "$output"
    verilator --quiet --cc --exe --build -j 4 --top-module jt51 \
        --timescale 1ns/1ps --Mdir "$output" "${trace_args[@]}" \
        -F "$JTROOT/modules/jt51/hdl/jt51.f" "$src/test.cpp" \
        > "$output/build.log" 2>&1
    cd "$(dirname "$csv")"
    "$output/Vjt51" "$program" "$csv" "$samples"
}

main "$@"
