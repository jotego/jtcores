#!/bin/bash
if [ -z "$1" ]; then
    cat <<EOF
cpsnap.sh <snapname>
    will copy snap binary files to new folder for simulations with sim.sh -s <snapname>
    the snap is generated from MAME or FPGA dumps
EOF
    exit 1
fi

mkdir -p $1
cp -v col.bin pal.bin vram_??.bin seta_cfg.hex $1