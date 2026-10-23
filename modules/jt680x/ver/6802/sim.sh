#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 23-10-2026

set -euo pipefail
jt6802_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
if [ "${1:-}" != --inside ]; then
    case $(uname -m) in arm64|aarch64) jt6802_default=arm64 ;; *) jt6802_default=latest ;; esac
    jt6802_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:$jt6802_default}
    docker image inspect "$jt6802_image" >/dev/null
    exec docker run --rm --pull=never -v "$jt6802_repo:/jtcores" \
        -w /jtcores "$jt6802_image" -lc \
        'exec bash /jtcores/modules/jt680x/ver/6802/sim.sh --inside'
fi
export JTROOT="$jt6802_repo"
export JTFRAME="$JTROOT/modules/jtframe"
export CORES="$JTROOT/cores"
export MODULES="$JTROOT/modules"
export JTBIN="$JTROOT/release"
unset VERILATOR_ROOT
jt6802_suite="$JTROOT/modules/jt680x/ver/6802"
mkdir -p "$jt6802_suite/scratch"
cd "$JTFRAME/src/jtframe"
go build -o "$jt6802_suite/scratch/jtframe" .
cd "$jt6802_suite/scratch"
./jtframe ucode jt680x 6802 --output 6801 > generation.log 2>&1 || {
    cat generation.log
    exit 1
}
verilator --binary --timing --top-module test --Mdir obj_dir -j 4 \
    -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
    -DSIMULATION -DJT680X_6802 -I. \
    "$jt6802_suite/test.v" \
    "$JTROOT/modules/jt680x/hdl/jt680x.v" \
    "$JTROOT/modules/jt680x/hdl/jt680x_ctrl.v" \
    "$JTROOT/modules/jt680x/hdl/jt680x_regs.v" \
    "$JTROOT/modules/jt680x/hdl/jt680x_alu.v" \
    "$JTROOT/modules/jt680x/hdl/jt6802.v" \
    "$JTROOT/modules/jt680x/hdl/jt6802_decode.v" > build.log 2>&1 || {
        tail -n 60 build.log
        exit 1
    }
./obj_dir/Vtest | tee test.log
grep -q '^PASS ' test.log
if grep -E 'FAIL:|%Fatal|%Error' test.log; then exit 1; fi

for jt6802_profile in jt6801_timing jt6301_timing; do
    jt6802_family="$JTFRAME/ver/cpu/$jt6802_profile"
    mkdir -p "$jt6802_suite/scratch/$jt6802_profile"
    cd "$jt6802_suite/scratch/$jt6802_profile"
    PATH="$jt6802_suite/scratch:$PATH" go run "$jt6802_family/init.go" > generation.log 2>&1 || {
        cat generation.log
        exit 1
    }
    verilator --binary --timing --top-module test --Mdir obj_dir -j 4 \
        -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
        -DSIMULATION -I. "$jt6802_family/test.v" \
        "$JTROOT/modules/jt680x/hdl/jt680x.v" \
        "$JTROOT/modules/jt680x/hdl/jt680x_alu.v" \
        jt680x_ctrl_sim.rtl \
        "$JTROOT/modules/jt680x/hdl/jt680x_regs.v" \
        "$JTFRAME/hdl/ram/jtframe_ram.v" > build.log 2>&1 || {
            tail -n 60 build.log
            exit 1
        }
    ./obj_dir/Vtest > test.log 2>&1 || { tail -n 60 test.log; exit 1; }
    if grep -E 'FAIL:|%Fatal|%Error' test.log; then exit 1; fi
    python3 "$jt6802_family/verify_coverage.py" test.log
done
