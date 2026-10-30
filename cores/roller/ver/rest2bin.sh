#!/bin/bash -e

if [ "${1:-}" = --delete ]; then
    rm -f psac0.bin psac1.bin obj.bin psac_mmr.bin obj_mmr.bin ccu.bin ext.bin
    exit 0
fi

if [ "$(stat -c %s rest.bin)" -ne 4136 ]; then
    echo "Roller Games scene rest.bin must contain 4136 bytes" >&2
    exit 1
fi

split_part() {
    dd if=rest.bin of="$1.bin" bs=1 skip="$2" count="$3" status=none
}

split_part psac0        0 1024
split_part psac1     1024 1024
split_part obj       2048 2048
split_part psac_mmr  4096   15
split_part obj_mmr   4111    8
split_part ccu       4119   16
split_part ext       4135    1
