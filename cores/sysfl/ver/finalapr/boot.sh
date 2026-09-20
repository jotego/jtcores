#!/bin/bash
# finalapr first-boot simulation. Same flow as ver/speedrcr/boot.sh but the
# fastboot image only shortens generic delay loops, so allow more frames
# (default 900) for the full-length POST RAM tests.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
python3 make_sdram.py --fastboot
docker run --rm -v "$HOME/develop/jtpublicfork":/jtcores -v "$HOME/develop/jotego-support":/jotego \
    -e JOTEGO=/jotego -w /jtcores/cores/sysfl/ver/finalapr --entrypoint bash jotego/simulator:arm64 \
    -c "source /jtcores/setprj.sh >/dev/null 2>&1; jtsim -video ${1:-900}"
