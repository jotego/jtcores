#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${ROM:?Source setprj.sh from the project root first}"
if [[ ! -s "$ROM/sf2ua.rom" ]]; then
    jtframe mra cps1
fi
python3 prepare.py
jtsim -load results.cab -video 1200 -norotate "$@"
