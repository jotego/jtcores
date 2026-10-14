#!/bin/bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../../.." && pwd)
TASK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/osman-colmix.XXXXXX")
trap 'rm -rf "$TASK_TMP"' EXIT
iverilog -g2012 -s test -o "$TASK_TMP/test" "$HERE/test.v" \
  "$JTROOT/cores/osman/hdl/jtosman_colmix.v" \
  "$JTROOT/modules/jtframe/hdl/video/jtframe_blank.v"
vvp "$TASK_TMP/test"
