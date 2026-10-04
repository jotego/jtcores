#!/bin/bash -e

main() {
    if [ "${1:-}" = --delete ]; then
        rm -f scr1.bin scr0.bin pal.bin psac0.bin psac1.bin obj.bin \
              psac_mmr.bin scr_mmr.bin obj_mmr.bin prio.bin
        return
    fi

    if [ "$(stat -c %s rest.bin)" -ne 23584 ]; then
        echo "GX861 scene rest.bin must contain 23584 bytes" >&2
        return 1
    fi

    split_part scr1      0 8192
    split_part scr0   8192 8192
    split_part pal   16384 4096
    split_part psac0 20480 1024
    split_part psac1 21504 1024
    split_part obj   22528 1024
    split_part psac_mmr 23552 16
    split_part scr_mmr  23568 8
    split_part obj_mmr  23576 7
    split_part prio     23583 1
}

split_part() {
    dd if=rest.bin of="$1.bin" bs=1 skip="$2" count="$3" status=none
}

main "$@"
