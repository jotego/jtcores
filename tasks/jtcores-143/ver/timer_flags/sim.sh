#!/bin/bash
set -euo pipefail

main() {
    local src output run
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output="$src/../../artifacts/timer-flags-probe"
    mkdir -p "$output"
    run=$(mktemp -d "$output/run-XXXXXX")
    iverilog -g2012 -s test -o "$run/simulation" \
        "$JTROOT/modules/jt51/hdl/jt51_timers.v" "$src/test.sv" \
        "$JTFRAME/hdl/ver/jtframe_test_clocks.v" \
        "$JTFRAME/hdl/video/jtframe_vtimer.v" > "$run/build.log" 2>&1
    cd "$run"
    vvp ./simulation > sim.log 2>&1
    cat sim.log
    echo "Evidence: $run"
    rg -q '^PASS:' sim.log
}

main "$@"
