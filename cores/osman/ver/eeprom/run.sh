#!/bin/bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d "${TMPDIR:-/tmp}/osman-eeprom.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
SOURCES=("$HERE/test.v" "$JTROOT/cores/osman/hdl/jtosman_eeprom.v" "$JTROOT/modules/jteeprom/hdl/jt9346.v")
iverilog -g2012 -s test -o "$OUT/test" "${SOURCES[@]}"
vvp "$OUT/test"
