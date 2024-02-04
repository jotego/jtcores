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
    # Beta key is enabled for cores listed in beta.yaml
    for TARGET in $*; do
        if jtframe cfgstr $CORENAME --target=$TARGET --output bash | grep JTFRAME_SKIP; then
            echo "Skipping $CORENAME for $TARGET because of JTFRAME_SKIP"
            continue
        fi
        if [ $TARGET != pocket ]; then SKIPPOCKET=--skipPocket; else unset SKIPPOCKET; fi
        jtframe mra --skipROM $SKIPPOCKET $CORENAME
        echo "Compiling for $TARGET"
        jtseed 4 $CORENAME -$TARGET --nodbg
        # recover hard disk space
        rm -rf $CORES/$CORENAME/$TARGET
    done
fi
