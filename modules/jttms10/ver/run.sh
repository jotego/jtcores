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
