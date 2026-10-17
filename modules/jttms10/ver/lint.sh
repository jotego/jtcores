#!/bin/bash
set -euo pipefail
ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
bash "$ver_dir/build.sh"
# The JTFRAME-generated parameter header lacks a terminal newline.
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$ver_dir/build" --top-module jttms10 "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall --top-module jttms10_field \
    "$ver_dir/../hdl/jttms10_field.v"
