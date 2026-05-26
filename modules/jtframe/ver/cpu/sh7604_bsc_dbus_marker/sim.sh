#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

if [ -z "${JTFRAME:-}" ]; then
    echo "ERROR: source setprj.sh first"
    exit 1
fi

verilator \
    --binary \
    --timing \
    --top-module test \
    -Wno-TIMESCALEMOD \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -DSIMULATION \
    -I"$JTFRAME/ver/inc" \
    test.sv \
    SH7604_BSC.sv

./obj_dir/Vtest
