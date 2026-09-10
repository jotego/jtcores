#!/bin/bash
# Sound-board-only bench: MAME-captured host commands into jtmnymny_snd.
set -euo pipefail
cd "$(dirname "$0")"
JTROOT=$(cd ../../../..; pwd)
REL=cores/mnymny/ver/snd

case "$(uname -m)" in
    arm64|aarch64) IMAGE=${IMAGE:-jotego/simulator:arm64} ;;
    *)             IMAGE=${IMAGE:-jotego/simulator:latest} ;;
esac

cp ../../hdl/jtmnymny_tms5200_lpc.hex ../../hdl/jtmnymny_tms5200_chirp.hex . 2>/dev/null || true

docker run --rm -v "$JTROOT":/jtroot -w /jtroot/$REL "$IMAGE" -c '
    unset VERILATOR_ROOT
    verilator --binary --timing -j 4 -Wno-fatal --top-module tb_snd \
        tb_snd.v ../../hdl/jtmnymny_snd.v ../../hdl/jtmnymny_6821.v \
        ../../hdl/jtmnymny_tms5200.v \
        +incdir+. -y ../../hdl -y /jtroot/modules/jtframe/hdl/clocking \
        -y /jtroot/modules/jt680x/hdl -y /jtroot/modules/jt12/jt49/hdl \
        -o tbsnd >verilator.log 2>&1 || { tail -40 verilator.log; exit 1; }
    ./obj_dir/tbsnd
'
