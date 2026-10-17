#!/bin/bash
set -euo pipefail
ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
bash "$ver_dir/build.sh"
# The JTFRAME-generated parameter header lacks a terminal newline.
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$ver_dir/build" --top-module jttms10 "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall --top-module jttms10_field \
    "$ver_dir/../hdl/jttms10_field.v"
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$ver_dir/build" --top-module jttms10_word "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall --top-module jttms10_io \
    "$ver_dir/../hdl/jttms10_io.v" "$ver_dir/../hdl/jttms10_video.v" \
    "$ver_dir/../hdl/jttms10_refresh.v"
verilator --lint-only -Wall --top-module jttms10_bus \
    "$ver_dir/../hdl/jttms10_bus.v"
verilator --lint-only -Wall --top-module jttms10_fabric \
    "$ver_dir/../hdl/jttms10_fabric.v" "$ver_dir/../hdl/jttms10_bus.v" \
    "$ver_dir/../hdl/jttms10_io.v" "$ver_dir/../hdl/jttms10_video.v" \
    "$ver_dir/../hdl/jttms10_refresh.v"
