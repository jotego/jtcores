#!/bin/bash
set -euo pipefail
ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
build_dir=$(mktemp -d -t jttms10-lint-XXXXXX)
trap 'rm -rf -- "$build_dir"' EXIT
bash "$ver_dir/build.sh" "$build_dir"
# The JTFRAME-generated parameter header lacks a terminal newline.
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$build_dir" --top-module jttms10 "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall --top-module jttms10_field \
    "$ver_dir/../hdl/jttms10_field.v"
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$build_dir" --top-module jttms10_word "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall -Wno-EOFNEWLINE \
    -I"$build_dir" --top-module jttms10_system "$ver_dir"/../hdl/*.v
verilator --lint-only -Wall --top-module jttms10_io \
    "$ver_dir/../hdl/jttms10_io.v" "$ver_dir/../hdl/jttms10_video.v" \
    "$ver_dir/../hdl/jttms10_refresh.v" "$ver_dir/../hdl/jttms10_host.v"
verilator --lint-only -Wall --top-module jttms10_host \
    "$ver_dir/../hdl/jttms10_host.v"
verilator --lint-only -Wall --top-module jttms10_pixel \
    "$ver_dir/../hdl/jttms10_pixel.v"
verilator --lint-only -Wall --top-module jttms10_cache \
    "$ver_dir/../hdl/jttms10_cache.v"
verilator --lint-only -Wall --top-module jttms10_bus \
    "$ver_dir/../hdl/jttms10_bus.v" "$ver_dir/../hdl/jttms10_bus_timer.v"
verilator --lint-only -Wall --top-module jttms10_bus_timer \
    "$ver_dir/../hdl/jttms10_bus_timer.v"
verilator --lint-only -Wall --top-module jttms10_fabric \
    "$ver_dir/../hdl/jttms10_fabric.v" "$ver_dir/../hdl/jttms10_bus.v" \
    "$ver_dir/../hdl/jttms10_bus_timer.v" \
    "$ver_dir/../hdl/jttms10_io.v" "$ver_dir/../hdl/jttms10_video.v" \
    "$ver_dir/../hdl/jttms10_refresh.v" "$ver_dir/../hdl/jttms10_host.v"
