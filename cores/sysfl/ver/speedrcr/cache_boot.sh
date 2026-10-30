#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 30-10-2026
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
cd "$here"
if [[ ! -s backup.bin && -s nvram.bin ]]; then cp nvram.bin backup.bin; fi
blocks=${1:-8}
frames=${2:-2001}
cab=${3:-speed1_fast.cab}
case "$blocks" in 2|4|8|16|32|64) ;; *) echo "Cache blocks must be 2, 4, 8, 16, 32 or 64" >&2; exit 1;; esac
[[ "$frames" =~ ^[1-9][0-9]*$ ]] || exit 1
[[ "$cab" != */* && -f "$cab" ]] || { echo "Cabinet file must be in $here" >&2; exit 1; }
for asset in rom.bin nvram.bin backup.bin sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin c75bios_lo.bin c75bios_hi.bin; do
    [[ -s "$asset" ]] || { echo "Missing $asset; prepare the boot assets with make_sdram.py --fastboot" >&2; exit 1; }
done
image=${SIMULATOR_IMAGE:-jotego/simulator:arm64}
support=${JOTEGO:-$HOME/develop/jotego-support}
docker image inspect "$image" >/dev/null
log="cache_boot_$((blocks*256))b.log"
status=0
{
    echo "cache_bytes=$((blocks*256)) requested_frames=$frames cabinet=$cab"
    shasum -a 256 "$cab" rom.bin nvram.bin backup.bin sdram_bank?.bin
    docker run --rm --pull=never -v "$repo":/jtcores -v "$support":/jotego \
        -e JOTEGO=/jotego -w /jtcores/cores/sysfl/ver/speedrcr --entrypoint bash "$image" \
        -c 'source /jtcores/setprj.sh >/dev/null 2>&1; set -e; jtsim -video "$2" -d SYSFL_CPUSTAT -d "SYSFL_ICACHE_BLK=$1" "$3"' \
        _ "$blocks" "$frames" "$cab"
} > "$log" 2> "${log%.log}.stderr.log" || status=$?
cat "${log%.log}.stderr.log" >> "$log"
rm "${log%.log}.stderr.log"
if (( status!=0 )); then
    echo "Boot failed with exit $status; see $here/$log" >&2
    exit "$status"
fi
if ! grep -q 'CACHESTAT frame=' "$log" || grep -Eq 'ERROR:|HALTED|FAIL|%Error|FATAL:' "$log"; then
    echo "Boot verification failed; see $here/$log" >&2
    exit 1
fi
echo "Boot completed: $here/$log; frames: $here/frames/"
if (( frames>1073 )); then python3 check_cache_boot.py "$log" --frames "$frames"; fi
