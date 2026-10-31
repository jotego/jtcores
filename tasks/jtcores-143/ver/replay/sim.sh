#!/bin/bash
set -euo pipefail

main() {
    local src output
    local trace_args=()
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output="$src/../../artifacts/replay-build"
    if [[ ${1:-} == --keep ]]; then
        trace_args=(--trace-fst -DTRACE)
        shift
    fi
    [[ $# -le 1 ]] || { echo "Usage: $0 [--keep] [CAPTURE]" >&2; exit 2; }
    if [[ $# == 1 ]]; then export YAMAHA_REPLAY; YAMAHA_REPLAY=$(realpath "$1"); fi
    mkdir -p "$output"
    cd "$src"
    go run init.go
    verilator --quiet --binary --timing --top-module test -j 4 \
        --Mdir "$output" "${trace_args[@]}" \
        test.sv ../../rtl/c96_yamaha_sampler.v > "$output/build.log" 2>&1
    "$output/Vtest" | tee "$output/sim.log"
    rg -q '^PASS:' "$output/sim.log"
}

main "$@"
