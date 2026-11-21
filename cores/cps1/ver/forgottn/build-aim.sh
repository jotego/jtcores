#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 31-10-2026
set -euo pipefail
script_dir=$(cd "$(dirname "$0")" && pwd)
repo_dir=$(cd "$script_dir/../../../.." && pwd)
if [[ ${1:-} == --docker ]]; then
    docker image inspect jotego/simulator:arm64 >/dev/null
    exec docker run --pull=never --rm --entrypoint /bin/bash \
        -v "$repo_dir:/jtcores" jotego/simulator:arm64 -c \
        'apt-get install -y -qq binutils-m68k-linux-gnu && bash /jtcores/cores/cps1/ver/forgottn/build-aim.sh'
fi
prefix=${M68K_PREFIX:-m68k-linux-gnu-}
cd "$script_dir"
"${prefix}as" -m68000 aim.s -o aim.o
"${prefix}ld" -Ttext=0x100 -e forgottn_aim aim.o -o aim.elf
"${prefix}objcopy" -O binary aim.elf aim.bin
"${prefix}objcopy" -O binary --reverse-bytes=2 aim.elf aim-mra.bin
"${prefix}objdump" -d aim.elf
od -An -v -tx1 aim-mra.bin
