#!/bin/bash
# Verify jtmnymny_mixer.v against the bit-true vectors (analyze.py --emit).
set -euo pipefail
cd "$(dirname "$0")"
JTROOT=$(cd ../../../..; pwd)
REL=cores/mnymny/ver/audio

case "$(uname -m)" in
    arm64|aarch64) IMAGE=${IMAGE:-jotego/simulator:arm64} ;;
    *)             IMAGE=${IMAGE:-jotego/simulator:latest} ;;
esac

[ -f out/stim.hex ] || { echo "run: python3 analyze.py --emit"; exit 1; }
cp ../../hdl/jtmnymny_coeffs.hex .

docker run --rm -v "$JTROOT":/jtroot -w /jtroot/$REL "$IMAGE" -c '
    unset VERILATOR_ROOT
    verilator --binary -j 4 -Wno-fatal --top-module tb_mixer \
        tb_mixer.v ../../hdl/jtmnymny_mixer.v +incdir+../../hdl \
        -o tbmix >verilator.log 2>&1 || { tail -30 verilator.log; exit 1; }
    ./obj_dir/tbmix
'
