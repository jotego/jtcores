#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${ROM:?Source setprj.sh from the project root first}"
if [[ ! -s "$ROM/superman.rom" ]]; then
    jtframe mra taitox
fi
python3 build_boot.py
python3 prepare_boot.py
jtsim -load boot_control.cab -video 120 -norotate "$@"
