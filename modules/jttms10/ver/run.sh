#!/bin/bash
set -euo pipefail
ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
bash "$ver_dir/build.sh"
python3 "$ver_dir/run.py" "$@"
for unit in alu field; do
    if [ "$unit" = alu ]; then
        bench="$ver_dir/$unit/test.v"
    else
        bench="$ver_dir/$unit/test.sv"
    fi
    iverilog -g2012 -s test -o "$ver_dir/build/$unit.vvp" \
        "$bench" "$ver_dir/../hdl/jttms10_$unit.v"
    vvp "$ver_dir/build/$unit.vvp"
done
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/word.vvp" "$ver_dir/word/test.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    vvp word.vvp
)
iverilog -g2012 -s test -o "$ver_dir/build/io.vvp" \
    "$ver_dir/io/test.sv" "$ver_dir/../hdl/jttms10_io.v" \
    "$ver_dir/../hdl/jttms10_video.v" "$ver_dir/../hdl/jttms10_refresh.v" \
    "$ver_dir/../hdl/jttms10_host.v"
vvp "$ver_dir/build/io.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/bus.vvp" \
    "$ver_dir/bus/test.sv" "$ver_dir/../hdl/jttms10_bus.v"
vvp "$ver_dir/build/bus.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/fabric.vvp" \
    "$ver_dir/fabric/test.sv" "$ver_dir/../hdl/jttms10_fabric.v" \
    "$ver_dir/../hdl/jttms10_field.v" "$ver_dir/../hdl/jttms10_bus.v" \
    "$ver_dir/../hdl/jttms10_io.v" "$ver_dir/../hdl/jttms10_video.v" \
    "$ver_dir/../hdl/jttms10_refresh.v" "$ver_dir/../hdl/jttms10_host.v"
vvp "$ver_dir/build/fabric.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/host.vvp" \
    "$ver_dir/host/test.sv" "$ver_dir/../hdl/jttms10_fabric.v" \
    "$ver_dir/../hdl/jttms10_bus.v" "$ver_dir/../hdl/jttms10_io.v" \
    "$ver_dir/../hdl/jttms10_video.v" "$ver_dir/../hdl/jttms10_refresh.v" \
    "$ver_dir/../hdl/jttms10_host.v"
vvp "$ver_dir/build/host.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/pixel.vvp" \
    "$ver_dir/pixel/test.sv" "$ver_dir/../hdl/jttms10_pixel.v" \
    "$ver_dir/../hdl/jttms10_alu.v"
vvp "$ver_dir/build/pixel.vvp"
