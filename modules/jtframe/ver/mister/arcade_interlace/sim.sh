#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
source ../../../bin/setprj.sh >/dev/null
gather=$(mktemp)
build_dir=$(mktemp -d)
trap 'rm -f "$gather" sim.log; rm -r -- "$build_dir"' EXIT
envsubst < gather.f > "$gather"
verilator --binary --timing -Wno-fatal -Wno-TIMESCALEMOD -Wno-IMPLICITSTATIC \
    -Wno-PINMISSING \
    -Wno-IMPLICIT -Wno-WIDTH -Wno-PROCASSWIRE -f "$gather" --top-module test \
    test.v --Mdir "$build_dir" > /dev/null
"$build_dir/Vtest" | tee sim.log
grep -q '^PASS:' sim.log
