#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jtroot=${JTROOT:?Set JTROOT to the jtcores checkout}
count=99999975
mode=native
keep_build=0
result_bin=""

while (($#)); do
    case "$1" in
        --keep-build) keep_build=1; shift ;;
        --instructions)
            count=${2:?--instructions needs a count}
            shift 2
            ;;
        --mode)
            mode=${2:?--mode needs emulation or native}
            shift 2
            ;;
        --result-bin)
            result_bin=${2:?--result-bin needs a path}
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--mode emulation|native] [--instructions COUNT] [--result-bin PATH] [--keep-build]"
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [[ $mode != emulation && $mode != native ]]; then
    echo "MODE must be emulation or native" >&2
    exit 2
fi
if ! [[ $count =~ ^[1-9][0-9]*$ ]] || ((${#count} > 10)) ||
    ((count % 25 != 0 || count > 99999975)); then
    echo "COUNT must be a positive multiple of 25 at most 99999975 (32-bit E-cycle limit)" >&2
    exit 2
fi
rtl="$jtroot/modules/jtframe/hdl/cpu/mc6809i.v"
arith="$jtroot/modules/jtframe/hdl/cpu/jtframe_hd6309_arith.v"
wrapper="$(dirname -- "$script_dir")/../rtl/hd6309_cycle_test.sv"
[[ -f $rtl ]] || { echo "CPU RTL not found: $rtl" >&2; exit 2; }
[[ -f $arith ]] || { echo "HD6309 arithmetic RTL not found: $arith" >&2; exit 2; }
[[ -f $wrapper ]] || { echo "HD6309 FPGA wrapper not found: $wrapper" >&2; exit 2; }
mode_bit=0
if [[ $mode == native ]]; then mode_bit=1; fi

build_dir=$(mktemp -d "${TMPDIR:-/tmp}/hd6309-verilator.XXXXXX")
if ((keep_build)); then
    echo "build_dir=$build_dir"
else
    trap 'rm -rf -- "$build_dir"' EXIT
fi

/usr/bin/time -f 'compile_wall_seconds=%e' \
    env CCACHE_DISABLE=1 verilator --quiet --cc --exe --build --build-jobs 2 \
        -Wno-fatal --top-module hd6309_cycle_test \
        -GTARGET_INSTRUCTIONS="$count" \
        -GNATIVE_MODE="$mode_bit" \
        --Mdir "$build_dir" -CFLAGS '-O3' \
        "$wrapper" "$rtl" "$arith" "$script_dir/bench.cpp"
args=("$count" "$mode_bit")
if [[ -n $result_bin ]]; then args+=(--result-bin "$result_bin"); fi
/usr/bin/time -f 'simulation_wall_seconds=%e' "$build_dir/Vhd6309_cycle_test" "${args[@]}"
