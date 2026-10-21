#!/bin/bash
set -euo pipefail

main() {
    local src output
    src=$(cd -- "$(dirname -- "$0")" && pwd)
    output=${1:-$src/../artifacts}
    mkdir -p "$output"
    "${CA65:-ca65}" "$src/monitor.s" -o "$output/monitor.o" -l "$output/monitor.lst"
    "${LD65:-ld65}" -C "$src/monitor.cfg" "$output/monitor.o" \
        -o "$output/monitor-bank.bin" -m "$output/monitor.map" -Ln "$output/monitor.lbl"
    python3 - "$output" <<'PY'
import sys
from pathlib import Path
out = Path(sys.argv[1])
bank = (out / 'monitor-bank.bin').read_bytes()
assert len(bank) == 8192
image = bytearray(bank * 8)
image[0x2000:0x2002] = bytes([0, 255])
image[0x4000] = 0
(out / 'monitor.bin').write_bytes(image)
PY
}

main "$@"
