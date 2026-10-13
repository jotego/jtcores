#!/bin/bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../../.." && pwd)
HDL=${AMBER_HDL:-$JTROOT/cores/osman/hdl}
OUT=$(mktemp -d "${TMPDIR:-/tmp}/osman-amber.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
SOURCES=(a23_core a23_decode a23_execute a23_register_bank a23_fetch a23_alu a23_barrel_shift a23_multiply a23_cache a23_wishbone a23_coprocessor sram_line_en sram_byte_en)
FILES=(); for module in "${SOURCES[@]}"; do FILES+=("$HDL/amber/$module.v"); done
iverilog -g2012 -I "$HDL" -s test -o "$OUT/test" "$HERE/test.v" "${FILES[@]}" \
    "$JTROOT/modules/jtframe/hdl/ram/jtframe_dual_ram.v"
cd "$HERE"
for delay in 1 2 5 8 13; do vvp "$OUT/test" +delay="$delay"; done
for delay in 1 5 13; do vvp "$OUT/test" +delay="$delay" +rom=swap.hex +words=25 +writes=4; done
