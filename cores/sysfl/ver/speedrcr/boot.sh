#!/bin/bash
# speedrcr first-boot simulation (CPU enabled; scene replays use run_scenes.sh
# which passes -d NOMAIN instead).
# Builds SIM-ONLY fastboot sdram images (shortened POST delay/RAM tests, see
# make_sdram.py) and runs the RTL for N frames (default 600).
# Boot progress prints as "jt960 milestone <pc>" lines, see jtsysfl_main.v
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
python3 make_sdram.py --fastboot
docker run --rm -v "$HOME/develop/jtpublicfork":/jtcores -v "$HOME/develop/jotego-support":/jotego \
    -e JOTEGO=/jotego -w /jtcores/cores/sysfl/ver/speedrcr --entrypoint bash jotego/simulator:arm64 \
    -c "source /jtcores/setprj.sh >/dev/null 2>&1; jtsim -video ${1:-600}"
