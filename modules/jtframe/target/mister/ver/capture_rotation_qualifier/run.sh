#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../../../.." && pwd)
export JTROOT="$root"
export JTFRAME="$root/modules/jtframe"
obj=$(mktemp -d "${TMPDIR:-/tmp}/capture-rotation-qualifier.XXXXXX")
trap 'rm -rf -- "$obj"' EXIT
verilator --binary --timing --top-module test -Wno-fatal -Wno-PINMISSING \
  -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-WIDTH -Wno-TIMESCALEMOD \
  -DJTFRAME_LF_VW=9 -DJTFRAME_LF_HW=9 -DJTFRAME_MR_FASTIO=0 \
  -DJTFRAME_REGRESSION -DJTFRAME_VERTICAL --Mdir "$obj" \
  -f "$here/gather.f" "$here/test.sv"
"$obj/Vtest"
