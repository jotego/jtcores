#!/bin/bash
set -e

git config --global --add safe.directory /jtcores
cd /jtcores
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe

source $JTFRAME/bin/setprj.sh > /dev/null
export PATH=$PATH:/usr/local/go/bin

CORENAME=$1
shift

if [ -z "$BETAKEY" ]; then
    BETAKEY=`printf "%04X%04X" $RANDOM $RANDOM`
    echo "WARNING: remote compilation with no beta key. Assigning random one"
fi

export JTUTIL=/jtutil
mkdir $JTUTIL
printf "%08x" 0x$BETAKEY | xxd -r -p > $JTUTIL/beta.bin
ls -l $JTUTIL/beta.bin

if [ -e $CORES/$CORENAME/cfg/macros.def ]; then
    jtframe mra --skipROM $CORENAME
    # Beta key is enabled for cores listed in beta.yaml
    for TARGET in $*; do
        echo "Compiling for $TARGET"
        jtseed 4 $CORENAME -$TARGET --nodbg
    done
fi
