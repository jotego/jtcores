#!/bin/bash

for DELAY in 0 260 520 729 1041 1250 1475 1736 1996 2256 2500 2734 2994 3255 3515 3750 3993 4253 4513 4774 5000 5208 5520 5729 5989 6250 6510 6770 6979 7291 7500 7725 7986 8246 8506 8750 8984 9244 9505 9765 10000 10243 10329;
do
    echo Using ${DELAY}ps delay
    jtcore 1943 -mr -d SDRAM_SHIFT=\\\"$DELAY\\\"
    OUTPUT=$JTGNG_ROOT/1943/mister/output_files/jt1943.rbf
    if [ -e  ]; then
        cp $OUTPUT jt1943_${DELAY}ps.rbf
        mv $JTGNG_ROOT/log/mister/jt1943.log jt1943_${DELAY}ps.log
    else
        echo "Missing output RBF file for ${DELAY}ps"
    fi
done

7za a jt1943_shift.7z jt1943*.log jt1943*.rbf
