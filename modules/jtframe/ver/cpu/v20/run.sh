#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 29-10-2026
set -euo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
image=${SIM_IMAGE:-jotego/linter:latest}
if [[ ${1:-} != --inside ]]; then
    docker image inspect "$image" >/dev/null
    exec docker run --pull=never --rm --entrypoint /bin/bash -v "$root:/jtcores" "$image" \
        /jtcores/modules/jtframe/ver/cpu/v20/run.sh --inside
fi
export JTROOT="$root" JTFRAME="$root/modules/jtframe"
export PATH="$JTFRAME/bin:$PATH:."
if [[ ${2:-} != --cpu-only ]]; then
    exec simunit.sh --run "$JTFRAME/ver/cpu/v20_bus"
fi
cd "$JTFRAME/ver/cpu/v20"
mkdir -p logs
cp "$JTFRAME/hdl/cpu/nuv30/ucrom.hex" "$JTFRAME/hdl/cpu/nuv30/ucdecode.hex" .
for mode in v20 v30 v20-synthesis; do
    mkdir -p "build/$mode"
    macros=()
    if [[ $mode == v30 ]]; then macros=(-DV30_REGRESSION); fi
    if [[ $mode == v20-synthesis ]]; then macros=(-DSYNTHESIS); fi
    if ! verilator --binary --assert --timing -j 4 --top-module cpu_test \
        -Wno-WIDTHEXPAND -Wno-TIMESCALEMOD -I"$JTFRAME/hdl/cpu/nuv30" \
        --Mdir "build/$mode" "${macros[@]}" \
        "$JTFRAME/hdl/cpu/nuv30/v30u_ss_pkg.sv" \
        "$JTFRAME/hdl/cpu/nuv30/v30u_ucrom.sv" \
        "$JTFRAME/hdl/cpu/nuv30/v30u_biu.sv" \
        "$JTFRAME/hdl/cpu/nuv30/v30u_eu.sv" \
        "$JTFRAME/hdl/cpu/nuv30/v30_core.sv" \
        "$JTFRAME/hdl/cpu/jtframe_v30.sv" \
        "$JTFRAME/hdl/cpu/jtframe_v20_bus.sv" \
        "$JTFRAME/hdl/cpu/jtframe_v20.sv" cpu_test.sv >"logs/$mode-build.log" 2>&1; then
        tail -60 "logs/$mode-build.log"
        exit 1
    fi
    for waits in 0 3 16; do
        "build/$mode/Vcpu_test" "+wait=$waits" +seed=76543210 | tee "logs/$mode-w$waits.log"
        grep -q '^PASS CPU' "logs/$mode-w$waits.log"
    done
done
# An incorrect data byte must be rejected by the architectural checks.
if build/v20/Vcpu_test +wait=3 +corrupt >logs/negative.log 2>&1; then
    echo "FAIL: corrupt data was accepted"
    exit 1
fi
grep -q 'read/add/LOCK' logs/negative.log
echo "PASS negative control: corrupt read rejected"
