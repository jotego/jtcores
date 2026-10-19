#!/bin/bash
set -euo pipefail
ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
bash "$ver_dir/build.sh"
python3 "$ver_dir/run.py" "$@"
python3 "$ver_dir/array/programs.py" --fill-boundaries --out "$ver_dir/build/fill-boundaries.yaml"
python3 "$ver_dir/run.py" --vectors "$ver_dir/build/fill-boundaries.yaml"
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
iverilog -g2012 -s test -o "$ver_dir/build/regs.vvp" \
    "$ver_dir/regs/test.sv" "$ver_dir/../hdl/jttms10_regs.v"
vvp "$ver_dir/build/regs.vvp"
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/word.vvp" "$ver_dir/word/test.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    vvp word.vvp
)
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/arch.vvp" "$ver_dir/arch/test.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    for mode in 1 2 3 4 5 6 7 8; do
        vvp arch.vvp +mode="$mode"
    done
)
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/system.vvp" "$ver_dir/system/test.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    vvp system.vvp
)
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/pixelbus.vvp" "$ver_dir/pixelbus/test.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    vvp pixelbus.vvp
)
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/arrayirq.vvp" "$ver_dir/array/interrupt.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    for fill_size in 1 2 4 8 16; do
        vvp arrayirq.vvp +FILL_PSIZE="$fill_size"
    done
)
iverilog -g2012 -s test -I"$ver_dir/build" \
    -o "$ver_dir/build/lineirq.vvp" "$ver_dir/line/interrupt.sv" \
    "$ver_dir"/../hdl/*.v
(
    cd "$ver_dir/build"
    vvp lineirq.vvp
)
iverilog -g2012 -s test -o "$ver_dir/build/io.vvp" \
    "$ver_dir/io/test.sv" "$ver_dir/../hdl/jttms10_io.v" \
    "$ver_dir/../hdl/jttms10_video.v" "$ver_dir/../hdl/jttms10_refresh.v" \
    "$ver_dir/../hdl/jttms10_host.v"
vvp "$ver_dir/build/io.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/bus.vvp" \
    "$ver_dir/bus/test.sv" "$ver_dir/../hdl/jttms10_bus.v"
vvp "$ver_dir/build/bus.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/startup.vvp" \
    "$ver_dir/startup/test.sv" "$ver_dir/../hdl/jttms10_bus.v"
vvp "$ver_dir/build/startup.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/cache.vvp" \
    "$ver_dir/cache/test.sv" "$ver_dir/../hdl/jttms10_cache.v"
vvp "$ver_dir/build/cache.vvp"
iverilog -g2012 -s test -o "$ver_dir/build/cachefield.vvp" \
    "$ver_dir/cachefield/test.sv" "$ver_dir/../hdl/jttms10_field.v" \
    "$ver_dir/../hdl/jttms10_cache.v" "$ver_dir/../hdl/jttms10_bus.v"
vvp "$ver_dir/build/cachefield.vvp"
iverilog -g2012 -s test -Ptest.TIMING=1 -o "$ver_dir/build/cachefield-timed.vvp" \
    "$ver_dir/cachefield/test.sv" "$ver_dir/../hdl/jttms10_field.v" \
    "$ver_dir/../hdl/jttms10_cache.v" "$ver_dir/../hdl/jttms10_bus.v" \
    "$ver_dir/../hdl/jttms10_bus_timer.v"
vvp "$ver_dir/build/cachefield-timed.vvp"
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
python3 -B "$ver_dir/timing/test_checker.py"
python3 -B "$ver_dir/timing/test_fill_oracle.py"
python3 -B "$ver_dir/timing/test_fill_cases.py"
python3 "$ver_dir/bus_timing/check.py"
python3 "$ver_dir/load_pause/check.py"
python3 "$ver_dir/emu/check.py"
# Validate mutation injection sites before starting the larger timing matrices.
python3 "$ver_dir/timing/mutations.py"
timing_simulator=${JTTMS10_TIMING_SIMULATOR:-iverilog}
timing_args=(--simulator "$timing_simulator")
if [ -n "${JTTMS10_TIMING_REPORT:-}" ]; then
    timing_args+=(--report "$JTTMS10_TIMING_REPORT")
fi
python3 "$ver_dir/timing/run.py" "${timing_args[@]}"
python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" --wait-states 1
python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" --wait-states 1 --pause-clocks 7
python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" --case divs_even_boundary_26_hit --pause-clocks 7 --pause-after-clocks 32
python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" --case divs_even_boundary_26_off --wait-states 1 --pause-clocks 7 --pause-after-clocks 32
# Every nonzero sub-state pause must realign a newly allocated data read.
for pause in 1 2 3 4 5 6; do
    python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" --case load_move_f0_w32_o15_s1_off --case _phase_ --wait-states 1 --pause-clocks "$pause"
done
coverage_args=()
if [ -n "${JTTMS10_TIMING_REPORT:-}" ]; then
    coverage_args+=(--report "$JTTMS10_TIMING_REPORT.coverage.json")
fi
python3 "$ver_dir/timing/coverage.py" "${coverage_args[@]}"
