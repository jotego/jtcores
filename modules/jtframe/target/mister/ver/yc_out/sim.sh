#!/bin/bash
set -e
cd "$(dirname "$0")"
trap 'rm -rf obj_dir' EXIT
rm -rf obj_dir

verilator --binary --sv --timescale 1ns/1ps \
    -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
    --top-module test test.sv ../../hdl/sys/yc_out.sv

./obj_dir/Vtest
