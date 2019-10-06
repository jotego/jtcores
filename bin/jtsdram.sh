#!/bin/bash

MIN=0
MAX=11000
CORE=1943

cd $JTGNG_ROOT

while [ $# -gt 0 ]; do
    case "$1" in
        -min)
            shift
            MIN=$1;;
        -max)
            shift
            MAX=$1;;
        -core)
            shift
            CORE=$1;;
        *)
            echo "Unknown parameter"
            exit 1;;
    esac
    shift
done

for DELAY in 0 260 520 729 1041 1250 1475 1736 1996 2256 2500 2734 2994 3255 3515 3750 3993 4253 4513 4774 5000 5208 5520 5729 5989 6250 6510 6770 6979 7291 7500 7725 7986 8246 8506 8750 8984 9244 9505 9765 10000 10243 10329;
do
    if [[ $DELAY -lt $MIN || $DELAY -gt $MAX ]]; then
        continue
    fi
    echo Using ${DELAY}ps delay
    jtcore ${CORE} -mr -d SDRAM_SHIFT=\\\"$DELAY\\\"
    OUTPUT=$JTGNG_ROOT/${CORE}/mister/output_files/jt${CORE}.rbf
    if [ -e  ]; then
        cp $OUTPUT jt${CORE}_${DELAY}ps.rbf
        mv $JTGNG_ROOT/log/mister/jt${CORE}.log jt${CORE}_${DELAY}ps.log
    else
        echo "Missing output RBF file for ${DELAY}ps"
    fi
done

7za a jt${CORE}_shift.7z jt${CORE}*.log jt${CORE}*.rbf
