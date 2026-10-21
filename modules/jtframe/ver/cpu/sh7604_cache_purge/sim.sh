#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
JTFRAME_DIR="${JTFRAME:-$(cd "$TEST_DIR/../../.." && pwd)}"
VERILATOR_BIN="${VERILATOR:-verilator}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sh7604-cache-purge.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

"$VERILATOR_BIN" \
    --binary \
    --timing \
    --top-module test \
    -Wno-fatal \
    --Mdir "$BUILD_DIR" \
    "$JTFRAME_DIR/hdl/cpu/sh7604/SH7604_pkg.sv" \
    "$JTFRAME_DIR/hdl/cpu/sh7604/CACHE.sv" \
    "$TEST_DIR/test.sv"

"$BUILD_DIR/Vtest"
