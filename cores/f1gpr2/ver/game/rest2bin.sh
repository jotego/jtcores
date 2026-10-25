#!/bin/bash -e
# f1gpr2 scene restore. Layout TBD after scene capture is set up.
# For now, exit cleanly when no rest.bin exists (plain boot).
[ -f rest.bin ] || exit 0

SIZE=$(wc -c < rest.bin | tr -d ' ')
split() { dd if=rest.bin of=$1.bin bs=1 skip=$2 count=$3 status=none; }

case "$SIZE" in
*)
    echo "rest2bin.sh: scene restore not yet configured (size=$SIZE)"
    exit 1
    ;;
esac
