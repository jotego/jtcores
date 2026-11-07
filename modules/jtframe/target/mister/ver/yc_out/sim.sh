#!/bin/bash
set -e
cd "$(dirname "$0")"
trap 'rm -rf obj_dir; rm -f yc_samples.csv' EXIT
rm -rf obj_dir
mkdir -p obj_dir
python3 reference.py obj_dir

verilator --binary --sv --timescale 1ns/1ps \
    -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
    --top-module test test.sv ../../hdl/sys/yc_out.sv

./obj_dir/Vtest

if [ -n "${YC_EVIDENCE_DIR:-}" ]; then
    mkdir -p "$YC_EVIDENCE_DIR"
    cp yc_samples.csv "$YC_EVIDENCE_DIR/yc_samples.csv"
    cp obj_dir/yc_trace.hex obj_dir/yc_expected.hex "$YC_EVIDENCE_DIR/"
fi
